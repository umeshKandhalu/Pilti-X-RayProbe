from app.services.inference import XRayAnalyzer
from app.services.ecg import ECGAnalyzer
from app.services.report import ReportGenerator
from app.services.auth import AuthService
from app.services.storage import MinioStorage

# Initialize Singletons with Safety Wrappers
def init_service(service_class, name):
    try:
        print(f"[INIT] Initializing {name}...")
        return service_class()
    except Exception as e:
        print(f"[ERROR] Failed to initialize {name}: {e}")
        import traceback
        traceback.print_exc()
        return None

analyzer = init_service(XRayAnalyzer, "XRayAnalyzer")
ecg_analyzer = init_service(ECGAnalyzer, "ECGAnalyzer")
report_gen = init_service(ReportGenerator, "ReportGenerator")
storage = init_service(MinioStorage, "MinioStorage")
auth_service = init_service(AuthService, "AuthService")

def get_ecg_analyzer():
    if not ecg_analyzer:
        raise HTTPException(status_code=503, detail="ECG Analysis Engine not available")
    return ecg_analyzer

def get_analyzer():
    if not analyzer:
        raise HTTPException(status_code=503, detail="X-Ray Analysis Engine not available")
    return analyzer

def get_report_generator():
    if not report_gen:
        raise HTTPException(status_code=503, detail="Report Generation Engine not available")
    return report_gen

def get_storage():
    if not storage:
        raise HTTPException(status_code=503, detail="Storage Service not available")
    return storage

def get_auth_service():
    if not auth_service:
        # Crucial for login, if this fails we have a major issue
        raise HTTPException(status_code=503, detail="Authentication Service not available")
    return auth_service

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
