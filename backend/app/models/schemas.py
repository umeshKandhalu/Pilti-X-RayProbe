from pydantic import BaseModel
from typing import Optional, List, Dict

class LoginRequest(BaseModel):
    email: str
    password: str
    dob: Optional[str] = None

class ReportRequest(BaseModel):
    patient_id: str
    patient_name: str
    dob: str
    email: str
    original_image: str # Base64 encoded
    findings: dict
    heatmap_image: Optional[str] = None # Base64 encoded
    model_info: Optional[str] = "Standard Model"
