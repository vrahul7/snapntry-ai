"""
tps_warp.py — SnapnTry AI Saree Pipeline
=========================================
Applies Thin-Plate Spline (TPS) warping to fit saree fabric panels
to the geometry of the target model's body.

Why TPS?
    Saree fabric is a non-rigid, deformable surface. Simple affine/perspective
    transforms are insufficient for the curved, draped geometry of a saree.
    TPS is a smooth, globally-consistent deformation that interpolates
    between sparse control point pairs — exactly what's needed to warp
    a flat saree panel into a body-conformant shape.

Algorithm:
    1. Detect source control points on the saree fabric via SIFT keypoints
       (falling back to a uniform grid if SIFT finds too few features).
    2. Detect target anchor points on the person's body via:
        - Canny edge detection on the body silhouette
        - Contour finding to extract the torso/body boundary
        - Geometric sampling of the boundary to produce anchor points
    3. Match source → target control points (nearest neighbour on a 
       normalized grid, column-wise from left-to-right)
    4. Compute the TPS mapping using scipy.interpolate.RBFInterpolator 
       with kernel='thin_plate_spline'
    5. Remap the source image pixel coordinates through the TPS map to
       produce the warped panel.

Author: SnapnTry AI
"""

import cv2
import numpy as np
from PIL import Image
from typing import Optional, Tuple


# ──────────────────────────────────────────────────────────────────────────────
# Control Point Extraction
# ──────────────────────────────────────────────────────────────────────────────

def _extract_sift_control_points(
    image_np: np.ndarray,
    n_points: int = 16,
) -> np.ndarray:
    """
    Extracts n_points source control points from the fabric image via SIFT.
    
    Falls back to a uniform grid if SIFT finds fewer than n_points / 2 keypoints.

    Returns:
        pts: (N, 2) array of (x, y) control points in image coordinates.
    """
    gray = cv2.cvtColor(image_np, cv2.COLOR_RGBA2GRAY) if image_np.shape[2] == 4 else \
           cv2.cvtColor(image_np, cv2.COLOR_RGB2GRAY)

    h, w = gray.shape

    # Try SIFT (available in OpenCV 4+)
    try:
        sift = cv2.SIFT_create()
        keypoints, _ = sift.detectAndCompute(gray, None)

        if len(keypoints) >= n_points // 2:
            # Sort by response (strongest features first)
            keypoints = sorted(keypoints, key=lambda kp: kp.response, reverse=True)
            pts = np.array([[kp.pt[0], kp.pt[1]] for kp in keypoints[:n_points]])
            # Sort points left-to-right, top-to-bottom for consistent matching
            pts = pts[np.lexsort((pts[:, 0], pts[:, 1]))]
            return pts.astype(np.float32)
    except Exception as e:
        print(f"[TPS Warp] SIFT failed: {e}")

    # Fallback: uniform grid of control points
    print("[TPS Warp] Using uniform grid control points (SIFT fallback)")
    grid_side = int(np.sqrt(n_points))
    xs = np.linspace(w * 0.1, w * 0.9, grid_side)
    ys = np.linspace(h * 0.1, h * 0.9, grid_side)
    xg, yg = np.meshgrid(xs, ys)
    pts = np.stack([xg.ravel(), yg.ravel()], axis=1)
    return pts.astype(np.float32)


def _extract_body_anchor_points(
    person_np: np.ndarray,
    region: str = "upper",
    n_points: int = 16,
) -> np.ndarray:
    """
    Extracts body anchor points from the person image using contour analysis.
    
    Args:
        person_np: RGB numpy array of the person image.
        region: "upper" (torso), "lower" (hips/legs), "full" (full body).
        n_points: Number of anchor points to return.

    Returns:
        pts: (N, 2) array of (x, y) target anchor points.
    """
    h, w = person_np.shape[:2]
    gray = cv2.cvtColor(person_np, cv2.COLOR_RGB2GRAY)

    # Detect body silhouette using adaptive edge detection
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blurred, 30, 100)

    # Dilate edges to close small gaps
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    edges = cv2.dilate(edges, kernel)

    # Find contours
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    if not contours:
        return _fallback_anchor_points(h, w, region, n_points)

    # Use the largest contour (body silhouette)
    largest = max(contours, key=cv2.contourArea)
    contour_pts = largest.reshape(-1, 2).astype(np.float32)

    # Filter to the relevant body region
    if region == "upper":
        y_min, y_max = h * 0.15, h * 0.65
    elif region == "lower":
        y_min, y_max = h * 0.50, h * 0.95
    else:  # full
        y_min, y_max = h * 0.10, h * 0.95

    region_pts = contour_pts[
        (contour_pts[:, 1] >= y_min) & (contour_pts[:, 1] <= y_max)
    ]

    if len(region_pts) < n_points:
        return _fallback_anchor_points(h, w, region, n_points)

    # Sample n_points evenly from the region boundary
    indices = np.linspace(0, len(region_pts) - 1, n_points, dtype=int)
    sampled = region_pts[indices]
    # Sort left-to-right, top-to-bottom for consistent matching with source
    sampled = sampled[np.lexsort((sampled[:, 0], sampled[:, 1]))]
    return sampled.astype(np.float32)


def _fallback_anchor_points(h: int, w: int, region: str, n_points: int) -> np.ndarray:
    """Generates a body-proportional grid of anchor points as fallback."""
    print(f"[TPS Warp] Using fallback anchor grid for region={region}")
    grid_side = int(np.sqrt(n_points))

    if region == "upper":
        xs = np.linspace(w * 0.20, w * 0.80, grid_side)
        ys = np.linspace(h * 0.20, h * 0.65, grid_side)
    elif region == "lower":
        xs = np.linspace(w * 0.20, w * 0.80, grid_side)
        ys = np.linspace(h * 0.50, h * 0.92, grid_side)
    else:
        xs = np.linspace(w * 0.15, w * 0.85, grid_side)
        ys = np.linspace(h * 0.15, h * 0.90, grid_side)

    xg, yg = np.meshgrid(xs, ys)
    pts = np.stack([xg.ravel(), yg.ravel()], axis=1)
    return pts.astype(np.float32)


# ──────────────────────────────────────────────────────────────────────────────
# TPS Computation
# ──────────────────────────────────────────────────────────────────────────────

def _compute_tps_warp(
    src_pts: np.ndarray,
    dst_pts: np.ndarray,
    target_h: int,
    target_w: int,
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Computes the TPS mapping from dst_pts → src_pts and returns
    the (map_x, map_y) remap arrays for cv2.remap.

    We compute the inverse mapping (target pixel → source pixel) to
    avoid gaps from forward warping.

    Args:
        src_pts: (N, 2) source control points in (x, y) format
        dst_pts: (N, 2) target control points in (x, y) format  
        target_h, target_w: Output image dimensions

    Returns:
        map_x: (H, W) float32 map of x source coordinates
        map_y: (H, W) float32 map of y source coordinates
    """
    try:
        from scipy.interpolate import RBFInterpolator

        # RBFInterpolator takes (y, x) convention
        src_yx = src_pts[:, [1, 0]]  # Convert (x,y) → (y,x)
        dst_yx = dst_pts[:, [1, 0]]

        # Build inverse mapping: dst → src
        # interp maps dst_yx → src_yx
        interp_y = RBFInterpolator(dst_yx, src_yx[:, 0], kernel='thin_plate_spline', smoothing=1.0)
        interp_x = RBFInterpolator(dst_yx, src_yx[:, 1], kernel='thin_plate_spline', smoothing=1.0)

        # Create a dense grid of target pixel coordinates
        yy, xx = np.mgrid[0:target_h, 0:target_w]
        grid_pts = np.stack([yy.ravel(), xx.ravel()], axis=1).astype(np.float64)

        # Evaluate the inverse TPS mapping at every target pixel
        src_y_coords = interp_y(grid_pts).reshape(target_h, target_w)
        src_x_coords = interp_x(grid_pts).reshape(target_h, target_w)

        map_x = src_x_coords.astype(np.float32)
        map_y = src_y_coords.astype(np.float32)

        return map_x, map_y

    except ImportError:
        print("[TPS Warp] scipy not available — using affine approximation fallback")
        return _affine_fallback_maps(src_pts, dst_pts, target_h, target_w)

    except Exception as e:
        print(f"[TPS Warp] TPS computation failed ({e}) — using affine fallback")
        return _affine_fallback_maps(src_pts, dst_pts, target_h, target_w)


def _affine_fallback_maps(
    src_pts: np.ndarray,
    dst_pts: np.ndarray,
    target_h: int,
    target_w: int,
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Fallback: Computes a best-fit affine transform and returns remap maps.
    Used when scipy is not available.
    """
    # Use least-squares affine transform from dst_pts → src_pts
    n = min(len(src_pts), len(dst_pts), 3)
    src_3 = src_pts[:n].astype(np.float32)
    dst_3 = dst_pts[:n].astype(np.float32)

    M, _ = cv2.estimateAffinePartial2D(dst_3, src_3)
    if M is None:
        # Identity fallback
        M = np.eye(2, 3, dtype=np.float32)

    # Build dense maps from affine matrix
    yy, xx = np.mgrid[0:target_h, 0:target_w].astype(np.float32)
    map_x = M[0, 0] * xx + M[0, 1] * yy + M[0, 2]
    map_y = M[1, 0] * xx + M[1, 1] * yy + M[1, 2]

    return map_x.astype(np.float32), map_y.astype(np.float32)


# ──────────────────────────────────────────────────────────────────────────────
# Public API
# ──────────────────────────────────────────────────────────────────────────────

def warp_saree_panel(
    panel_image: Image.Image,
    person_image: Image.Image,
    body_region: str = "full",
    target_size: Optional[Tuple[int, int]] = None,
    n_control_points: int = 16,
) -> Image.Image:
    """
    Warps a saree panel image to conform to the geometry of a target model's body.

    Args:
        panel_image: RGBA PIL Image of a saree region (blouse/drape/pallu/petticoat).
        person_image: RGB PIL Image of the target model.
        body_region: Which body region to anchor to — "upper", "lower", or "full".
        target_size: (width, height) of output. Defaults to person_image.size.
        n_control_points: Number of TPS control point pairs (must be a perfect square).

    Returns:
        Warped RGBA PIL Image aligned to the target model's body.

    Example:
        >>> warped_blouse = warp_saree_panel(regions.blouse, model_img, body_region="upper")
    """
    # Normalize n_control_points to be a perfect square
    grid_side = int(np.sqrt(n_control_points))
    n_control_points = grid_side * grid_side

    # Convert to numpy
    if panel_image.mode != "RGBA":
        panel_image = panel_image.convert("RGBA")
    if person_image.mode != "RGB":
        person_image = person_image.convert("RGB")

    panel_np = np.array(panel_image)
    person_np = np.array(person_image)

    person_h, person_w = person_np.shape[:2]
    target_w, target_h = target_size if target_size else (person_w, person_h)

    print(f"[TPS Warp] Warping panel ({panel_np.shape[1]}x{panel_np.shape[0]}) "
          f"to body region '{body_region}' ({target_w}x{target_h})")

    # Resize panel to target dimensions for warping
    panel_resized = cv2.resize(
        panel_np,
        (target_w, target_h),
        interpolation=cv2.INTER_LANCZOS4
    )

    # Extract source control points from the panel
    src_pts = _extract_sift_control_points(panel_resized, n_points=n_control_points)

    # Extract target anchor points from the person's body
    dst_pts = _extract_body_anchor_points(person_np, region=body_region, n_points=n_control_points)

    # Scale dst_pts to target dimensions if person image differs
    if (person_w, person_h) != (target_w, target_h):
        dst_pts[:, 0] *= target_w / person_w
        dst_pts[:, 1] *= target_h / person_h

    # Ensure equal number of points
    n = min(len(src_pts), len(dst_pts))
    src_pts = src_pts[:n]
    dst_pts = dst_pts[:n]

    # Compute TPS maps
    map_x, map_y = _compute_tps_warp(src_pts, dst_pts, target_h, target_w)

    # Remap each channel separately (RGBA)
    warped_channels = []
    for c in range(4):
        channel = panel_resized[:, :, c].astype(np.float32)
        warped_c = cv2.remap(
            channel,
            map_x,
            map_y,
            interpolation=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_CONSTANT,
            borderValue=0,
        )
        warped_channels.append(warped_c.astype(np.uint8))

    warped_np = np.stack(warped_channels, axis=2)

    print(f"[TPS Warp] Warp complete. Output shape: {warped_np.shape}")
    return Image.fromarray(warped_np, mode="RGBA")


# ──────────────────────────────────────────────────────────────────────────────
# Self-test
# ──────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=== TPS Warp Self-Test ===")

    # Create a dummy saree panel (RGBA)
    panel_np = np.zeros((200, 150, 4), dtype=np.uint8)
    panel_np[:, :, 0] = 180  # Red channel
    panel_np[:, :, 1] = 80   # Green channel
    panel_np[:, :, 3] = 200  # Alpha (mostly opaque)
    panel = Image.fromarray(panel_np, mode="RGBA")

    # Create a dummy person image (RGB)
    person_np = np.random.randint(80, 200, (400, 300, 3), dtype=np.uint8)
    person = Image.fromarray(person_np, mode="RGB")

    # Test warp
    warped = warp_saree_panel(panel, person, body_region="upper")
    print(f"Warped panel size: {warped.size}, mode: {warped.mode}")
    assert warped.size == person.size, "Warped size should match person size"
    print("=== TPS Warp Self-Test Passed ===")
