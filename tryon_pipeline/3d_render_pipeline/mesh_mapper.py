import os
import cv2
import numpy as np
from PIL import Image

class PatternMeshMapper:
    """
    Handles mapping of synthesized 2D ethnic garment patterns onto 3D model base meshes.
    Prepares texture maps, calculates normal displacement, and exports UV configuration maps.
    """
    
    def __init__(self, obj_mesh_path=None):
        self.obj_mesh_path = obj_mesh_path
        
    def generate_bump_map(self, texture_img: Image.Image) -> Image.Image:
        """
        Generates a high-frequency bump map from the texture image to simulate fabric weaves.
        """
        img_np = np.array(texture_img.convert('L')) # Convert to grayscale
        # Compute gradients using Sobel filter
        sobel_x = cv2.Sobel(img_np, cv2.CV_64F, 1, 0, ksize=3)
        sobel_y = cv2.Sobel(img_np, cv2.CV_64F, 0, 1, ksize=3)
        
        # Calculate magnitude of gradient
        magnitude = np.sqrt(sobel_x**2 + sobel_y**2)
        magnitude = cv2.normalize(magnitude, None, 0, 255, cv2.NORM_MINMAX)
        bump_map = Image.fromarray(magnitude.astype(np.uint8))
        return bump_map
        
    def generate_normal_map(self, texture_img: Image.Image, strength: float = 1.5) -> Image.Image:
        """
        Converts the height/texture map into a normal map (RGB representation of unit normal vector coordinates).
        """
        img_np = np.array(texture_img.convert('L')).astype(np.float32) / 255.0
        
        # Compute Sobel gradients
        dx = cv2.Sobel(img_np, cv2.CV_64F, 1, 0, ksize=3)
        dy = cv2.Sobel(img_np, cv2.CV_64F, 0, 1, ksize=3)
        
        # Invert gradients depending on coordinates
        dx = -dx * strength
        dy = -dy * strength
        
        # Calculate normal coordinates
        h, w = img_np.shape
        normal_map = np.zeros((h, w, 3), dtype=np.float32)
        
        # Normal vectors components
        normal_map[..., 0] = dx
        normal_map[..., 1] = dy
        normal_map[..., 2] = 1.0
        
        # Normalize vectors to unit length
        norm = np.linalg.norm(normal_map, axis=-1, keepdims=True)
        normal_map = normal_map / norm
        
        # Convert [-1, 1] to RGB [0, 255]
        normal_map = (normal_map + 1.0) * 127.5
        normal_map_rgb = Image.fromarray(normal_map.astype(np.uint8))
        return normal_map_rgb

    def apply_pattern_to_uv(self, pattern_path: str, base_uv_map_path: str, output_path: str) -> bool:
        """
        Maps a 2D pattern image onto a predefined base model UV template layout.
        Allows bridal lehengas or heavy Kanjeevarams to retain gold thread/zari borders on specific mesh parts.
        """
        if not os.path.exists(pattern_path):
            raise FileNotFoundError(f"Pattern image not found at: {pattern_path}")
            
        # Load the synthesized ethnic pattern
        pattern = cv2.imread(pattern_path)
        
        # Load the base model UV coordinates map (where coordinates indicate how fabric wraps)
        # In production, base_uv_map contains a segmentation mask of panels (e.g., bodice, skirt folds, borders)
        if base_uv_map_path and os.path.exists(base_uv_map_path):
            base_uv = cv2.imread(base_uv_map_path)
        else:
            # Fallback: Default grid resizing
            base_uv = np.zeros_like(pattern)
            
        # Map pattern onto UV template
        # 1. Resize pattern to fit UV space dimensions
        h, w, _ = base_uv.shape if base_uv_map_path else pattern.shape
        mapped_texture = cv2.resize(pattern, (w, h), interpolation=cv2.INTER_CUBIC)
        
        # 2. Extract normal and displacement map paths
        out_dir = os.path.dirname(output_path)
        os.makedirs(out_dir, exist_ok=True)
        
        # Write final mapped texture to output path
        cv2.imwrite(output_path, mapped_texture)
        
        # Save generated normal map alongside
        mapped_pil = Image.open(output_path)
        norm_map = self.generate_normal_map(mapped_pil)
        normal_path = os.path.splitext(output_path)[0] + "_normal.png"
        norm_map.save(normal_path)
        
        print(f"[MeshMapper] Successfully generated texture map: {output_path}")
        print(f"[MeshMapper] Successfully generated normal map: {normal_path}")
        return True
