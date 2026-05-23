import os
import sys

# Change working directory to the pipeline directory
os.chdir(r"C:\Users\NC24008_Rahul\.gemini\antigravity\scratch\b2b_gena2z\tryon_pipeline")
sys.path.append(r"C:\Users\NC24008_Rahul\.gemini\antigravity\scratch\b2b_gena2z\tryon_pipeline")

import torch
from PIL import Image
import numpy as np

# Define paths
brain_dir = r"C:\Users\NC24008_Rahul\.gemini\antigravity\brain\ea96354e-8a37-4063-85ea-701de3090b0b"
garment_path = os.path.join(brain_dir, "media__1779479417506.png")
person_path = os.path.join(brain_dir, "media__1779479417522.png")

print(f"Garment path exists: {os.path.exists(garment_path)}")
print(f"Person path exists: {os.path.exists(person_path)}")

# Run inference in mock mode first to see if preprocessing works
cmd = f".venv\\Scripts\\python.exe inference.py --person_path \"{person_path}\" --garment_path \"{garment_path}\" --category upper_body --mock --output_path test_tryon_mock_result.png"
print(f"Running command: {cmd}")
os.system(cmd)

print("Mock run complete. Checking if output file exists...")
output_path = "test_tryon_mock_result.png"
if os.path.exists(output_path):
    print(f"Mock output generated successfully! Size={Image.open(output_path).size}")
else:
    print("Mock output generation failed.")
