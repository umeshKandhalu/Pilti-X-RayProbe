import torchxrayvision as xrv
from transformers import AutoModel, AutoImageProcessor
import torch
import os

# Set cache directories to a permanent location in the image
os.environ['XDG_CACHE_HOME'] = '/app/.cache'
os.environ['TRANSFORMERS_CACHE'] = '/app/.cache/huggingface'
os.environ['TORCH_HOME'] = '/app/.cache/torch'
os.environ['HF_HOME'] = '/app/.cache/huggingface'
# Force torchxrayvision to use a specific directory if possible
# (It usually follows XDG_CACHE_HOME or TORCH_HOME)

print("--- Pre-downloading SOTA Radiology Models ---")

# 1. TorchXRayVision Models
print("Downloading DenseNet121...")
xrv.models.DenseNet(weights="densenet121-res224-all")

print("Downloading ResNet50...")
xrv.models.ResNet(weights="resnet50-res512-all")

print("Downloading OOD Detector...")
xrv.autoencoders.ResNetAE(weights="101-elastic")

# 2. HuggingFace Models
print("Downloading RAD-DINO (HuggingFace)...")
AutoImageProcessor.from_pretrained("microsoft/rad-dino")
AutoModel.from_pretrained("microsoft/rad-dino")

print("--- Pre-downloading ECG Foundations ---")
print("Downloading HuBERT-ECG (HuggingFace)...")
AutoModel.from_pretrained("Edoardo-BS/hubert-ecg-base", trust_remote_code=True)

print("--- Model Pre-download Complete! ---")
