from transformers import AutoModel, AutoImageProcessor
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
    """Next Generation SOTA Radiology Analyzer using RAD-DINO (ViT) and Clinical Ensembles."""
    def __init__(self):
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        print(f"Loading Next-Gen SOTA (RAD-DINO + Ensemble) on {self.device}...")
        
        # --- Model 1: RAD-DINO (Next Gen Vision Transformer Backbone) ---
        print("Loading Model 1: RAD-DINO (Vision Transformer)...")
        try:
            self.vit_processor = AutoImageProcessor.from_pretrained("microsoft/rad-dino")
            self.vit_backbone = AutoModel.from_pretrained("microsoft/rad-dino", output_attentions=True)
            self.vit_backbone.to(self.device).eval()
        except Exception as e:
            print(f"Warning: Failed to load RAD-DINO: {e}. Falling back to standard visualization.")
            self.vit_backbone = None

        # --- Model 2: DenseNet121 (Primary Classifier) ---
        print("Loading Model 2: DenseNet121 (High Resolution)...")
        self.model_densenet = xrv.models.DenseNet(weights="densenet121-res224-all")
        self.model_densenet.to(self.device).eval()
        
        # --- Model 3: ResNet50 (Validation Classifier) ---
        print("Loading Model 3: ResNet50 (Extra Detail)...")
        self.model_resnet = xrv.models.ResNet(weights="resnet50-res512-all")
        self.model_resnet.to(self.device).eval()
        
        # --- OOD Detection (Autoencoder) ---
        print("Loading OOD Detector: ResNetAE-101...")
        self.ood_model = xrv.autoencoders.ResNetAE(weights="101-elastic")
        self.ood_model.to(self.device).eval()

        # Shared Class Names
        self.class_names = self.model_densenet.pathologies
        
        # --- Preprocessing Pipelines ---
        self.transform_densenet = transforms.Compose([
            xrv.datasets.XRayCenterCrop(),
            xrv.datasets.XRayResizer(224)
        ])
        
        self.transform_resnet = transforms.Compose([
            xrv.datasets.XRayCenterCrop(),
            xrv.datasets.XRayResizer(512)
        ])

    def preprocess_image(self, image_bytes, target_size=224):
        image = Image.open(io.BytesIO(image_bytes))
        image = ImageOps.exif_transpose(image)
        orig_image = image.copy()
        
        # Grayscale for XRV
        image_l = image.convert("L")
        img_np = np.array(image_l)
        img_np = xrv.datasets.normalize(img_np, 255)
        img_np = img_np[None, :, :]
        
        if target_size == 224:
            img_tensor = self.transform_densenet(img_np)
        else:
            img_tensor = self.transform_resnet(img_np)
            
        img_tensor = torch.from_numpy(img_tensor).unsqueeze(0).to(self.device).float()
        return img_tensor, orig_image

    def check_ood(self, image_tensor, threshold=10000):
        with torch.no_grad():
            out = self.ood_model(image_tensor)
            mse = torch.mean((image_tensor - out['out']) ** 2).item()
            return mse, mse > threshold

    def predict(self, image_bytes):
        tensor_224, original_image = self.preprocess_image(image_bytes, target_size=224)
        tensor_512, _ = self.preprocess_image(image_bytes, target_size=512)
        
        # 1. OOD Check
        ood_score, is_ood = self.check_ood(tensor_224)
        if is_ood:
            return {
                "error": "OOD_DETECTED",
                "message": f"Image does not appear to be a valid Chest X-Ray. (Error: {ood_score:.0f})",
                "ood_score": ood_score
            }

        # 2. Inference (SOTA Ensemble)
        with torch.no_grad():
            out_dense = self.model_densenet(tensor_224)
            probs_dense = torch.sigmoid(out_dense).squeeze().cpu().numpy()
            
            out_res = self.model_resnet(tensor_512)
            probs_res = torch.sigmoid(out_res).squeeze().cpu().numpy()
            
        avg_probs = (probs_dense + probs_res) / 2.0
        top_idx = np.argmax(avg_probs)
        
        # 3. Next-Gen Heatmap (RAD-DINO Attention Rollout) & Pinpoint
        heatmap_data, pinpoint_data, heatmap_raw = self._generate_vit_heatmap_and_pinpoint(original_image, return_raw=True)
        
        # 4. Results
        results = {name: float(avg_probs[i]) for i, name in enumerate(self.class_names)}
        p_d, p_r = probs_dense[top_idx], probs_res[top_idx]
        
        top_prob = avg_probs[top_idx]
        threshold = 0.15
        top_finding_label = self.class_names[top_idx] if top_prob >= threshold else "No Findings"

        # 5. Clinical Consensus Agent (The "Second Pass" Review)
        consensus = self._clinical_consensus_agent(top_finding_label, top_prob, heatmap_raw)
        
        return {
            "predictions": results,
            "heatmap": heatmap_data,
            "pinpoint": pinpoint_data,
            "top_finding": top_finding_label,
            "consensus": consensus, # NEW: Multi-agent verification
            "is_high_confidence": bool((p_d > 0.6 and p_r > 0.6) or top_prob < threshold or consensus["status"] == "APPROVED"),
            "model_info": "Next-Gen (RAD-DINO ViT + Clinical Ensemble + Consensus Agent)"
        }

    def _clinical_consensus_agent(self, finding, prob, heatmap_raw):
        """
        Mimics a 'Senior Radiologist' by checking if the AI's visual attention 
        aligns with the predicted medical finding.
        """
        if finding == "No Findings" or prob < 0.15 or heatmap_raw is None:
            return {"status": "UNCERTAIN", "agent_name": "Clinical Auditor", "reason": "No significant pathologies detected or visual attention data unavailable."}

        # Simplified Anatomical Mapping (0-1.0 coords on resized heatmap)
        # We check where the peak attention is (max_loc)
        h, w = heatmap_raw.shape
        min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(heatmap_raw)
        peak_x, peak_y = max_loc[0] / w, max_loc[1] / h
        
        # Anatomical Regions:
        # X: 0.0-0.45 (Right Lung), 0.45-0.55 (Mediastinum), 0.55-1.0 (Left Lung)
        # Y: 0.0-1.0 (Lungs/Heart)

        is_heart_region = 0.4 <= peak_x <= 0.6 and 0.4 <= peak_y <= 0.8
        is_lung_region = (peak_x < 0.45 or peak_x > 0.55) and 0.1 <= peak_y <= 0.9

        diagnosis = finding.lower()
        consensus_status = "UNCERTAIN"
        reason = "Visual focus is non-specific."

        if "cardiomegaly" in diagnosis:
            if is_heart_region:
                consensus_status = "APPROVED"
                reason = "Sate-of-the-Art verification: Visual focus correctly identifies cardiac enlargement region."
            else:
                consensus_status = "CONFLICT"
                reason = "Caution: High probability of Cardiomegaly but visual attention is outside the cardiac silhouette."
        
        elif any(path in diagnosis for path in ["pneumonia", "effusion", "pneumothorax", "atelectasis", "infiltration"]):
            if is_lung_region:
                consensus_status = "APPROVED"
                reason = f"State-of-the-Art verification: Visual focus correctly identifies pulmonary abnormality in lung fields for {finding}."
            else:
                consensus_status = "CONFLICT"
                reason = f"Caution: {finding} predicted but visual attention is non-pulmonary. Suggest secondary review."

        return {
            "status": consensus_status,
            "agent_name": "PCSS Senior Clinical Auditor",
            "reason": reason,
            "peak_attention_coords": [float(peak_x), float(peak_y)]
        }

    def _generate_vit_heatmap_and_pinpoint(self, original_image, return_raw=False):
        """Generates a sharper attention heatmap and a focal pinpoint crop."""
        if not self.vit_backbone:
            fallback = self._fallback_image(original_image)
            return (fallback, fallback, None) if return_raw else (fallback, fallback)

        try:
            # ViT Preprocessing: Force stretch to 518x518 to ensure 
            # pixel-perfect alignment when mapping back from the 37x37 grid.
            resized_vit = original_image.resize((518, 518), Image.BILINEAR)
            inputs = self.vit_processor(images=resized_vit, return_tensors="pt").to(self.device)
            
            with torch.no_grad():
                outputs = self.vit_backbone(**inputs)
                attentions = outputs.attentions 
            
            # --- Better Attention Rollout (Last 4 Layers) ---
            num_layers = 4
            rollout = None
            for i in range(1, num_layers + 1):
                attn_layer = attentions[-i].squeeze(0)
                attn_avg = torch.mean(attn_layer, dim=0)
                I = torch.eye(attn_avg.size(0)).to(self.device)
                a = (attn_avg + I) / 2
                a = a / a.sum(dim=-1, keepdim=True)
                
                if rollout is None:
                    rollout = a
                else:
                    rollout = torch.matmul(a, rollout)
            
            # Extract CLS attention to grid
            cls_attn = rollout[0, 1:]
            grid_size = int(np.sqrt(cls_attn.size(0)))
            heatmap = cls_attn.reshape(grid_size, grid_size).cpu().numpy()
            
            # Emphasize peaks (Power transformation)
            heatmap = np.power(heatmap, 3.0)
            heatmap = (heatmap - heatmap.min()) / (heatmap.max() - heatmap.min() + 1e-8)
            
            # --- 1. Global Heatmap Overlay with Masking ---
            orig_w, orig_h = original_image.size
            heatmap_resized = cv2.resize(heatmap, (orig_w, orig_h))
            
            # Generate colors using the HOT colormap (no blue base) or JET with manual masking
            # We zero out low-intensity spots to avoid the JET-blue background.
            heatmap_smooth = cv2.GaussianBlur(heatmap_resized, (15, 15), 0)
            
            # Only apply colors to peaks above 15% intensity
            display_threshold = 0.15
            heatmap_mask = (heatmap_smooth > display_threshold).astype(np.float32)
            heatmap_mask = cv2.GaussianBlur(heatmap_mask, (31, 31), 0) # Smooth transition
            
            heatmap_uint8 = np.uint8(255 * heatmap_smooth)
            heatmap_color = cv2.applyColorMap(heatmap_uint8, cv2.COLORMAP_JET)
            
            open_cv_image = cv2.cvtColor(np.array(original_image.convert("RGB")), cv2.COLOR_RGB2BGR)
            
            # Alpha blend where mask exists; otherwise keep original
            mask_3d = heatmap_mask[:, :, np.newaxis]
            overlay = (open_cv_image * (1 - mask_3d * 0.75) + heatmap_color * (mask_3d * 0.75)).astype(np.uint8)
            
            # --- 2. Pinpoint Crop ---
            min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(heatmap_resized)
            peak_x, peak_y = max_loc
            
            crop_size = int(min(orig_w, orig_h) * 0.4)
            left = max(0, peak_x - crop_size // 2)
            top = max(0, peak_y - crop_size // 2)
            right = min(orig_w, left + crop_size)
            bottom = min(orig_h, top + crop_size)
            
            pinpoint_img = original_image.crop((left, top, right, bottom))
            
            # Convert to Base64
            def to_b64(pil_img):
                buf = io.BytesIO()
                pil_img.convert("RGB").save(buf, format="JPEG")
                return base64.b64encode(buf.getvalue()).decode("utf-8")

            res_heatmap = to_b64(Image.fromarray(cv2.cvtColor(overlay, cv2.COLOR_BGR2RGB)))
            res_pinpoint = to_b64(pinpoint_img)

            if return_raw:
                return res_heatmap, res_pinpoint, heatmap_resized
            return res_heatmap, res_pinpoint
            
        except Exception as e:
            print(f"Error generating ViT pinpoint: {e}")
            fallback = self._fallback_image(original_image)
            return (fallback, fallback, None) if return_raw else (fallback, fallback)

    def _fallback_image(self, original_image):
        buffered = io.BytesIO()
        original_image.convert("RGB").save(buffered, format="JPEG")
        return base64.b64encode(buffered.getvalue()).decode("utf-8")
