import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import transforms
from PIL import Image, ImageOps
import numpy as np
import io
import base64
import cv2
import torchxrayvision as xrv

class XRayAnalyzer:
    def __init__(self):
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        print(f"Loading Clinical Ensemble Models on {self.device}...")
        
        # --- Model 1: DenseNet121 (Primary - Used for GradCAM) ---
        print("Loading Model 1: DenseNet121 (High Resolution)...")
        self.model_densenet = xrv.models.DenseNet(weights="densenet121-res224-all")
        self.model_densenet.to(self.device)
        self.model_densenet.eval()
        
        # --- Model 2: ResNet50 (Secondary - Validation) ---
        print("Loading Model 2: ResNet50 (Extra Detail)...")
        self.model_resnet = xrv.models.ResNet(weights="resnet50-res512-all")
        self.model_resnet.to(self.device)
        self.model_resnet.eval()
        
        # --- OOD Detection (Autoencoder) ---
        print("Loading OOD Detector: ResNetAE-101...")
        self.ood_model = xrv.autoencoders.ResNetAE(weights="101-elastic")
        self.ood_model.to(self.device)
        self.ood_model.eval()

        # Shared Class Names (Verified Intersection)
        self.class_names = self.model_densenet.pathologies
        
        # --- Preprocessing Pipelines ---
        # DenseNet requires 224x224
        self.transform_densenet = transforms.Compose([
            xrv.datasets.XRayCenterCrop(),
            xrv.datasets.XRayResizer(224)
        ])
        
        # ResNet requires 512x512
        self.transform_resnet = transforms.Compose([
            xrv.datasets.XRayCenterCrop(),
            xrv.datasets.XRayResizer(512)
        ])

        # --- Grad-CAM Setup (Attached to DenseNet) ---
        self.gradients = None
        self.activations = None
        self._register_hooks()

    def _register_hooks(self):
        """Register hooks to capture activations and gradients for Grad-CAM on DenseNet."""
        target_layer = self.model_densenet.features.denseblock4.denselayer16.conv2
        
        def save_activations(module, input, output):
            self.activations = output.detach()
            
        def save_gradients(module, grad_input, grad_output):
            self.gradients = grad_output[0].detach()

        target_layer.register_forward_hook(save_activations)
        if hasattr(target_layer, 'register_full_backward_hook'):
            target_layer.register_full_backward_hook(save_gradients)
        else:
            target_layer.register_backward_hook(save_gradients)

    def preprocess_image(self, image_bytes, target_size=224):
        # Load image
        image = Image.open(io.BytesIO(image_bytes))
        
        # Handle EXIF Rotation (Critical for Mobile Uploads)
        image = ImageOps.exif_transpose(image)
        
        # Convert to Grayscale
        image = image.convert("L")
        img_np = np.array(image)
        
        # Normalize
        img_np = xrv.datasets.normalize(img_np, 255)
        
        # Add channel dimension
        img_np = img_np[None, :, :]
        
        # Transform based on target size
        if target_size == 224:
            img_tensor = self.transform_densenet(img_np)
        else:
            img_tensor = self.transform_resnet(img_np)
            
        img_tensor = torch.from_numpy(img_tensor).unsqueeze(0).to(self.device).float()
        
        if target_size == 224:
            img_tensor.requires_grad = True # For Grad-CAM
            
        return img_tensor, image

    def check_ood(self, image_tensor, threshold=10000):
        with torch.no_grad():
            out = self.ood_model(image_tensor)
            rec = out['out']
            mse = torch.mean((image_tensor - rec) ** 2).item()
            return mse, mse > threshold

    def predict(self, image_bytes):
        # --- 1. Prepare Inputs ---
        tensor_dense, original_image = self.preprocess_image(image_bytes, target_size=224)
        tensor_res, _ = self.preprocess_image(image_bytes, target_size=512)
        
        # --- 2. OOD Check ---
        ood_score, is_ood = self.check_ood(tensor_dense)
        if is_ood:
            print(f"OOD DETECTED! Score: {ood_score}")
            return {
                "error": "OOD_DETECTED",
                "message": f"Image does not appear to be a valid Chest X-Ray. (Reconstruction Error: {ood_score:.0f})",
                "ood_score": ood_score
            }

        # --- 3. Inference (Ensemble) ---
        # DenseNet Forward Pass
        out_dense = self.model_densenet(tensor_dense)
        probs_dense = torch.sigmoid(out_dense).squeeze().detach().cpu().numpy()
        
        # ResNet Forward Pass
        with torch.no_grad():
            out_res = self.model_resnet(tensor_res)
            probs_res = torch.sigmoid(out_res).squeeze().detach().cpu().numpy()
            
        # Ensemble Averaging
        avg_probs = (probs_dense + probs_res) / 2.0
        top_idx = np.argmax(avg_probs)
        
        # --- 3. Grad-CAM (Using DenseNet) ---
        self.model_densenet.zero_grad()
        # Backward pass on DenseNet output for the top ENSEMBLE class
        # We use the DenseNet output score for backprop, but guide it by the ensemble winner
        out_dense[:, top_idx].backward(retain_graph=True)
        
        heatmap_data = self._generate_heatmap(original_image)
        
        # --- 4. Prepare Results ---
        results = {}
        high_confidence = False
        
        for i, class_name in enumerate(self.class_names):
            p_d = float(probs_dense[i])
            p_r = float(probs_res[i])
            p_avg = float(avg_probs[i])
            
            # Formatting for UI: "Avg (Detailed Breakdown)"
            # But here we just send the average for simplicity in the main graph
            results[class_name] = p_avg
            
            # Check for high confidence agreement
            if i == top_idx and p_d > 0.6 and p_r > 0.6:
                high_confidence = True

        # Clinical Threshold
        MAX_NORMAL_THRESHOLD = 0.15
        top_prob = avg_probs[top_idx]
        
        if top_prob < MAX_NORMAL_THRESHOLD:
            top_finding_label = "No Findings"
            high_confidence = True # High confidence that it's normal
        else:
            top_finding_label = self.class_names[top_idx]

        return {
            "predictions": results,
            "heatmap": heatmap_data,
            "top_finding": top_finding_label,
            "is_high_confidence": high_confidence,
            "model_info": "Ensemble (DenseNet121 + ResNet50)"
        }

    def _generate_heatmap(self, original_image):
        if self.activations is None or self.gradients is None:
            return self._fallback_image(original_image)
            
        acts = self.activations
        grads = self.gradients
        
        weights = torch.mean(grads, dim=(2, 3), keepdim=True)
        heatmap = torch.sum(weights * acts, dim=1).squeeze()
        heatmap = F.relu(heatmap)
        
        max_val = torch.max(heatmap)
        if max_val > 0:
            heatmap = heatmap / max_val
            
        heatmap = heatmap.cpu().numpy()
        
        # --- Handle Center Crop Alignment ---
        # The model sees a Center Crop of min(H, W)
        orig_w, orig_h = original_image.size
        crop_size = min(orig_w, orig_h)
        
        start_x = (orig_w - crop_size) // 2
        start_y = (orig_h - crop_size) // 2
        
        # 1. Resize heatmap to the CROP size (not full original size yet)
        heatmap_crop = cv2.resize(heatmap, (crop_size, crop_size))
        
        # 2. Embed into full size canvas (pad with zeros)
        heatmap_full = np.zeros((orig_h, orig_w), dtype=np.float32)
        heatmap_full[start_y:start_y+crop_size, start_x:start_x+crop_size] = heatmap_crop
        
        # 3. Colorize (using the full aligned heatmap)
        heatmap_full = np.uint8(255 * heatmap_full)
        heatmap_color = cv2.applyColorMap(heatmap_full, cv2.COLORMAP_JET)
        
        # 4. Zero out the padding areas strictly (optional, but cleaner)
        # The heatmap logic above naturally puts 0s there, so low heat (blue in JET).
        # Typically we want "no heat" to be transparent or just background.
        # But for overlay, blue is "low prob". 
        # If we want it to look "empty", we might need alpha blending. 
        # For now, let's simple-add first. 
        # Actually JET 0 is Blue. So padding will be Blue. 
        # Ideally padding should be ignored. 
        
        # Advanced Overlay: Only overlay where we have the crop? 
        # Or better: resizing 0 to crop_size, then padding. 0 maps to Blue. 
        # Let's simple-add first. 
        
        # Overlay
        open_cv_image = np.array(original_image.convert("RGB"))
        # Convert RGB to BGR for OpenCV
        open_cv_image = cv2.cvtColor(open_cv_image, cv2.COLOR_RGB2BGR)
        
        overlay = cv2.addWeighted(open_cv_image, 0.6, heatmap_color, 0.4, 0)
        overlay_rgb = cv2.cvtColor(overlay, cv2.COLOR_BGR2RGB)
        
        # To Base64
        im_pil = Image.fromarray(overlay_rgb)
        buffered = io.BytesIO()
        im_pil.save(buffered, format="JPEG")
        return base64.b64encode(buffered.getvalue()).decode("utf-8")

    def _fallback_image(self, original_image):
        open_cv_image = np.array(original_image.convert("RGB"))
        im_pil = Image.fromarray(open_cv_image)
        buffered = io.BytesIO()
        im_pil.save(buffered, format="JPEG")
        return base64.b64encode(buffered.getvalue()).decode("utf-8")
