import argparse
import torch
import torch.nn as nn
from diffusers import UNet2DConditionModel

def load_catvton_unet(
    pretrained_model_name_or_path: str = "zhengchong/CatVTON",
    subfolder: str = "vitonhd-16k-512/attention"
) -> UNet2DConditionModel:
    """
    Loads the pretrained Cat-VTON UNet model from Hugging Face by downloading
    attention weights and merging them into the stable-diffusion-inpainting base.
    """
    print(f"Loading base inpainting UNet runwayml/stable-diffusion-inpainting...")
    unet = UNet2DConditionModel.from_pretrained(
        "runwayml/stable-diffusion-inpainting",
        subfolder="unet"
    )
    
    print(f"Downloading attention weights from HF repository: {pretrained_model_name_or_path}/{subfolder}")
    from huggingface_hub import hf_hub_download
    
    # Try downloading model.safetensors first
    try:
        print("Trying to download model.safetensors...")
        weights_path = hf_hub_download(
            repo_id=pretrained_model_name_or_path,
            filename=f"{subfolder}/model.safetensors"
        )
        from safetensors.torch import load_file
        state_dict = load_file(weights_path)
        print(f"Successfully loaded safetensors weights from {weights_path}")
    except Exception as e:
        print(f"Could not load safetensors: {e}. Trying pytorch_model.bin...")
        weights_path = hf_hub_download(
            repo_id=pretrained_model_name_or_path,
            filename=f"{subfolder}/pytorch_model.bin"
        )
        state_dict = torch.load(weights_path, map_location="cpu")
        print(f"Successfully loaded pytorch_model.bin weights from {weights_path}")
        
    print("Merging attention weights into base UNet with strict=False...")
    missing_keys, unexpected_keys = unet.load_state_dict(state_dict, strict=False)
    print(f"Weights loaded. Missing keys count: {len(missing_keys)}, Unexpected keys count: {len(unexpected_keys)}")
    return unet

def freeze_unet_for_vton(unet: UNet2DConditionModel) -> UNet2DConditionModel:
    """
    Freezes all parameters of the UNet except for self-attention blocks (attn1).
    """
    # Freeze all parameters
    for param in unet.parameters():
        param.requires_grad = False
        
    # Unfreeze self-attention blocks (attn1 in Transformer2DModel blocks)
    for name, module in unet.named_modules():
        if "attn1" in name:
            for param in module.parameters():
                param.requires_grad = True
                
    unfrozen_params = 0
    total_params = 0
    for param in unet.parameters():
        total_params += param.numel()
        if param.requires_grad:
            unfrozen_params += param.numel()
            
    print(f"UNet Total Parameters:    {total_params:,}")
    print(f"UNet Trainable Parameters: {unfrozen_params:,} ({unfrozen_params / total_params * 100:.2f}%)")
    
    return unet

def get_tiny_unet_for_testing() -> UNet2DConditionModel:
    """
    Creates a tiny UNet model configuration for fast testing without downloading weights.
    """
    config = {
        "sample_size": 64,
        "in_channels": 9, # Cat-VTON 9 channels input
        "out_channels": 4,
        "layers_per_block": 1,
        "block_out_channels": (32, 64),
        "down_block_types": ("DownBlock2D", "CrossAttnDownBlock2D"),
        "up_block_types": ("CrossAttnUpBlock2D", "UpBlock2D"),
        "cross_attention_dim": 32,
    }
    return UNet2DConditionModel(**config)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test VTON Model Architecture modification")
    parser.add_argument("--test", action="store_true", help="Run model architecture verification")
    parser.add_argument("--use_real", action="store_true", help="Download and test pretrained Cat-VTON UNet")
    args = parser.parse_args()
    
    if args.test:
        print("Running Cat-VTON Model Wrapper verification...")
        
        if args.use_real:
            try:
                unet = load_catvton_unet()
            except Exception as e:
                print(f"Failed to download pretrained Cat-VTON UNet: {e}. Falling back to tiny UNet.")
                unet = get_tiny_unet_for_testing()
        else:
            print("Initializing tiny UNet for configuration check...")
            unet = get_tiny_unet_for_testing()
            
        # Freeze parameters
        unet = freeze_unet_for_vton(unet)
        
        # Verify forward pass with 9-channel horizontally concatenated input tensor
        # Height=64, Width=96 (concatenated 64x48 person and 64x48 garment)
        batch_size = 2
        latent_h, latent_w = 64, 96
        dummy_input = torch.randn(batch_size, 9, latent_h, latent_w)
        dummy_timestep = torch.tensor([1, 50])
        
        cross_attn_dim = unet.config.cross_attention_dim if hasattr(unet.config, "cross_attention_dim") else 768
        if cross_attn_dim is None:
            cross_attn_dim = 768
        dummy_encoder_hidden_states = torch.randn(batch_size, 77, cross_attn_dim)
        
        print("\nExecuting forward pass test on concatenated input...")
        with torch.no_grad():
            output = unet(
                sample=dummy_input,
                timestep=dummy_timestep,
                encoder_hidden_states=dummy_encoder_hidden_states
            ).sample
            
        print(f"Input shape:  {dummy_input.shape}")
        print(f"Output shape: {output.shape} (Expected: [B, 4, 64, 96])")
        
        # Split output to verify midpoint splitting
        person_output = output[:, :, :, :48]
        garment_output = output[:, :, :, 48:]
        print(f"Split Person output shape:  {person_output.shape} (Expected: [B, 4, 64, 48])")
        print(f"Split Garment output shape: {garment_output.shape} (Expected: [B, 4, 64, 48])")
        
        assert output.shape == (batch_size, 4, latent_h, latent_w), "Output shape mismatch!"
        assert unet.config.in_channels == 9, "UNet entry channel size is not 9!"
        
        print("\nCat-VTON model wrapper tests completed successfully!")
    else:
        print("Cat-VTON model wrapper script imported successfully.")
