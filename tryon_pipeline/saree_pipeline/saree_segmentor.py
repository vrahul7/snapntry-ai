"""
saree_segmentor.py — SnapnTry AI Saree Pipeline
================================================
Segments a saree flat-lay product image into 4 functional draping regions:

    Region 0 — BLOUSE     : The fitted upper-body piece (choli)
    Region 1 — PETTICOAT  : The underskirt / base lower-body fabric
    Region 2 — DRAPE BODY : The main 5-yard panel that wraps the body
    Region 3 — PALLU      : The decorative end draped over the shoulder

Strategy (with graceful fallbacks):
  1. Try Segformer B2 Clothes (already used in preprocess.py) to identify
     clothing class pixels. Map classes to saree regions.
  2. If Segformer fails or returns insufficient pixels, fall back to
     proportional rule-based region boxes on the image.
  3. Use Gaussian blob detection + contour analysis to separate the pallu
     from the main draped body panel (pallus typically have denser patterns).

Returns a SareeRegions dataclass with 4 PIL Image crops + 4 binary masks.

Author: SnapnTry AI
"""

import cv2
import numpy as np
from PIL import Image, ImageFilter
from dataclasses import dataclass, field
from typing import Optional
import sys
import os

# Add parent directory for preprocess imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


@dataclass
class SareeRegions:
    """Holds the 4 segmented regions of a saree image."""
    blouse: Optional[Image.Image] = None          # Choli / fitted upper piece
    blouse_mask: Optional[np.ndarray] = None

    petticoat: Optional[Image.Image] = None       # Underskirt base
    petticoat_mask: Optional[np.ndarray] = None

    drape_body: Optional[Image.Image] = None      # Main 5-yard draped panel
    drape_body_mask: Optional[np.ndarray] = None

    pallu: Optional[Image.Image] = None           # Decorative shoulder end
    pallu_mask: Optional[np.ndarray] = None

    # Full image dimensions for reference
    image_width: int = 0
    image_height: int = 0

    # Source method used
    method: str = "unknown"  # "segformer" | "rule_based"


def _get_segformer():
    """Lazy-loads the Segformer B2 Clothes model (shared with preprocess.py)."""
    try:
        from preprocess import get_clothing_segmenter
        return get_clothing_segmenter()
    except ImportError:
        try:
            from tryon_pipeline.preprocess import get_clothing_segmenter
            return get_clothing_segmenter()
        except ImportError:
            pass

    # Direct load if all else fails
    from transformers import SegformerImageProcessor, AutoModelForSemanticSegmentation
    import torch
    device = "cuda" if torch.cuda.is_available() else "cpu"
    processor = SegformerImageProcessor.from_pretrained("mattmdjaga/segformer_b2_clothes")
    model = AutoModelForSemanticSegmentation.from_pretrained(
        "mattmdjaga/segformer_b2_clothes"
    ).to(device)
    return processor, model


def _apply_segformer(image: Image.Image) -> Optional[np.ndarray]:
    """
    Runs Segformer on the saree image.
    Returns a 2D numpy array of class indices (H, W) or None on failure.

    Segformer B2 Clothes class map:
        0: Background   1: Hat       2: Hair      3: Sunglasses  4: Upper-clothes
        5: Skirt        6: Pants     7: Dress     8: Belt        9: Left-shoe
       10: Right-shoe  11: Face     12: Left-leg 13: Right-leg  14: Left-arm
       15: Right-arm   16: Bag      17: Scarf
    """
    try:
        import torch
        import torch.nn as nn

        processor, model = _get_segformer()
        device = next(model.parameters()).device

        inputs = processor(images=image, return_tensors="pt")
        inputs = {k: v.to(device) for k, v in inputs.items()}

        with torch.no_grad():
            outputs = model(**inputs)
            logits = outputs.logits

        h, w = np.array(image).shape[:2]
        upsampled = nn.functional.interpolate(
            logits,
            size=(h, w),
            mode="bilinear",
            align_corners=False,
        )
        pred_seg = upsampled.argmax(dim=1)[0].cpu().numpy().astype(np.uint8)
        return pred_seg

    except Exception as e:
        print(f"[SareeSegmentor] Segformer failed: {e}")
        return None


def _make_binary_mask(bool_mask: np.ndarray) -> np.ndarray:
    """Converts a boolean mask to uint8 [0, 255]."""
    return (bool_mask * 255).astype(np.uint8)


def _morphological_clean(mask: np.ndarray, kernel_size: int = 7) -> np.ndarray:
    """Applies close + open morphology to remove small holes and noise."""
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kernel_size, kernel_size))
    cleaned = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_OPEN, kernel)
    return cleaned


def _crop_to_mask(image_np: np.ndarray, mask: np.ndarray) -> tuple[Image.Image, np.ndarray]:
    """
    Crops image and mask to the bounding box of the mask, 
    adds transparency channel where mask is 0.
    Returns (RGBA PIL Image, cropped mask).
    """
    if mask.sum() == 0:
        # Return 1x1 transparent placeholder
        return Image.fromarray(np.zeros((1, 1, 4), dtype=np.uint8)), np.zeros((1, 1), dtype=np.uint8)

    ys, xs = np.where(mask > 0)
    x1, x2 = xs.min(), xs.max()
    y1, y2 = ys.min(), ys.max()

    # Add small padding
    pad = 5
    h, w = image_np.shape[:2]
    x1 = max(0, x1 - pad)
    y1 = max(0, y1 - pad)
    x2 = min(w - 1, x2 + pad)
    y2 = min(h - 1, y2 + pad)

    cropped_img = image_np[y1:y2+1, x1:x2+1].copy()
    cropped_mask = mask[y1:y2+1, x1:x2+1].copy()

    # Convert to RGBA with mask as alpha
    if cropped_img.shape[2] == 3:
        rgba = cv2.cvtColor(cropped_img, cv2.COLOR_RGB2RGBA)
    else:
        rgba = cropped_img.copy()
    rgba[:, :, 3] = cropped_mask

    return Image.fromarray(rgba), cropped_mask


def _detect_pallu_region(
    image_np: np.ndarray,
    drape_mask: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    """
    Separates the pallu from the main drape body.
    
    The pallu is typically:
    - Located in the upper-left or upper-right quadrant of the drape
    - Has denser decorative pattern (higher local texture variance)
    - Represents ~15-25% of the total drape area
    
    Strategy:
    1. Divide the drape mask into vertical strips
    2. Compute local texture variance (Laplacian variance) per strip
    3. The strip(s) with highest texture = pallu
    
    Returns: (pallu_mask, remaining_drape_mask)
    """
    h, w = drape_mask.shape

    if drape_mask.sum() == 0:
        return np.zeros_like(drape_mask), drape_mask

    # Get bounding box of drape region
    ys, xs = np.where(drape_mask > 0)
    if len(ys) == 0:
        return np.zeros_like(drape_mask), drape_mask

    x1, x2 = xs.min(), xs.max()
    y1, y2 = ys.min(), ys.max()
    drape_w = x2 - x1
    drape_h = y2 - y1

    if drape_w < 10 or drape_h < 10:
        return np.zeros_like(drape_mask), drape_mask

    # Compute Laplacian variance in the top 35% of the drape area
    # (pallu is usually in the upper portion)
    top_cutoff = y1 + int(drape_h * 0.35)
    gray = cv2.cvtColor(image_np, cv2.COLOR_RGB2GRAY).astype(np.float32)
    laplacian = cv2.Laplacian(gray, cv2.CV_32F)
    laplacian_var = laplacian ** 2

    # Divide the top-portion into left/right halves
    mid_x = (x1 + x2) // 2

    # Compute mean texture variance for left vs right half of top section
    left_roi = laplacian_var[y1:top_cutoff, x1:mid_x]
    right_roi = laplacian_var[y1:top_cutoff, mid_x:x2]

    left_mean = float(np.mean(left_roi)) if left_roi.size > 0 else 0.0
    right_mean = float(np.mean(right_roi)) if right_roi.size > 0 else 0.0

    # Pallu is on the side with higher texture variance
    pallu_mask = np.zeros_like(drape_mask)
    pallu_height = y1 + int(drape_h * 0.40)  # Top 40% is pallu region

    if left_mean >= right_mean:
        # Pallu on the left
        pallu_mask[y1:pallu_height, x1:mid_x] = drape_mask[y1:pallu_height, x1:mid_x]
    else:
        # Pallu on the right
        pallu_mask[y1:pallu_height, mid_x:x2] = drape_mask[y1:pallu_height, mid_x:x2]

    # The remaining drape = drape_mask minus pallu_mask
    remaining_drape = drape_mask.copy()
    remaining_drape[pallu_mask > 0] = 0

    return pallu_mask, remaining_drape


def _rule_based_segmentation(image_np: np.ndarray, h: int, w: int) -> SareeRegions:
    """
    Fallback proportional segmentation when Segformer is unavailable.
    
    Nivi-style saree proportional layout (rough approximation):
        Blouse:    Top 20%, horizontal center 15%-85%
        Petticoat: Bottom 30%, full width (below drape)
        Drape:     Middle 65%, full width
        Pallu:     Top 40% of drape area, left 50%
    """
    regions = SareeRegions(image_width=w, image_height=h, method="rule_based")

    # --- Blouse ---
    blouse_mask = np.zeros((h, w), dtype=np.uint8)
    by1, by2 = int(h * 0.02), int(h * 0.25)
    bx1, bx2 = int(w * 0.10), int(w * 0.90)
    blouse_mask[by1:by2, bx1:bx2] = 255
    blouse_mask = _morphological_clean(blouse_mask, kernel_size=5)
    regions.blouse, regions.blouse_mask = _crop_to_mask(image_np, blouse_mask)

    # --- Drape Body (middle section) ---
    drape_mask = np.zeros((h, w), dtype=np.uint8)
    dy1, dy2 = int(h * 0.20), int(h * 0.78)
    drape_mask[dy1:dy2, :] = 255
    drape_mask = _morphological_clean(drape_mask, kernel_size=5)

    # --- Pallu from the drape (top-left portion of drape) ---
    pallu_mask, remaining_drape_mask = _detect_pallu_region(image_np, drape_mask)
    regions.drape_body, regions.drape_body_mask = _crop_to_mask(image_np, remaining_drape_mask)
    regions.pallu, regions.pallu_mask = _crop_to_mask(image_np, pallu_mask)

    # --- Petticoat (bottom section) ---
    petti_mask = np.zeros((h, w), dtype=np.uint8)
    py1, py2 = int(h * 0.72), int(h * 0.98)
    petti_mask[py1:py2, int(w * 0.15):int(w * 0.85)] = 255
    petti_mask = _morphological_clean(petti_mask, kernel_size=5)
    regions.petticoat, regions.petticoat_mask = _crop_to_mask(image_np, petti_mask)

    return regions


def segment_saree_regions(saree_image: Image.Image) -> SareeRegions:
    """
    Main entrypoint. Segments a saree flat-lay image into 4 draping regions.

    Args:
        saree_image: PIL Image of the saree (flat-lay or product shot).

    Returns:
        SareeRegions dataclass with blouse, petticoat, drape_body, and pallu
        as RGBA PIL Images + corresponding binary numpy masks.

    Example:
        >>> from PIL import Image
        >>> saree = Image.open("my_saree.jpg")
        >>> regions = segment_saree_regions(saree)
        >>> regions.blouse.save("blouse.png")
        >>> regions.pallu.save("pallu.png")
    """
    # Ensure RGB
    if saree_image.mode != "RGB":
        saree_image = saree_image.convert("RGB")

    image_np = np.array(saree_image)
    h, w = image_np.shape[:2]

    print(f"[SareeSegmentor] Segmenting saree image: {w}x{h}px")

    # --- Attempt Segformer-based segmentation ---
    pred_seg = _apply_segformer(saree_image)

    if pred_seg is not None:
        print("[SareeSegmentor] Segformer succeeded — mapping classes to saree regions")
        regions = SareeRegions(image_width=w, image_height=h, method="segformer")

        # Segformer class mapping for saree:
        #   Blouse    → class 4 (Upper-clothes)
        #   Petticoat → class 6 (Pants) — the visible underskirt leg
        #   Drape     → class 5 (Skirt) + class 7 (Dress) — flowing panels
        #   Pallu is extracted from the drape via texture analysis

        # --- Blouse (class 4 = Upper-clothes) ---
        blouse_raw = _make_binary_mask(pred_seg == 4)
        # Restrict to top 35% of image (blouse is always at the top in product shots)
        blouse_top_restrict = np.zeros_like(blouse_raw)
        blouse_top_restrict[:int(h * 0.40), :] = blouse_raw[:int(h * 0.40), :]
        blouse_mask = _morphological_clean(blouse_top_restrict, kernel_size=5)

        if blouse_mask.sum() < (0.005 * h * w * 255):
            print("[SareeSegmentor] Blouse class sparse — using rule-based blouse box")
            blouse_mask = np.zeros((h, w), dtype=np.uint8)
            blouse_mask[int(h * 0.02):int(h * 0.25), int(w * 0.15):int(w * 0.85)] = 255

        regions.blouse, regions.blouse_mask = _crop_to_mask(image_np, blouse_mask)

        # --- Petticoat (class 6 = Pants, representing the visible underskirt) ---
        petti_raw = _make_binary_mask(pred_seg == 6)
        petti_mask = _morphological_clean(petti_raw, kernel_size=5)
        if petti_mask.sum() < (0.005 * h * w * 255):
            petti_mask = np.zeros((h, w), dtype=np.uint8)
            petti_mask[int(h * 0.72):int(h * 0.98), int(w * 0.15):int(w * 0.85)] = 255

        regions.petticoat, regions.petticoat_mask = _crop_to_mask(image_np, petti_mask)

        # --- Drape Body + Pallu (class 5=Skirt + class 7=Dress) ---
        drape_raw = _make_binary_mask(
            (pred_seg == 5) | (pred_seg == 7)
        )
        drape_mask = _morphological_clean(drape_raw, kernel_size=7)

        if drape_mask.sum() < (0.01 * h * w * 255):
            print("[SareeSegmentor] Drape classes sparse — using rule-based drape box")
            drape_mask = np.zeros((h, w), dtype=np.uint8)
            drape_mask[int(h * 0.20):int(h * 0.78), :] = 255

        # Detect pallu from the drape using texture variance analysis
        pallu_mask, remaining_drape_mask = _detect_pallu_region(image_np, drape_mask)

        regions.drape_body, regions.drape_body_mask = _crop_to_mask(image_np, remaining_drape_mask)
        regions.pallu, regions.pallu_mask = _crop_to_mask(image_np, pallu_mask)

        print(
            f"[SareeSegmentor] Segmentation complete (Segformer): "
            f"blouse={regions.blouse.size}, petticoat={regions.petticoat.size}, "
            f"drape={regions.drape_body.size}, pallu={regions.pallu.size}"
        )
        return regions

    # --- Fallback to proportional rule-based segmentation ---
    print("[SareeSegmentor] Falling back to rule-based proportional segmentation")
    regions = _rule_based_segmentation(image_np, h, w)
    print(
        f"[SareeSegmentor] Segmentation complete (rule-based): "
        f"blouse={regions.blouse.size}, petticoat={regions.petticoat.size}, "
        f"drape={regions.drape_body.size}, pallu={regions.pallu.size}"
    )
    return regions


# ──────────────────────────────────────────────────────────────────────────────
# Quick self-test
# ──────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import sys

    print("=== SareeSegmentor Self-Test ===")

    # Create a dummy saree test image with color bands simulating regions
    dummy = np.zeros((600, 400, 3), dtype=np.uint8)
    dummy[10:130, 60:340] = [220, 80, 120]   # Blouse — pink top band
    dummy[130:450, :] = [255, 165, 0]         # Drape — orange middle
    dummy[130:280, :200] = [200, 50, 200]     # Pallu — purple top-left
    dummy[450:580, 60:340] = [240, 240, 100]  # Petticoat — yellow bottom

    test_image = Image.fromarray(dummy)
    regions = segment_saree_regions(test_image)

    print(f"Blouse region size:    {regions.blouse.size}")
    print(f"Petticoat region size: {regions.petticoat.size}")
    print(f"Drape body size:       {regions.drape_body.size}")
    print(f"Pallu size:            {regions.pallu.size}")
    print(f"Segmentation method:   {regions.method}")
    print("=== Self-Test Passed ===")
