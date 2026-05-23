import cv2
import numpy as np
from PIL import Image

_processor = None
_model = None

def get_clothing_segmenter():
    global _processor, _model
    if _processor is None or _model is None:
        from transformers import SegformerImageProcessor, AutoModelForSemanticSegmentation
        import torch
        device = "cuda" if torch.cuda.is_available() else "cpu"
        # Download/load model from HF
        _processor = SegformerImageProcessor.from_pretrained("mattmdjaga/segformer_b2_clothes")
        _model = AutoModelForSemanticSegmentation.from_pretrained("mattmdjaga/segformer_b2_clothes").to(device)
    return _processor, _model

def resize_and_pad(image: Image.Image, target_size=(512, 384)) -> Image.Image:
    """
    Resizes image preserving aspect ratio and pads to target_size (height, width).
    """
    img = np.array(image)
    h, w = img.shape[:2]
    target_h, target_w = target_size
    
    # Calculate scale factor
    scale = min(target_h / h, target_w / w)
    new_h, new_w = int(h * scale), int(w * scale)
    
    # Resize
    resized = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
    
    # Pad to target size
    pad_h = target_h - new_h
    pad_w = target_w - new_w
    
    top = pad_h // 2
    bottom = pad_h - top
    left = pad_w // 2
    right = pad_w - left
    
    color = [0, 0, 0] if len(img.shape) == 3 else 0
    padded = cv2.copyMakeBorder(resized, top, bottom, left, right, cv2.BORDER_CONSTANT, value=color)
    
    return Image.fromarray(padded)

def extract_garment_mask(garment_image: Image.Image) -> tuple[Image.Image, Image.Image]:
    """
    Isolates the garment from the background using a hybrid Segformer + Otsu thresholding approach.
    Returns:
        cropped_garment: Garment image with transparent background.
        binary_mask: White mask on black background.
    """
    img = np.array(garment_image)
    if img.ndim == 2:
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)
    elif img.shape[2] == 4:
        img = cv2.cvtColor(img, cv2.COLOR_RGBA2RGB)
        
    h, w = img.shape[:2]
    
    # 1. Try Segformer first
    try:
        import torch
        import torch.nn as nn
        processor, model = get_clothing_segmenter()
        device = next(model.parameters()).device
        
        inputs = processor(images=garment_image, return_tensors="pt")
        inputs = {k: v.to(device) for k, v in inputs.items()}
        
        with torch.no_grad():
            outputs = model(**inputs)
            logits = outputs.logits
            
        upsampled_logits = nn.functional.interpolate(
            logits,
            size=(h, w),
            mode="bilinear",
            align_corners=False,
        )
        pred_seg = upsampled_logits.argmax(dim=1)[0].cpu().numpy()
        
        # Garment classes: 4 (Upper-clothes), 5 (Skirt), 6 (Pants), 7 (Dress), 17 (Scarf)
        seg_mask = np.zeros((h, w), dtype=np.uint8)
        seg_mask[np.isin(pred_seg, [4, 5, 6, 7, 17])] = 255
        
        # If segformer found a reasonable amount of garment pixels (e.g. > 1% of the image)
        if np.sum(seg_mask) > (0.01 * h * w * 255):
            # Clean up the mask using morphological operations
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
            cleaned = cv2.morphologyEx(seg_mask, cv2.MORPH_CLOSE, kernel)
            cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_OPEN, kernel)
            
            contours, _ = cv2.findContours(cleaned, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            mask = np.zeros_like(cleaned)
            if contours:
                largest_contour = max(contours, key=cv2.contourArea)
                cv2.drawContours(mask, [largest_contour], -1, 255, -1)
            else:
                mask = cleaned
                
            x, y, w_box, h_box = cv2.boundingRect(mask)
            cropped_img = img[y:y+h_box, x:x+w_box]
            cropped_mask = mask[y:y+h_box, x:x+w_box]
            
            rgba = cv2.cvtColor(cropped_img, cv2.COLOR_RGB2RGBA)
            rgba[:, :, 3] = cropped_mask
            return Image.fromarray(rgba), Image.fromarray(cropped_mask)
    except Exception as e:
        print(f"Segformer garment extraction failed: {e}. Falling back to Otsu.")
        
    # 2. Fallback to Otsu thresholding (original logic)
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    blurred = cv2.bilateralFilter(gray, 9, 75, 75)
    _, thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    cleaned = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_OPEN, kernel)
    
    contours, _ = cv2.findContours(cleaned, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    mask = np.zeros_like(cleaned)
    
    if contours:
        largest_contour = max(contours, key=cv2.contourArea)
        cv2.drawContours(mask, [largest_contour], -1, 255, -1)
    else:
        mask = cleaned
        
    x, y, w_box, h_box = cv2.boundingRect(mask)
    cropped_img = img[y:y+h_box, x:x+w_box]
    cropped_mask = mask[y:y+h_box, x:x+w_box]
    
    rgba = cv2.cvtColor(cropped_img, cv2.COLOR_RGB2RGBA)
    rgba[:, :, 3] = cropped_mask
    
    return Image.fromarray(rgba), Image.fromarray(cropped_mask)

def generate_body_agnostic_mask(person_image: Image.Image, category: str = "upper_body") -> tuple[Image.Image, Image.Image]:
    """
    Generates a body-agnostic representation where the target garment area is masked out.
    Args:
        person_image: High-res image of the target person.
        category: upper_body, lower_body, or one_piece.
    Returns:
        agnostic_person: Image with garment area colored gray.
        agnostic_mask: Binary mask indicating the region to paint.
    """
    import torch
    import torch.nn as nn
    
    img = np.array(person_image)
    h, w = img.shape[:2]
    
    # Try using Segformer first
    try:
        processor, model = get_clothing_segmenter()
        device = next(model.parameters()).device
        
        inputs = processor(images=person_image, return_tensors="pt")
        inputs = {k: v.to(device) for k, v in inputs.items()}
        
        with torch.no_grad():
            outputs = model(**inputs)
            logits = outputs.logits
            
        upsampled_logits = nn.functional.interpolate(
            logits,
            size=(h, w),
            mode="bilinear",
            align_corners=False,
        )
        pred_seg = upsampled_logits.argmax(dim=1)[0].cpu().numpy()
        
        mask = np.zeros((h, w), dtype=np.uint8)
        
        # 4: Upper-clothes, 5: Skirt, 6: Pants, 7: Dress, 17: Scarf
        if category == "upper_body":
            mask[pred_seg == 4] = 255
            mask[pred_seg == 17] = 255 # Scarf
        elif category == "lower_body":
            mask[pred_seg == 5] = 255
            mask[pred_seg == 6] = 255
        elif category in ["one_piece", "dress"]:
            mask[pred_seg == 4] = 255
            mask[pred_seg == 5] = 255
            mask[pred_seg == 6] = 255
            mask[pred_seg == 7] = 255
            mask[pred_seg == 17] = 255
            
        # Fallback if no matching pixels found by Segformer
        if np.sum(mask) == 0:
            raise ValueError("No pixels matching category found by Segformer.")
            
    except Exception as e:
        print(f"Segformer agnostic mask gen failed/skipped: {e}. Using rule-based fallback.")
        mask = np.zeros((h, w), dtype=np.uint8)
        if category == "upper_body":
            y1, y2 = int(h * 0.25), int(h * 0.70)
            x1, x2 = int(w * 0.15), int(w * 0.85)
            cv2.rectangle(mask, (x1, y1), (x2, y2), 255, -1)
        elif category == "lower_body":
            y1, y2 = int(h * 0.55), int(h * 0.95)
            x1, x2 = int(w * 0.15), int(w * 0.85)
            cv2.rectangle(mask, (x1, y1), (x2, y2), 255, -1)
        else:
            y1, y2 = int(h * 0.25), int(h * 0.90)
            x1, x2 = int(w * 0.15), int(w * 0.85)
            cv2.rectangle(mask, (x1, y1), (x2, y2), 255, -1)
            
    # Dilate the mask slightly to cover boundaries and seams
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (11, 11))
    dilated_mask = cv2.dilate(mask, kernel)
    
    # Create the agnostic person image by replacing the mask area with a neutral gray (128, 128, 128)
    agnostic_img = img.copy()
    agnostic_img[dilated_mask == 255] = [128, 128, 128]
    
    return Image.fromarray(agnostic_img), Image.fromarray(dilated_mask)

def estimate_pose_guidance(person_image: Image.Image) -> Image.Image:
    """
    Computes a simplified edge/contour representation of the human pose skeleton.
    Simulates a DensePose / joint skeleton channel.
    """
    img = np.array(person_image)
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    
    # Compute Canny edges to get shape outline
    edges = cv2.Canny(gray, 50, 150)
    
    # Dilate to make pose lines thicker
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    pose_skeleton = cv2.dilate(edges, kernel)
    
    # Convert to 3-channel (RGB) representation
    pose_rgb = cv2.merge([pose_skeleton, np.zeros_like(pose_skeleton), pose_skeleton])
    
    return Image.fromarray(pose_rgb)

if __name__ == "__main__":
    # Test script execution
    print("Preprocessing helpers defined successfully.")
    
    # Create dummy images for shape verification
    dummy_garment = Image.fromarray(np.uint8(np.random.rand(400, 400, 3) * 255))
    dummy_person = Image.fromarray(np.uint8(np.random.rand(600, 400, 3) * 255))
    
    resized_p = resize_and_pad(dummy_person)
    print(f"Resized Person shape: {np.array(resized_p).shape}")
    
    # We run with fallback since dummy images will fail Segformer
    g_crop, g_mask = extract_garment_mask(dummy_garment)
    print(f"Extracted garment mask shape: {np.array(g_mask).shape}")
    
    agnostic, agnostic_mask = generate_body_agnostic_mask(resized_p, "upper_body")
    print(f"Agnostic Person shape: {np.array(agnostic).shape}")
    print(f"Agnostic Mask shape: {np.array(agnostic_mask).shape}")
    
    pose = estimate_pose_guidance(resized_p)
    print(f"Pose guidance shape: {np.array(pose).shape}")
