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
    heatmap_image: Optional[str] = None # Base64 encoded for X-ray
    pinpoint_image: Optional[str] = None # Base64 encoded for X-ray focal crop
    waveform_image: Optional[str] = None # Base64 encoded for ECG
    doctor_marked_images: Optional[List[str]] = [] # List of Base64 encoded images
    model_info: Optional[str] = "Standard Model"
    is_ecg: Optional[bool] = False

class ECGAnalysisRequest(BaseModel):
    image: str # Base64 encoded

class UserLimitUpdate(BaseModel):
    max_storage_bytes: Optional[int] = None
    max_runs_count: Optional[int] = None

class UserInfo(BaseModel):
    email: str
    role: str
    created_at: str
    storage_used_bytes: int
    max_storage_bytes: int
    runs_used_count: int
    max_runs_count: int

class UserListResponse(BaseModel):
    users: List[UserInfo]
