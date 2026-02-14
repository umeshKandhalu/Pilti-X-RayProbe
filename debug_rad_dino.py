from transformers import AutoModel, AutoImageProcessor
import torch
import numpy as np
from PIL import Image
import cv2
import io

def debug_heatmap():
    device = "cpu"
    print("Loading RAD-DINO...")
    processor = AutoImageProcessor.from_pretrained("microsoft/rad-dino")
    model = AutoModel.from_pretrained("microsoft/rad-dino", output_attentions=True)
    model.to(device).eval()

    # Generic chest x-ray like dummy
    img = Image.new('RGB', (224, 224), color = (100, 100, 100))
    inputs = processor(images=img, return_tensors="pt").to(device)

    with torch.no_grad():
        outputs = model(**inputs)
        attentions = outputs.attentions

    print(f"Number of layers: {len(attentions)}")
    print(f"Shape of last layer attention: {attentions[-1].shape}")

    last_layer_attn = attentions[-1].squeeze(0)
    avg_attn = torch.mean(last_layer_attn, dim=0)
    print(f"Avg attn shape: {avg_attn.shape}")
    
    cls_attn = avg_attn[0, 1:]
    print(f"CLS attn min: {cls_attn.min().item()}, max: {cls_attn.max().item()}")

if __name__ == "__main__":
    debug_heatmap()
