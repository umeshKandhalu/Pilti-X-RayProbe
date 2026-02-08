import torchxrayvision as xrv
import torch
import numpy as np

# Load Autoencoder
print("Loading AE...")
ae = xrv.autoencoders.ResNetAE(weights="101-elastic")
ae.eval()

# 1. Zero Image (Black)
zeros = torch.zeros((1, 1, 224, 224))
# 2. Random Noise (Simulating non-structure)
# XRV normalizes roughly to -1024, 1024 range. 
# Random noise in that range.
rand = torch.rand((1, 1, 224, 224)) * 2000 - 1000

with torch.no_grad():
    out_z = ae(zeros)
    rec_z = out_z['out']
    mse_z = torch.mean((zeros - rec_z)**2).item()
    
    out_r = ae(rand)
    rec_r = out_r['out']
    mse_r = torch.mean((rand - rec_r)**2).item()

print(f"MSE Zeros: {mse_z}")
print(f"MSE Random Noise: {mse_r}")
