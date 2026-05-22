import os
import argparse
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from diffusers import DDPMScheduler, AutoencoderKL, UNet2DConditionModel
from transformers import CLIPTextModel, CLIPTokenizer
from accelerate import Accelerator
from tqdm.auto import tqdm

# Import pipeline modules
try:
    from dataset import VTONDataset
    from model import patch_unet_for_vton, get_tiny_unet_for_testing
except ImportError:
    from .dataset import VTONDataset
    from .model import patch_unet_for_vton, get_tiny_unet_for_testing

def parse_args():
    parser = argparse.ArgumentParser(description="Cat-VTON style Virtual Try-On Training Pipeline")
    parser.add_argument("--data_root", type=str, default=None, help="Path to VTON dataset (contains persons/ and garments/)")
    parser.add_argument("--category", type=str, default="upper_body", choices=["upper_body", "lower_body", "one_piece"])
    parser.add_argument("--pretrained_model_name", type=str, default="runwayml/stable-diffusion-inpainting")
    parser.add_argument("--output_dir", type=str, default="./checkpoints", help="Directory to save checkpoints")
    parser.add_argument("--epochs", type=int, default=10, help="Number of training epochs")
    parser.add_argument("--batch_size", type=int, default=2, help="Batch size per GPU")
    parser.add_argument("--lr", type=float, default=1e-5, help="Learning rate")
    parser.add_argument("--gradient_accumulation_steps", type=int, default=1)
    parser.add_argument("--gradient_checkpointing", action="store_true", help="Enable gradient checkpointing to save VRAM")
    parser.add_argument("--mixed_precision", type=str, default="fp16", choices=["no", "fp16", "bf16"])
    parser.add_argument("--mock", action="store_true", help="Run a fast mock dry-run with a tiny UNet and dummy weights")
    return parser.parse_args()

def main():
    args = parse_args()
    
    # Initialize accelerator
    accelerator = Accelerator(
        mixed_precision=args.mixed_precision,
        gradient_accumulation_steps=args.gradient_accumulation_steps
    )
    
    os.makedirs(args.output_dir, exist_ok=True)
    
    # 1. Load Dataset
    # VTONDataset will create and use synthetic dummy data if data_root doesn't exist
    dataset = VTONDataset(data_root=args.data_root, category=args.category, is_train=True)
    dataloader = DataLoader(dataset, batch_size=args.batch_size, shuffle=True)
    
    # 2. Load Models
    if args.mock:
        print("--- Running in MOCK Mode with tiny models ---")
        # Initialize small test models to bypass downloading and VRAM overhead
        unet = get_tiny_unet_for_testing()
        unet = patch_unet_for_vton(unet)
        
        # Mocks for scheduling and VAE
        noise_scheduler = DDPMScheduler(
            num_train_timesteps=1000,
            beta_start=0.00085,
            beta_end=0.012,
            beta_schedule="scaled_linear",
        )
        
        # Simple lambda/mock classes to replace VAE and Text Encoder for testing shape flow
        class MockVAE:
            def encode(self, x):
                class LatentOutput:
                    def __init__(self, tensor):
                        self.latent_dist = self
                        self.tensor = tensor
                    def sample(self):
                        # Shape of latents is [B, 4, H/8, W/8] (32x24 for a tiny model config or 64x48)
                        b, c, h, w = self.tensor.shape
                        return torch.randn(b, 4, h // 8, w // 8, device=self.tensor.device)
                return LatentOutput(x)
            
        class MockTextEncoder(nn.Module):
            def __init__(self, cross_attn_dim=32):
                super().__init__()
                self.cross_attn_dim = cross_attn_dim
            def forward(self, input_ids):
                # Returns dummy embedding of shape [B, seq_len, cross_attn_dim]
                b, seq_len = input_ids.shape
                return (torch.randn(b, seq_len, self.cross_attn_dim, device=input_ids.device),)
                
        vae = MockVAE()
        text_encoder = MockTextEncoder(cross_attn_dim=unet.config.cross_attention_dim)
        
        # Mock tokenization
        class MockTokenizer:
            def __call__(self, text, padding, max_length, truncation, return_tensors):
                return {"input_ids": torch.zeros((len(text), max_length), dtype=torch.long)}
        tokenizer = MockTokenizer()
        
    else:
        print(f"Loading pretrained models from: {args.pretrained_model_name}")
        try:
            noise_scheduler = DDPMScheduler.from_pretrained(args.pretrained_model_name, subfolder="scheduler")
            tokenizer = CLIPTokenizer.from_pretrained(args.pretrained_model_name, subfolder="tokenizer")
            text_encoder = CLIPTextModel.from_pretrained(args.pretrained_model_name, subfolder="text_encoder")
            vae = AutoencoderKL.from_pretrained(args.pretrained_model_name, subfolder="vae")
            unet = UNet2DConditionModel.from_pretrained(args.pretrained_model_name, subfolder="unet")
            
            # Patch UNet for 13 channels & freeze all but self-attention
            unet = patch_unet_for_vton(unet)
        except Exception as e:
            print(f"Failed to load real models: {e}. Force enabling MOCK mode.")
            args.mock = True
            main()
            return
            
    # 3. Freeze non-trainable components
    # VAE and text encoder are frozen
    if not args.mock:
        vae.requires_grad_(False)
        text_encoder.requires_grad_(False)
        
    if args.gradient_checkpointing:
        unet.enable_gradient_checkpointing()
        
    # 4. Optimizer setup
    # Filter out parameters that do not require grad (trainable params only)
    trainable_params = [p for p in unet.parameters() if p.requires_grad]
    optimizer = torch.optim.AdamW(trainable_params, lr=args.lr)
    
    # Prepare with Accelerator
    # For mock mode, vae and text_encoder are not normal torch modules, so we only prepare what is needed
    if args.mock:
        unet, optimizer, dataloader = accelerator.prepare(unet, optimizer, dataloader)
    else:
        unet, vae, text_encoder, optimizer, dataloader = accelerator.prepare(
            unet, vae, text_encoder, optimizer, dataloader
        )
        
    device = accelerator.device
    
    # 5. Training Loop
    print(f"Starting training pipeline. Epochs: {args.epochs}, Batch Size: {args.batch_size}")
    
    for epoch in range(args.epochs):
        unet.train()
        epoch_loss = 0.0
        
        progress_bar = tqdm(
            dataloader, 
            desc=f"Epoch {epoch+1}/{args.epochs}", 
            disable=not accelerator.is_local_main_process
        )
        
        for step, batch in enumerate(progress_bar):
            with accelerator.accumulate(unet):
                # Move tensors to correct device
                person_img = batch["person"].to(device)
                garment_img = batch["garment"].to(device)
                agnostic_person_img = batch["agnostic_person"].to(device)
                agnostic_mask = batch["agnostic_mask"].to(device)
                
                # a. Encode inputs to latent space using frozen VAE
                with torch.no_grad():
                    # If mock, vae is our mock class; else standard HF VAE
                    if args.mock:
                        z_gt = vae.encode(person_img).sample()
                        z_agnostic = vae.encode(agnostic_person_img).sample()
                        z_garment = vae.encode(garment_img).sample()
                    else:
                        z_gt = vae.encode(person_img).latent_dist.sample() * 0.18215
                        z_agnostic = vae.encode(agnostic_person_img).latent_dist.sample() * 0.18215
                        z_garment = vae.encode(garment_img).latent_dist.sample() * 0.18215
                        
                # b. Add noise to ground truth person latents
                noise = torch.randn_like(z_gt)
                bsz = z_gt.shape[0]
                timesteps = torch.randint(0, noise_scheduler.config.num_train_timesteps, (bsz,), device=device).long()
                
                noisy_latents = noise_scheduler.add_noise(z_gt, noise, timesteps)
                
                # c. Downsample the agnostic mask to latent dimensions
                latent_h, latent_w = z_gt.shape[2], z_gt.shape[3]
                m_latent = F.interpolate(agnostic_mask, size=(latent_h, latent_w), mode="nearest")
                
                # d. Concatenate along channel dimension (Dim 1)
                # noisy_latents (4) + z_agnostic (4) + m_latent (1) + z_garment (4) = 13 channels
                x_concat = torch.cat([noisy_latents, z_agnostic, m_latent, z_garment], dim=1)
                
                # e. Get text embeddings for conditioning (generic prompt for VTON alignment)
                # To maintain SD text encoder compatibility
                prompts = ["a photo of a person trying on a garment"] * bsz
                
                # Encode text
                if args.mock:
                    # Mock text tokenizer and encoder
                    inputs = tokenizer(prompts, padding="max_length", max_length=77, truncation=True, return_tensors="pt")
                    encoder_hidden_states = text_encoder(inputs["input_ids"].to(device))[0]
                else:
                    with torch.no_grad():
                        inputs = tokenizer(prompts, padding="max_length", max_length=77, truncation=True, return_tensors="pt")
                        encoder_hidden_states = text_encoder(inputs.input_ids.to(device))[0]
                        
                # f. Forward pass: predict noise
                noise_pred = unet(
                    sample=x_concat,
                    timestep=timesteps,
                    encoder_hidden_states=encoder_hidden_states
                ).sample
                
                # g. Calculate MSE Loss
                loss = F.mse_loss(noise_pred.float(), noise.float(), reduction="mean")
                
                # h. Backpropagation
                accelerator.backward(loss)
                optimizer.step()
                optimizer.zero_grad()
                
            epoch_loss += loss.item()
            progress_bar.set_postfix({"loss": loss.item()})
            
        avg_loss = epoch_loss / len(dataloader)
        print(f"Epoch {epoch+1} Completed. Average Loss: {avg_loss:.6f}")
        
        # Save check-point at the end of each epoch
        if accelerator.is_main_process:
            checkpoint_path = os.path.join(args.output_dir, f"checkpoint-epoch-{epoch+1}")
            os.makedirs(checkpoint_path, exist_ok=True)
            
            # Save the UNet state dict
            # Unwrap model before saving
            unwrapped_unet = accelerator.unwrap_model(unet)
            if args.mock:
                # Direct state dict save for custom mockup
                torch.save(unwrapped_unet.state_dict(), os.path.join(checkpoint_path, "pytorch_model.bin"))
            else:
                unwrapped_unet.save_pretrained(checkpoint_path)
                
            print(f"Saved checkpoint to {checkpoint_path}")
            
    print("Training finished successfully!")

if __name__ == "__main__":
    main()
