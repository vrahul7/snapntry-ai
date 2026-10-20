"""
compose_service.py — SnapnTry AI Saree Pipeline
================================================
The final compositor that layers all 4 saree regions onto a target model
to produce a photorealistic saree draping result.

Composition Order (back to front, Nivi style):
    1. Start with target model image
    2. Mask out body region (torso + lower body via agnostic mask)
    3. Layer PETTICOAT  — lower body, 90% opacity (visible at hem/ankle)
    4. Layer DRAPE BODY — full torso to ankle, 85% opacity (main fabric)
    5. Layer BLOUSE     — upper torso, 95% opacity (fitted piece)
    6. Layer PALLU      — over left shoulder + arm, 80% opacity (draping end)
    7. Apply PLEAT ENHANCEMENT — emboss filter on drape to simulate fabric folds
    8. Apply LAPLACIAN PYRAMID BLENDING on each layer boundary
    9. Apply HISTOGRAM MATCHING — color/lighting matching between saree + model

Why Laplacian Pyramid Blending?
    Standard alpha-compositing creates sharp, "sticker-like" edges. Laplacian
    pyramid blending seamlessly integrates the fabric by merging low and high
    frequency components at different scales, producing a natural fabric-on-skin
    look.

Author: SnapnTry AI
"""

import cv2
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance
from typing import Optional, Tuple
import sys
import os

# Add parent directory for shared utilities
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# ──────────────────────────────────────────────────────────────────────────────
# Body Masking
# ──────────────────────────────────────────────────────────────────────────────

def _generate_full_body_mask(
    person_np: np.ndarray,
    region: str = "full",
) -> np.ndarray:
    """
    Generates a mask covering the body area where saree will be applied.
    For sarees, this covers torso + lower body.

    Args:
        person_np: RGB numpy array of person image.
        region: "upper", "lower", or "full" (for sarees: always "full").

    Returns:
        Binary mask (H, W), uint8 [0, 255]
    """
    h, w = person_np.shape[:2]

    # Try Segformer-based mask
    try:
        sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        try:
            from preprocess import get_clothing_segmenter
        except ImportError:
            from tryon_pipeline.preprocess import get_clothing_segmenter

        import torch
        import torch.nn as nn

        processor, model = get_clothing_segmenter()
        device = next(model.parameters()).device
        person_pil = Image.fromarray(person_np)

        inputs = processor(images=person_pil, return_tensors="pt")
        inputs = {k: v.to(device) for k, v in inputs.items()}

        with torch.no_grad():
            outputs = model(**inputs)
            logits = outputs.logits

        upsampled = nn.functional.interpolate(
            logits, size=(h, w), mode="bilinear", align_corners=False
        )
        pred_seg = upsampled.argmax(dim=1)[0].cpu().numpy()

        mask = np.zeros((h, w), dtype=np.uint8)
        # Cover all clothing classes + legs + arms for saree draping area
        body_classes = [4, 5, 6, 7, 12, 13, 14, 15, 17]  # clothes + limbs + scarf
        for cls in body_classes:
            mask[pred_seg == cls] = 255

        # Dilate to ensure full coverage
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))
        mask = cv2.dilate(mask, kernel)

        if mask.sum() > (0.05 * h * w * 255):
            return mask

    except Exception as e:
        print(f"[Compose] Segformer body mask failed: {e}")

    # Fallback: proportional body box for saree coverage
    mask = np.zeros((h, w), dtype=np.uint8)
    if region == "upper":
        mask[int(h * 0.15):int(h * 0.65), int(w * 0.10):int(w * 0.90)] = 255
    elif region == "lower":
        mask[int(h * 0.50):int(h * 0.97), int(w * 0.10):int(w * 0.90)] = 255
    else:  # full (for sarees)
        mask[int(h * 0.12):int(h * 0.97), int(w * 0.08):int(w * 0.92)] = 255

    return mask


# ──────────────────────────────────────────────────────────────────────────────
# Pleat Enhancement
# ──────────────────────────────────────────────────────────────────────────────

def _enhance_pleats(panel_np: np.ndarray) -> np.ndarray:
    """
    Simulates saree pleat texture by enhancing fabric fold shadows.

    Steps:
    1. Convert to LAB color space
    2. Apply Emboss-like filter on the L channel to simulate fold shadows
    3. Apply subtle vertical Gaussian blur to suggest flowing fabric lines
    4. Blend back with original (50/50 to avoid over-processing)

    Args:
        panel_np: RGBA numpy array of the drape panel.

    Returns:
        Enhanced RGBA panel with pleat texture.
    """
    if panel_np.shape[2] < 3:
        return panel_np

    # Separate RGB and alpha
    rgb = panel_np[:, :, :3].copy()
    alpha = panel_np[:, :, 3] if panel_np.shape[2] == 4 else None

    # Convert to float
    rgb_f = rgb.astype(np.float32) / 255.0

    # Apply emboss kernel (diagonal shading to simulate pleats)
    emboss_kernel = np.array([
        [-2, -1,  0],
        [-1,  1,  1],
        [ 0,  1,  2],
    ], dtype=np.float32)

    # Apply emboss to each channel
    embossed = np.zeros_like(rgb_f)
    for c in range(3):
        embossed[:, :, c] = cv2.filter2D(rgb_f[:, :, c], -1, emboss_kernel)

    # Normalize emboss to [0, 1]
    embossed = np.clip(embossed + 0.5, 0, 1)

    # Apply vertical blur to suggest flowing fabric motion
    flow_blurred = cv2.GaussianBlur(rgb_f, (1, 11), 0)

    # Blend: 60% original + 25% embossed (shadows) + 15% flow blur
    enhanced = 0.60 * rgb_f + 0.25 * embossed + 0.15 * flow_blurred
    enhanced = np.clip(enhanced, 0, 1)

    enhanced_uint8 = (enhanced * 255).astype(np.uint8)

    if alpha is not None:
        result = np.dstack([enhanced_uint8, alpha])
    else:
        result = enhanced_uint8

    return result


# ──────────────────────────────────────────────────────────────────────────────
# Laplacian Pyramid Blending (imported from inference.py if available)
# ──────────────────────────────────────────────────────────────────────────────

def _laplacian_blend(
    overlay: np.ndarray,
    base: np.ndarray,
    mask: np.ndarray,
    num_levels: int = 4,
) -> np.ndarray:
    """
    Blends overlay onto base using Laplacian pyramid blending.
    
    Args:
        overlay: float32 [H, W, 3] range [0, 1] — the saree layer
        base: float32 [H, W, 3] range [0, 1] — the person underneath
        mask: float32 [H, W] range [0, 1] — 1 where overlay is applied
        num_levels: pyramid depth

    Returns:
        Blended float32 [H, W, 3] image.
    """
    h, w = overlay.shape[:2]

    # Gaussian pyramids
    gp_overlay = [overlay.copy()]
    gp_base = [base.copy()]
    gp_mask = [mask.copy()]

    for _ in range(num_levels):
        gp_overlay.append(cv2.pyrDown(gp_overlay[-1]))
        gp_base.append(cv2.pyrDown(gp_base[-1]))
        gp_mask.append(cv2.pyrDown(gp_mask[-1]))

    # Laplacian pyramids
    lp_overlay = [gp_overlay[-1]]
    lp_base = [gp_base[-1]]

    for i in range(num_levels, 0, -1):
        size = (gp_overlay[i-1].shape[1], gp_overlay[i-1].shape[0])
        up_ov = cv2.pyrUp(gp_overlay[i], dstsize=size)
        up_ba = cv2.pyrUp(gp_base[i], dstsize=size)
        lp_overlay.append(gp_overlay[i-1] - up_ov)
        lp_base.append(gp_base[i-1] - up_ba)

    lp_overlay.reverse()
    lp_base.reverse()
    gp_mask.reverse()

    # Blend at each level
    blended = []
    for lo, lb, m in zip(lp_overlay, lp_base, gp_mask):
        if len(m.shape) == 2:
            m = np.expand_dims(m, axis=-1)
        blended.append(m * lo + (1.0 - m) * lb)

    # Reconstruct
    result = blended[-1]
    for i in range(num_levels - 1, -1, -1):
        size = (blended[i].shape[1], blended[i].shape[0])
        result = cv2.pyrUp(result, dstsize=size) + blended[i]

    return np.clip(result, 0.0, 1.0)


# ──────────────────────────────────────────────────────────────────────────────
# Histogram Matching (color/lighting normalization)
# ──────────────────────────────────────────────────────────────────────────────

def _match_histogram(source: np.ndarray, reference: np.ndarray) -> np.ndarray:
    """
    Matches the histogram of source to the reference image.
    Adjusts the saree's color/lighting to match the ambient lighting of the model photo.
    
    Uses CDF matching per channel.
    
    Args:
        source: uint8 [H, W, 3] image to adjust (saree panel)
        reference: uint8 [H, W, 3] reference image (person photo)

    Returns:
        Color-adjusted uint8 [H, W, 3] image.
    """
    try:
        from skimage.exposure import match_histograms
        matched = match_histograms(source, reference, channel_axis=2)
        return matched.astype(np.uint8)
    except ImportError:
        pass

    # Manual CDF matching fallback
    result = np.zeros_like(source)
    for c in range(3):
        src_hist, _ = np.histogram(source[:, :, c].ravel(), bins=256, range=[0, 256])
        ref_hist, _ = np.histogram(reference[:, :, c].ravel(), bins=256, range=[0, 256])

        src_cdf = np.cumsum(src_hist).astype(np.float64)
        ref_cdf = np.cumsum(ref_hist).astype(np.float64)

        src_cdf /= src_cdf[-1]
        ref_cdf /= ref_cdf[-1]

        # Build lookup table
        lut = np.zeros(256, dtype=np.uint8)
        j = 0
        for i in range(256):
            while j < 255 and ref_cdf[j] < src_cdf[i]:
                j += 1
            lut[i] = j

        result[:, :, c] = lut[source[:, :, c]]

    return result


# ──────────────────────────────────────────────────────────────────────────────
# Region Placement Helper
# ──────────────────────────────────────────────────────────────────────────────

def _place_panel_on_canvas(
    canvas: np.ndarray,
    panel: Image.Image,
    mask: np.ndarray,
    opacity: float,
    target_box: Tuple[int, int, int, int],  # (x1, y1, x2, y2)
    person_np: np.ndarray,
    apply_pleat: bool = False,
    apply_histogram: bool = True,
) -> np.ndarray:
    """
    Places a saree region panel onto the canvas at the specified bounding box
    with Laplacian pyramid blending.

    Args:
        canvas: float32 [H, W, 3] current composition canvas.
        panel: RGBA PIL Image of the saree region.
        mask: binary numpy mask [H, W] of the canvas region to blend.
        opacity: float [0, 1] opacity for this layer.
        target_box: (x1, y1, x2, y2) bounding box on the canvas.
        person_np: original person numpy array for histogram matching.
        apply_pleat: whether to apply pleat enhancement.
        apply_histogram: whether to apply histogram matching.

    Returns:
        Updated float32 [H, W, 3] canvas.
    """
    canvas_h, canvas_w = canvas.shape[:2]
    x1, y1, x2, y2 = target_box
    x1, y1 = max(0, x1), max(0, y1)
    x2, y2 = min(canvas_w, x2), min(canvas_h, y2)
    rw, rh = x2 - x1, y2 - y1

    if rw <= 0 or rh <= 0:
        return canvas

    # Resize panel to target box
    panel_rgba = np.array(panel.convert("RGBA").resize((rw, rh), Image.LANCZOS))

    if apply_pleat:
        panel_rgba = _enhance_pleats(panel_rgba)

    panel_rgb = panel_rgba[:, :, :3].astype(np.float32) / 255.0
    panel_alpha = panel_rgba[:, :, 3].astype(np.float32) / 255.0

    # Apply histogram matching (color/lighting normalization)
    if apply_histogram and person_np is not None:
        ref_region = person_np[y1:y2, x1:x2]
        if ref_region.size > 0:
            panel_rgb_uint8 = (panel_rgb * 255).astype(np.uint8)
            ref_resized = cv2.resize(ref_region, (rw, rh), interpolation=cv2.INTER_LINEAR)
            panel_rgb_matched = _match_histogram(panel_rgb_uint8, ref_resized)
            panel_rgb = panel_rgb_matched.astype(np.float32) / 255.0

    # Blend opacity into the panel alpha
    blend_alpha = panel_alpha * opacity

    # Create full-canvas-size overlay and mask
    full_overlay = canvas.copy()
    full_overlay[y1:y2, x1:x2] = panel_rgb

    blend_mask_full = np.zeros((canvas_h, canvas_w), dtype=np.float32)
    blend_mask_full[y1:y2, x1:x2] = blend_alpha

    # Optionally intersect with the body mask for accurate placement
    if mask is not None:
        mask_f = mask.astype(np.float32) / 255.0
        blend_mask_full = blend_mask_full * mask_f

    # Apply Gaussian blur to the blend mask for feathered edges
    blend_mask_full = cv2.GaussianBlur(blend_mask_full, (21, 21), 0)
    blend_mask_full = np.clip(blend_mask_full, 0, 1)

    # Laplacian pyramid blending
    blended = _laplacian_blend(full_overlay, canvas, blend_mask_full, num_levels=4)

    return blended.astype(np.float32)


# ──────────────────────────────────────────────────────────────────────────────
# Main Compositor
# ──────────────────────────────────────────────────────────────────────────────

def compose_saree_on_model(
    person_image: Image.Image,
    saree_regions,          # SareeRegions dataclass
    draping_style: str = "nivi",
    output_size: Optional[Tuple[int, int]] = None,
) -> Image.Image:
    """
    Composes all 4 saree regions onto the target model using Nivi-style
    draping geometry with Laplacian pyramid blending.

    Args:
        person_image: RGB PIL Image of the target model.
        saree_regions: SareeRegions dataclass (from saree_segmentor.py).
        draping_style: "nivi" (default). Others TBD in V2.
        output_size: (width, height) for the output. Defaults to person_image.size.

    Returns:
        RGB PIL Image — the composed saree draping result.

    Composition layers (back to front):
        1. Person (base layer)
        2. Petticoat (lower body, behind drape)
        3. Drape body (main saree panel)
        4. Blouse (upper torso)
        5. Pallu (shoulder drape)

    Example:
        >>> from saree_segmentor import segment_saree_regions
        >>> from compose_service import compose_saree_on_model
        >>> regions = segment_saree_regions(saree_img)
        >>> result = compose_saree_on_model(person_img, regions)
        >>> result.save("saree_result.png")
    """
    if person_image.mode != "RGB":
        person_image = person_image.convert("RGB")

    person_np = np.array(person_image)
    h, w = person_np.shape[:2]
    target_w, target_h = output_size if output_size else (w, h)

    if (target_w, target_h) != (w, h):
        person_np = cv2.resize(person_np, (target_w, target_h), interpolation=cv2.INTER_LANCZOS4)
        h, w = target_h, target_w

    print(f"[Compose] Compositing saree on model ({w}x{h}px, style={draping_style})")

    # Generate body coverage mask
    body_mask = _generate_full_body_mask(person_np, region="full")

    # Initialize canvas as the person image in float [0,1]
    canvas = person_np.astype(np.float32) / 255.0

    # ──────────────────────────────────────────────────────────────────────────
    # Layer 1: PETTICOAT — lower body underskirt (behind main drape)
    # Placement: lower 40% to 95% of body height, centered
    # ──────────────────────────────────────────────────────────────────────────
    if saree_regions.petticoat is not None and saree_regions.petticoat.size != (1, 1):
        petticoat_y1 = int(h * 0.52)
        petticoat_y2 = int(h * 0.97)
        petticoat_x1 = int(w * 0.12)
        petticoat_x2 = int(w * 0.88)

        # Lower body mask only
        lower_mask = np.zeros((h, w), dtype=np.uint8)
        lower_mask[petticoat_y1:petticoat_y2, petticoat_x1:petticoat_x2] = 255
        lower_mask = cv2.bitwise_and(lower_mask, body_mask)

        canvas = _place_panel_on_canvas(
            canvas=canvas,
            panel=saree_regions.petticoat,
            mask=lower_mask,
            opacity=0.90,
            target_box=(petticoat_x1, petticoat_y1, petticoat_x2, petticoat_y2),
            person_np=person_np,
            apply_pleat=False,
            apply_histogram=True,
        )
        print("[Compose] ✓ Petticoat layer applied")

    # ──────────────────────────────────────────────────────────────────────────
    # Layer 2: DRAPE BODY — main 5-yard fabric (torso to ankle)
    # Placement: 20% to 97% of height, full width
    # ──────────────────────────────────────────────────────────────────────────
    if saree_regions.drape_body is not None and saree_regions.drape_body.size != (1, 1):
        drape_y1 = int(h * 0.18)
        drape_y2 = int(h * 0.97)
        drape_x1 = int(w * 0.05)
        drape_x2 = int(w * 0.95)

        drape_mask = np.zeros((h, w), dtype=np.uint8)
        drape_mask[drape_y1:drape_y2, drape_x1:drape_x2] = 255
        drape_mask = cv2.bitwise_and(drape_mask, body_mask)

        canvas = _place_panel_on_canvas(
            canvas=canvas,
            panel=saree_regions.drape_body,
            mask=drape_mask,
            opacity=0.85,
            target_box=(drape_x1, drape_y1, drape_x2, drape_y2),
            person_np=person_np,
            apply_pleat=True,       # Enable pleat emboss for the main drape
            apply_histogram=True,
        )
        print("[Compose] ✓ Drape body layer applied (with pleat enhancement)")

    # ──────────────────────────────────────────────────────────────────────────
    # Layer 3: BLOUSE — fitted upper-body piece (choli)
    # Placement: upper torso area (18% to 42% height)
    # ──────────────────────────────────────────────────────────────────────────
    if saree_regions.blouse is not None and saree_regions.blouse.size != (1, 1):
        blouse_y1 = int(h * 0.14)
        blouse_y2 = int(h * 0.45)
        blouse_x1 = int(w * 0.15)
        blouse_x2 = int(w * 0.85)

        upper_mask = np.zeros((h, w), dtype=np.uint8)
        upper_mask[blouse_y1:blouse_y2, blouse_x1:blouse_x2] = 255
        upper_mask = cv2.bitwise_and(upper_mask, body_mask)

        canvas = _place_panel_on_canvas(
            canvas=canvas,
            panel=saree_regions.blouse,
            mask=upper_mask,
            opacity=0.95,
            target_box=(blouse_x1, blouse_y1, blouse_x2, blouse_y2),
            person_np=person_np,
            apply_pleat=False,
            apply_histogram=True,
        )
        print("[Compose] ✓ Blouse layer applied")

    # ──────────────────────────────────────────────────────────────────────────
    # Layer 4: PALLU — decorative end draped over left shoulder + arm
    # Placement (Nivi style): upper-left shoulder, draping diagonally
    # ──────────────────────────────────────────────────────────────────────────
    if saree_regions.pallu is not None and saree_regions.pallu.size != (1, 1):
        pallu_y1 = int(h * 0.08)
        pallu_y2 = int(h * 0.55)
        # Pallu goes over LEFT shoulder in Nivi style (right side on screen)
        # Adjust based on image orientation
        pallu_x1 = int(w * 0.0)
        pallu_x2 = int(w * 0.50)

        pallu_mask = np.zeros((h, w), dtype=np.uint8)
        pallu_mask[pallu_y1:pallu_y2, pallu_x1:pallu_x2] = 255

        canvas = _place_panel_on_canvas(
            canvas=canvas,
            panel=saree_regions.pallu,
            mask=pallu_mask,
            opacity=0.80,   # Slightly more transparent to show arm underneath
            target_box=(pallu_x1, pallu_y1, pallu_x2, pallu_y2),
            person_np=person_np,
            apply_pleat=True,
            apply_histogram=True,
        )
        print("[Compose] ✓ Pallu layer applied")

    # ──────────────────────────────────────────────────────────────────────────
    # Final Post-Processing
    # ──────────────────────────────────────────────────────────────────────────

    # Convert back to uint8
    result_uint8 = np.clip(canvas * 255, 0, 255).astype(np.uint8)

    # Mild sharpening to recover details lost in blending
    result_pil = Image.fromarray(result_uint8)
    result_pil = result_pil.filter(ImageFilter.UnsharpMask(radius=1.5, percent=120, threshold=3))

    # Slight contrast boost for premium look
    result_pil = ImageEnhance.Contrast(result_pil).enhance(1.05)

    print("[Compose] ✓ Saree composition complete!")
    return result_pil


# ──────────────────────────────────────────────────────────────────────────────
# Self-test
# ──────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=== Compose Service Self-Test ===")

    # Import SareeRegions for test
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from saree_segmentor import segment_saree_regions, SareeRegions
    from tps_warp import warp_saree_panel

    # Create a dummy person image
    person_np = np.zeros((600, 400, 3), dtype=np.uint8)
    person_np[:, :] = [180, 160, 145]  # Skin-tone background
    # Add some edges for contour detection
    cv2.rectangle(person_np, (80, 50), (320, 560), (160, 130, 110), -1)
    person_img = Image.fromarray(person_np, mode="RGB")

    # Create dummy saree image and segment it
    saree_np = np.zeros((600, 400, 3), dtype=np.uint8)
    saree_np[10:120, 60:340] = [220, 80, 120]   # Blouse region
    saree_np[120:430, :] = [200, 50, 200]         # Drape + pallu
    saree_np[430:570, 60:340] = [240, 240, 100]   # Petticoat
    saree_img = Image.fromarray(saree_np, mode="RGB")

    # Segment
    regions = segment_saree_regions(saree_img)
    print(f"Regions: blouse={regions.blouse.size}, petticoat={regions.petticoat.size}, "
          f"drape={regions.drape_body.size}, pallu={regions.pallu.size}")

    # Compose
    result = compose_saree_on_model(person_img, regions)
    print(f"Composed result size: {result.size}, mode: {result.mode}")

    result.save("/tmp/saree_compose_test.png")
    print("Saved to /tmp/saree_compose_test.png")
    print("=== Compose Service Self-Test Passed ===")
