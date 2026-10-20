"""
SnapnTry AI — Saree Draping Pipeline
=====================================
Specialized pipeline for draping sarees on target models.

Standard Western VTON models fail on sarees because sarees are unstitched
6-yard fabrics with dynamic pleats, pallu, and blouse — no fixed silhouette.
This module uses a 4-region segmentation + TPS warping + compose approach.

Sub-modules:
    saree_segmentor  — Splits saree flat-lay into 4 functional regions
    tps_warp         — Thin-Plate Spline warping of fabric panels to body
    compose_service  — Final compositor with pleat enhancement + blending
"""

from .saree_segmentor import SareeRegions, segment_saree_regions
from .tps_warp import warp_saree_panel
from .compose_service import compose_saree_on_model

__all__ = [
    "SareeRegions",
    "segment_saree_regions",
    "warp_saree_panel",
    "compose_saree_on_model",
]
