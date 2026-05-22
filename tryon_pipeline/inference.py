import os
import argparse
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
import numpy as np
from diffusers import DDIMScheduler, AutoencoderKL, UNet2DConditionModel
from transformers import CLIPTextModel, CLIPTokenizer

# Import pipeline components
try:
    from preprocess import (
        resize_and_pad,
        extract_garment_mask,
        generate_body_agnostic_mask,
        estimate_pose_guidance
    )
    from model import patch_unet_for_vton, get_tiny_unet_for_testing
except ImportError:
    from .preprocess import (
        resize_and_pad,
        extract_garment_mask,
        generate_body_agnostic_mask,
        estimate_pose_guidance
    )
    from .model import patch_unet_for_vton, get_tiny_unet_for_testing

def parse_args():
    parser = argparse.ArgumentParser(description="End-to-End VTON Inference Script")
    parser.add_argument("--person_path", type=str, required=True, help="Path to person photo")
    parser.add_argument("--garment_path", type=str, required=True, help="Path to apparel item image")
    parser.add_argument("--category", type=str, default="upper_body", choices=["upper_body", "lower_body", "one_piece"])
    parser.add_argument("--checkpoint_dir", type=str, default=None, help="Directory of custom trained UNet weights")
    parser.add_argument("--pretrained_model_name", type=str, default="runwayml/stable-diffusion-inpainting")
    parser.add_argument("--output_path", type=str, default="./output_tryon.png", help="Path to save result image")
    parser.add_argument("--num_inference_steps", type=int, default=30)
    parser.add_argument("--guidance_scale", type=float, default=7.5)
    parser.add_argument("--mixed_precision", type=str, default="fp16", choices=["no", "fp16", "bf16"])
    parser.add_argument("--mock", action="store_true", help="Run in mock mode using a tiny local network")
    return parser.parse_args()

@torch.no_grad()
def main():
    args = parse_args()
    
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Running inference on device: {device}")
    
    # 1. Load and Preprocess Images
    print("Loading and preprocessing input images...")
    person_pil = Image.open(args.person_path).convert("RGB")
    garment_pil = Image.open(args.garment_path).convert("RGB")
    
    # Size inputs to model spec: 512x384
    target_size = (512, 384)
    person_img = resize_and_pad(person_pil, target_size)
    garment_img = resize_and_pad(garment_pil, target_size)
    
    # Extract garments and masks
    _, garment_mask_pil = extract_garment_mask(garment_img)
    garment_mask_pil = resize_and_pad(garment_mask_pil.convert("RGB"), target_size).convert("L")
    
    agnostic_person_pil, agnostic_mask_pil = generate_body_agnostic_mask(person_img, args.category)
    pose_pil = estimate_pose_guidance(person_img)
    
    # Convert inputs to torch tensors and normalize
    transform_img = lambda x: torch.from_numpy(np.array(x)).permute(2, 0, 1).float().div(255.0).mul(2.0).sub(1.0).unsqueeze(0).to(device)
    transform_mask = lambda x: torch.from_numpy(np.array(x)).unsqueeze(0).unsqueeze(0).float().div(255.0).to(device)
    
    person_tensor = transform_img(person_img)
    garment_tensor = transform_img(garment_img)
    agnostic_person_tensor = transform_img(agnostic_person_pil)
    agnostic_mask_tensor = transform_mask(agnostic_mask_pil)
    
    # 2. Initialize Models
    if args.mock:
        print("--- Running in MOCK Mode ---")
        # Load a tiny UNet configuration
        unet = get_tiny_unet_for_testing()
        unet = patch_unet_for_vton(unet)
        
        # Load checkpoint if supplied
        if args.checkpoint_dir:
            ckpt_file = os.path.join(args.checkpoint_dir, "pytorch_model.bin")
            if os.path.exists(ckpt_file):
                print(f"Loading mock weights from {ckpt_file}")
                unet.load_state_dict(torch.load(ckpt_file, map_location="cpu"))
        
        unet = unet.to(device)
        
        # Setup mock scheduler
        scheduler = DDIMScheduler(
            num_train_timesteps=1000,
            beta_start=0.00085,
            beta_end=0.012,
            beta_schedule="scaled_linear",
            clip_sample=False,
            set_alpha_to_one=False,
        )
        
        # Mock class implementations for VAE/TextEncoder
        class MockVAE:
            def encode(self, x):
                class LatentOutput:
                    def __init__(self, tensor):
                        self.latent_dist = self
                        self.tensor = tensor
                    def sample(self):
                        b, c, h, w = self.tensor.shape
                        return torch.randn(b, 4, h // 8, w // 8, device=self.tensor.device)
                return LatentOutput(x)
            def decode(self, latents):
                class DecodedOutput:
                    def __init__(self, tensor):
                        self.sample = tensor
                b, c, h, w = latents.shape
                # Decode back to image space: [B, 3, H*8, W*8]
                return DecodedOutput(torch.randn(b, 3, h * 8, w * 8, device=latents.device))
                
        class MockTextEncoder(nn.Module):
            def __init__(self, cross_attn_dim=32):
                super().__init__()
                self.cross_attn_dim = cross_attn_dim
            def forward(self, input_ids):
                b, seq_len = input_ids.shape
                return (torch.randn(b, seq_len, self.cross_attn_dim, device=input_ids.device),)
                
        class MockTokenizer:
            def __call__(self, text, padding, max_length, truncation, return_tensors):
                return {"input_ids": torch.zeros((len(text), max_length), dtype=torch.long)}
                
        vae = MockVAE()
        text_encoder = MockTextEncoder(cross_attn_dim=unet.config.cross_attention_dim).to(device)
        tokenizer = MockTokenizer()
        
    else:
        print(f"Loading pretrained models from: {args.pretrained_model_name}")
        scheduler = DDIMScheduler.from_pretrained(args.pretrained_model_name, subfolder="scheduler")
        tokenizer = CLIPTokenizer.from_pretrained(args.pretrained_model_name, subfolder="tokenizer")
        text_encoder = CLIPTextModel.from_pretrained(args.pretrained_model_name, subfolder="text_encoder").to(device)
        vae = AutoencoderKL.from_pretrained(args.pretrained_model_name, subfolder="vae").to(device)
        
        if args.checkpoint_dir:
            print(f"Loading fine-tuned UNet weights from {args.checkpoint_dir}")
            unet = UNet2DConditionModel.from_pretrained(args.checkpoint_dir).to(device)
        else:
            unet = UNet2DConditionModel.from_pretrained(args.pretrained_model_name, subfolder="unet")
            unet = patch_unet_for_vton(unet).to(device)
            
    unet.eval()
    
    # 3. Latent Encoding
    print("Encoding inputs into latent space...")
    if args.mock:
        z_agnostic = vae.encode(agnostic_person_tensor).sample()
        z_garment = vae.encode(garment_tensor).sample()
    else:
        z_agnostic = vae.encode(agnostic_person_tensor).latent_dist.sample() * 0.18215
        z_garment = vae.encode(garment_tensor).latent_dist.sample() * 0.18215
        
    latent_h, latent_w = z_agnostic.shape[2], z_agnostic.shape[3]
    
    # Downsample agnostic mask to latents
    m_latent = F.interpolate(agnostic_mask_tensor, size=(latent_h, latent_w), mode="nearest")
    
    # 4. Text Encoding
    prompts = ["a photo of a person trying on a garment"]
    if args.mock:
        inputs = tokenizer(prompts, padding="max_length", max_length=77, truncation=True, return_tensors="pt")
        encoder_hidden_states = text_encoder(inputs["input_ids"].to(device))[0]
    else:
        inputs = tokenizer(prompts, padding="max_length", max_length=77, truncation=True, return_tensors="pt")
        encoder_hidden_states = text_encoder(inputs.input_ids.to(device))[0]
        
    # Support Classifier-Free Guidance (CFG) by duplicating embeddings
    if args.guidance_scale > 1.0:
        uncond_prompts = [""]
        if args.mock:
            uncond_inputs = tokenizer(uncond_prompts, padding="max_length", max_length=77, truncation=True, return_tensors="pt")
            uncond_hidden_states = text_encoder(uncond_inputs["input_ids"].to(device))[0]
        else:
            uncond_inputs = tokenizer(uncond_prompts, padding="max_length", max_length=77, truncation=True, return_tensors="pt")
            uncond_hidden_states = text_encoder(uncond_inputs.input_ids.to(device))[0]
            
        encoder_hidden_states = torch.cat([uncond_hidden_states, encoder_hidden_states], dim=0)
        
    # 5. Denoising Loop
    scheduler.set_timesteps(args.num_inference_steps)
    
    # Initialize starting noise
    latents = torch.randn_like(z_agnostic)
    
    for t in scheduler.timesteps:
        # Scale model inputs if scheduler requires it
        latent_model_input = scheduler.scale_model_input(latents, t)
        
        # Concatenate inputs along the channel dimension
        # Shape: [B, 13, H_latent, W_latent]
        # x_concat = Concat(latent_model_input, z_agnostic, m_latent, z_garment)
        x_concat = torch.cat([latent_model_input, z_agnostic, m_latent, z_garment], dim=1)
        
        if args.guidance_scale > 1.0:
            # For CFG we double the input (for uncond and cond branches)
            x_concat_double = torch.cat([x_concat] * 2, dim=0)
            
            # Predict noise
            noise_pred = unet(
                sample=x_concat_double,
                timestep=t,
                encoder_hidden_states=encoder_hidden_states
            ).sample
            
            # Perform CFG
            noise_pred_uncond, noise_pred_text = noise_pred.chunk(2)
            noise_pred = noise_pred_uncond + args.guidance_scale * (noise_pred_text - noise_pred_uncond)
        else:
            noise_pred = unet(
                sample=x_concat,
                timestep=t,
                encoder_hidden_states=encoder_hidden_states
            ).sample
            
        # Step scheduler
        latents = scheduler.step(noise_pred, t, latents).prev_sample
        
    # 6. Decode Latents to Image
    print("Decoding final latents using VAE...")
    if args.mock:
        decoded = vae.decode(latents).sample
    else:
        decoded = vae.decode(latents / 0.18215).sample
        
    # Post-process image tensor: shift to [0, 1] range, convert to channel-last, scale to uint8
    image_tensor = decoded.clamp(-1.0, 1.0)
    image_tensor = (image_tensor + 1.0) / 2.0
    image_np = image_tensor.squeeze(0).permute(1, 2, 0).cpu().numpy()
    
    # If mock, blend the mock tensor with the original image for visual debugging
    if args.mock:
        # Create a visually identifiable output: overlay the target garment on the agnostic region
        person_arr = np.array(person_img)
        garment_arr = np.array(garment_img)
        mask_arr = np.array(agnostic_mask_pil)
        
        output_np = person_arr.copy()
        # copy garment colors in mask area
        output_np[mask_arr == 255] = garment_arr[mask_arr == 255]
        
        # Add subtle green border around fitting area to show body segment boundaries
        contours, _ = cv2 = None, None
        try:
            import cv2
            contours, _ = cv2.findContours(mask_arr, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            cv2.drawContours(output_np, contours, -1, (0, 255, 0), 2)
        except Exception:
            pass
            
        output_pil = Image.fromarray(output_np)
    else:
        output_pil = Image.fromarray((image_np * 255).astype(np.uint8))
        
    # Save image
    output_pil.save(args.output_path)
    print(f"Successfully generated try-on output and saved to: {args.output_path}")

if __name__ == "__main__":
    main()
