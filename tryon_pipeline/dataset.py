import os
import argparse
import numpy as np
import torch
from torch.utils.data import Dataset, DataLoader
from PIL import Image
from torchvision import transforms

# Import preprocessing helpers
try:
    from preprocess import (
        resize_and_pad,
        extract_garment_mask,
        generate_body_agnostic_mask,
        estimate_pose_guidance
    )
except ImportError:
    from .preprocess import (
        resize_and_pad,
        extract_garment_mask,
        generate_body_agnostic_mask,
        estimate_pose_guidance
    )

class VTONDataset(Dataset):
    """
    Custom Dataset for Virtual Try-On (Cat-VTON style spatial channel concatenation).
    Loads target person images and garment images, applies preprocessing, and returns tensors.
    """
    def __init__(self, data_root=None, category="upper_body", is_train=True, target_size=(512, 384)):
        self.data_root = data_root
        self.category = category
        self.is_train = is_train
        self.target_size = target_size
        
        # Define image transforms (normalize to [-1, 1])
        self.transform_img = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize([0.5, 0.5, 0.5], [0.5, 0.5, 0.5])
        ])
        
        # Define mask transform (no normalization, just tensor)
        self.transform_mask = transforms.Compose([
            transforms.ToTensor()
        ])
        
        self.pairs = []
        
        # If no data_root provided, or directory is empty, we will prepare synthetic mock files
        if not data_root or not os.path.exists(data_root):
            self.data_root = "./dummy_data"
            self._create_synthetic_data()
        
        self._load_pairs()

    def _create_synthetic_data(self):
        """
        Creates synthetic person and garment images for dry-run verification.
        """
        os.makedirs(os.path.join(self.data_root, "persons"), exist_ok=True)
        os.makedirs(os.path.join(self.data_root, "garments"), exist_ok=True)
        
        print(f"Creating synthetic VTON dataset at {self.data_root}...")
        
        # Generate 4 synthetic image pairs
        for i in range(4):
            person_path = os.path.join(self.data_root, "persons", f"person_{i}.png")
            garment_path = os.path.join(self.data_root, "garments", f"garment_{i}.png")
            
            # Create a mock person image: light pink background with a central "torso" and "face"
            person_arr = np.ones((600, 400, 3), dtype=np.uint8) * 240
            # torso (blue)
            person_arr[200:500, 100:300, :] = [100, 150, 255]
            # face (skin tone)
            person_arr[80:180, 150:250, :] = [255, 200, 180]
            # pants (dark grey)
            person_arr[500:580, 120:280, :] = [50, 50, 50]
            
            # Create a mock garment image: red t-shirt shape on dark background
            garment_arr = np.zeros((400, 400, 3), dtype=np.uint8)
            # draw a t-shirt contour
            cv2 = None
            try:
                import cv2
                # Draw t-shirt using cv2
                pts = np.array([[100, 100], [300, 100], [350, 180], [300, 200], [280, 180], 
                                [280, 350], [120, 350], [120, 180], [100, 200], [50, 180]], np.int32)
                cv2.fillPoly(garment_arr, [pts], (255, 50, 50))
            except ImportError:
                # Fallback: simple rectangle
                garment_arr[100:350, 100:300] = [255, 50, 50]
                
            Image.fromarray(person_arr).save(person_path)
            Image.fromarray(garment_arr).save(garment_path)

    def _load_pairs(self):
        """
        Scans the paths and matches person images with garment images.
        """
        person_dir = os.path.join(self.data_root, "persons")
        garment_dir = os.path.join(self.data_root, "garments")
        
        if not os.path.exists(person_dir) or not os.path.exists(garment_dir):
            return
            
        person_files = sorted([f for f in os.listdir(person_dir) if f.endswith(('.png', '.jpg', '.jpeg'))])
        garment_files = sorted([f for f in os.listdir(garment_dir) if f.endswith(('.png', '.jpg', '.jpeg'))])
        
        # Simple pair matching by index or filename
        for i in range(min(len(person_files), len(garment_files))):
            self.pairs.append({
                "person_path": os.path.join(person_dir, person_files[i]),
                "garment_path": os.path.join(garment_dir, garment_files[i])
            })
            
        print(f"Loaded {len(self.pairs)} image pairs from {self.data_root}.")

    def __len__(self):
        return len(self.pairs)

    def __getitem__(self, idx):
        pair = self.pairs[idx]
        
        # 1. Load images
        person_pil = Image.open(pair["person_path"]).convert("RGB")
        garment_pil = Image.open(pair["garment_path"]).convert("RGB")
        
        # 2. Resize and pad
        person_img = resize_and_pad(person_pil, self.target_size)
        garment_img = resize_and_pad(garment_pil, self.target_size)
        
        # 3. Extract garment and generate its binary mask
        _, garment_mask_pil = extract_garment_mask(garment_img)
        # Ensure garment_mask is of target_size
        garment_mask_pil = resize_and_pad(garment_mask_pil.convert("RGB"), self.target_size).convert("L")
        
        # 4. Generate agnostic person representations
        agnostic_person_pil, agnostic_mask_pil = generate_body_agnostic_mask(person_img, self.category)
        
        # 5. Extract pose skeleton
        pose_pil = estimate_pose_guidance(person_img)
        
        # 6. Apply transforms
        person_tensor = self.transform_img(person_img)
        garment_tensor = self.transform_img(garment_img)
        garment_mask_tensor = self.transform_mask(garment_mask_pil)
        agnostic_person_tensor = self.transform_img(agnostic_person_pil)
        agnostic_mask_tensor = self.transform_mask(agnostic_mask_pil)
        pose_tensor = self.transform_img(pose_pil)
        
        return {
            "person": person_tensor,                       # [3, H, W]
            "garment": garment_tensor,                     # [3, H, W]
            "garment_mask": garment_mask_tensor,           # [1, H, W]
            "agnostic_person": agnostic_person_tensor,     # [3, H, W] (masked person)
            "agnostic_mask": agnostic_mask_tensor,         # [1, H, W]
            "pose": pose_tensor                            # [3, H, W]
        }

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test VTONDataset implementation")
    parser.add_argument("--test", action="store_true", help="Run dataset shapes test and validation")
    args = parser.parse_args()
    
    if args.test:
        print("Testing VTONDataset...")
        dataset = VTONDataset(data_root=None, category="upper_body", target_size=(512, 384))
        print(f"Dataset length: {len(dataset)}")
        
        dataloader = DataLoader(dataset, batch_size=2, shuffle=True)
        batch = next(iter(dataloader))
        
        print("\nBatch tensor shapes verification:")
        print(f"Person tensor shape:          {batch['person'].shape} (Expected: [B, 3, 512, 384])")
        print(f"Garment tensor shape:         {batch['garment'].shape} (Expected: [B, 3, 512, 384])")
        print(f"Garment mask tensor shape:    {batch['garment_mask'].shape} (Expected: [B, 1, 512, 384])")
        print(f"Agnostic person shape:        {batch['agnostic_person'].shape} (Expected: [B, 3, 512, 384])")
        print(f"Agnostic mask shape:          {batch['agnostic_mask'].shape} (Expected: [B, 1, 512, 384])")
        print(f"Pose guidance shape:          {batch['pose'].shape} (Expected: [B, 3, 512, 384])")
        
        # Verify normalization ranges
        print("\nTensor Range Validations:")
        print(f"Person range:                 [{batch['person'].min():.2f}, {batch['person'].max():.2f}] (Expected: approx [-1.0, 1.0])")
        print(f"Garment range:                [{batch['garment'].min():.2f}, {batch['garment'].max():.2f}] (Expected: approx [-1.0, 1.0])")
        print(f"Agnostic mask range:          [{batch['agnostic_mask'].min():.2f}, {batch['agnostic_mask'].max():.2f}] (Expected: [0.0, 1.0])")
        
        print("\nDataset test completed successfully!")
    else:
        print("Dataset script imported successfully.")
