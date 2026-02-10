from app.services.inference import XRayAnalyzer
from app.services.report import ReportGenerator
from app.services.auth import AuthService
from app.services.storage import MinioStorage

# Initialize Singletons
try:
    analyzer = XRayAnalyzer()
except Exception as e:
    print(f"Warning: Failed to load XRayAnalyzer: {e}")
    analyzer = None

report_gen = ReportGenerator()
storage = MinioStorage()
auth_service = AuthService()

def get_auth_service():
    return auth_service

def get_analyzer():
    if not analyzer:
        raise Exception("Model not loaded")
    return analyzer

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
