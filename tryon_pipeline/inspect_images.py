import os
from PIL import Image

brain_dir = r"C:\Users\NC24008_Rahul\.gemini\antigravity\brain\ea96354e-8a37-4063-85ea-701de3090b0b"
img1_path = os.path.join(brain_dir, "media__1779479417506.png")
img2_path = os.path.join(brain_dir, "media__1779479417522.png")

for i, img_path in enumerate([img1_path, img2_path], 1):
    if os.path.exists(img_path):
        img = Image.open(img_path)
        print(f"Image {i} ({os.path.basename(img_path)}): Format={img.format}, Size={img.size}, Mode={img.mode}")
    else:
        print(f"Image {i} does not exist at path: {img_path}")
