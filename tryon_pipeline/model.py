import argparse
import torch
import torch.nn as nn
from diffusers import UNet2DConditionModel

def patch_unet_for_vton(unet: UNet2DConditionModel, target_channels: int = 13) -> UNet2DConditionModel:
    """
    Modifies the input convolution layer of the UNet to accept multi-channel spatial concatenation.
    Freezes all parameters except the self-attention blocks and the new input layer.
    """
    # 1. Modify the entry convolution layer (conv_in)
    old_conv = unet.conv_in
    old_in_channels = old_conv.in_channels
    out_channels = old_conv.out_channels
    
    if old_in_channels == target_channels:
        print("UNet conv_in is already configured for 13 channels.")
    else:
        print(f"Modifying UNet conv_in: {old_in_channels} channels -> {target_channels} channels")
        
        # Create a new conv layer
        new_conv = nn.Conv2d(
            in_channels=target_channels,
            out_channels=out_channels,
            kernel_size=old_conv.kernel_size,
            stride=old_conv.stride,
            padding=old_conv.padding,
            bias=old_conv.bias is not None
        )
        
        # Initialize new weights
        # We copy the original weights for the existing channels, and fill the new channels with zeros
        with torch.no_grad():
            # Copy original weights
            new_conv.weight[:, :old_in_channels, :, :] = old_conv.weight
            # Zero-initialize the remaining channels (e.g. the garment latents)
            new_conv.weight[:, old_in_channels:, :, :] = 0.0
            if old_conv.bias is not None:
                new_conv.bias.copy_(old_conv.bias)
                
        unet.conv_in = new_conv
        # Update config so that saving/loading works correctly
        unet.config.in_channels = target_channels
        
    # 2. Freeze parameters & selectively unfreeze self-attention blocks and conv_in
    # Set all parameters to not require grad
    for param in unet.parameters():
        param.requires_grad = False
        
    # Unfreeze conv_in (since we modified its input shape)
    for param in unet.conv_in.parameters():
        param.requires_grad = True
        
    # Unfreeze self-attention blocks (attn1 in Transformer2DModel blocks)
    unfrozen_params = 0
    total_params = 0
    
    for name, module in unet.named_modules():
        # Check if the module is a self-attention module
        # In diffusers UNet2DConditionModel, self-attention blocks are typically named 'attn1'
        if "attn1" in name:
            for param in module.parameters():
                param.requires_grad = True
                
    # Calculate parameter budget
    for param in unet.parameters():
        total_params += param.numel()
        if param.requires_grad:
            unfrozen_params += param.numel()
            
    print(f"UNet Total Parameters:    {total_params:,}")
    print(f"UNet Trainable Parameters: {unfrozen_params:,} ({unfrozen_params / total_params * 100:.2f}%)")
    
    return unet

def get_tiny_unet_for_testing() -> UNet2DConditionModel:
    """
    Creates a tiny UNet model configurations for fast testing without downloading weights.
    """
    # Create configuration for a tiny UNet
    config = {
        "sample_size": 64,
        "in_channels": 9, # standard inpainting in channels
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
    parser.add_argument("--use_real", action="store_true", help="Download and test standard runwayml inpainting UNet")
    args = parser.parse_args()
    
    if args.test:
        print("Running VTON Model Wrapper verification...")
        
        # Determine whether to use a real model or a tiny test model
        if args.use_real:
            print("Loading pretrained runwayml/stable-diffusion-inpainting UNet...")
            try:
                unet = UNet2DConditionModel.from_pretrained(
                    "runwayml/stable-diffusion-inpainting",
                    subfolder="unet"
                )
            except Exception as e:
                print(f"Failed to download pretrained model: {e}. Falling back to tiny UNet.")
                unet = get_tiny_unet_for_testing()
        else:
            print("Initializing tiny UNet for configuration check...")
            unet = get_tiny_unet_for_testing()
            
        # Patch the UNet
        patched_unet = patch_unet_for_vton(unet)
        
        # Verify forward pass with 13-channel input tensor
        # Latent dimensions at 512x384 resolution are 64x48
        batch_size = 2
        latent_h, latent_w = 64, 48
        dummy_input = torch.randn(batch_size, 13, latent_h, latent_w)
        dummy_timestep = torch.tensor([1, 50])
        # Text encoder output representation for conditioning (usually shape [batch_size, seq_len, cross_attn_dim])
        cross_attn_dim = patched_unet.config.cross_attention_dim if hasattr(patched_unet.config, "cross_attention_dim") else 768
        if cross_attn_dim is None:
            cross_attn_dim = 768
        dummy_encoder_hidden_states = torch.randn(batch_size, 77, cross_attn_dim)
        
        print("\nExecuting forward pass test...")
        with torch.no_grad():
            output = patched_unet(
                sample=dummy_input,
                timestep=dummy_timestep,
                encoder_hidden_states=dummy_encoder_hidden_states
            ).sample
            
        print(f"Input shape:  {dummy_input.shape}")
        print(f"Output shape: {output.shape} (Expected: [B, 4, 64, 48])")
        
        # Verify that only the allowed parameters are trainable
        trainable_names = [name for name, param in patched_unet.named_parameters() if param.requires_grad]
        print(f"\nNumber of trainable parameters: {len(trainable_names)}")
        print("Sample of trainable parameter names:")
        for name in trainable_names[:5]:
            print(f"  - {name}")
            
        assert output.shape == (batch_size, 4, latent_h, latent_w), "Output shape mismatch!"
        assert patched_unet.conv_in.in_channels == 13, "UNet entry channel size is not 13!"
        
        print("\nModel wrapper tests completed successfully!")
    else:
        print("Model wrapper script imported successfully.")
