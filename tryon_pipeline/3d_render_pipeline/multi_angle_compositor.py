import os
from PIL import Image, ImageDraw, ImageFont

class MultiAngleCompositor:
    """
    Composites the front, 3/4 profile, and back renders into a single 
    polished catalog sheet layout (a multi-angle presentation).
    """
    
    def __init__(self, output_width=1800, output_height=1200):
        self.output_width = output_width
        self.output_height = output_height
        
    def create_catalog_collage(self, front_path: str, three_quarter_path: str, back_path: str, save_path: str, brand_name="SNAPNTRY AI ELITE") -> bool:
        """
        Creates a side-by-side layout: [ FRONT | 3/4 PROFILE | BACK ]
        with glassmorphic border styling and brand typography.
        """
        # Load images
        try:
            front = Image.open(front_path)
            three_q = Image.open(three_quarter_path)
            back = Image.open(back_path)
        except Exception as e:
            print(f"[MultiAngleCompositor] Error loading renders: {e}")
            return False
            
        # Target sizes for the three frames
        frame_w = self.output_width // 3
        frame_h = self.output_height
        
        # Resize inputs to fit
        front = front.resize((frame_w, frame_h), Image.Resampling.LANCZOS)
        three_q = three_q.resize((frame_w, frame_h), Image.Resampling.LANCZOS)
        back = back.resize((frame_w, frame_h), Image.Resampling.LANCZOS)
        
        # Create master canvas
        collage = Image.new('RGB', (self.output_width, self.output_height), (245, 245, 247)) # Sleek light-grey studio floor
        
        # Paste frames side-by-side
        collage.paste(front, (0, 0))
        collage.paste(three_q, (frame_w, 0))
        collage.paste(back, (frame_w * 2, 0))
        
        # Draw separators and text overlays
        draw = ImageDraw.Draw(collage)
        
        # Draw subtle white separators
        draw.line([(frame_w, 0), (frame_w, frame_h)], fill=(255, 255, 255), width=4)
        draw.line([(frame_w * 2, 0), (frame_w * 2, frame_h)], fill=(255, 255, 255), width=4)
        
        # Draw branding card at the bottom (mocking glassmorphism)
        card_h = 80
        card_y = frame_h - card_h
        
        # Draw translucent background card (semi-transparent white/gray)
        overlay = Image.new('RGBA', collage.size, (0,0,0,0))
        overlay_draw = ImageDraw.Draw(overlay)
        overlay_draw.rectangle([0, card_y, self.output_width, frame_h], fill=(15, 15, 20, 180)) # Semi-transparent dark overlay
        collage = Image.alpha_composite(collage.convert('RGBA'), overlay).convert('RGB')
        
        # Draw labels
        draw_labels = ImageDraw.Draw(collage)
        
        # Draw label texts
        # Since standard fonts might not be available, we draw simple text or lines
        try:
            # Try to load a clean font, or fallback to default
            font = ImageFont.load_default()
        except:
            font = None
            
        # Draw text labels for angles
        draw_labels.text((40, card_y + 30), "FRONT ANGLE (0°)", fill=(255, 255, 255), font=font)
        draw_labels.text((frame_w + 40, card_y + 30), "3/4 MESH PROFILE (45°)", fill=(255, 255, 255), font=font)
        draw_labels.text((frame_w * 2 + 40, card_y + 30), "BACK ANGLE (180°)", fill=(255, 255, 255), font=font)
        
        # Center brand label
        draw_labels.text((self.output_width - 250, card_y + 30), f"⚡ {brand_name}", fill=(255, 215, 0), font=font) # Golden brand label
        
        # Save collage
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        collage.save(save_path, "PNG")
        print(f"[MultiAngleCompositor] Successfully created multi-angle catalog sheet: {save_path}")
        return True
