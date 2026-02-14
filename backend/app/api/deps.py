from app.services.inference import XRayAnalyzer
from app.services.ecg import ECGAnalyzer
from app.services.report import ReportGenerator
from app.services.auth import AuthService
from app.services.storage import MinioStorage

# Initialize Singletons
try:
    analyzer = XRayAnalyzer()
except Exception as e:
    print(f"Warning: Failed to load XRayAnalyzer: {e}")
    analyzer = None

ecg_analyzer = ECGAnalyzer()

report_gen = ReportGenerator()
storage = MinioStorage()
auth_service = AuthService()

def get_auth_service():
    return auth_service

def get_analyzer():
    if not analyzer:
        raise Exception("Model not loaded")
    return analyzer

def get_ecg_analyzer():
    return ecg_analyzer

def get_report_generator():
    return report_gen


def get_storage():
    return storage

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from app.core.security import verify_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/v1/login")

def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    return verify_token(token, credentials_exception)

def get_admin_user(
    current_user: str = Depends(get_current_user),
    auth_service: AuthService = Depends(get_auth_service)
):
    user = auth_service.get_user(current_user)
    if not user or user.get('role') != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="The user does not have enough privileges"
        )
    return current_user
