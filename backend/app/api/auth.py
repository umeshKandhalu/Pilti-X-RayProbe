from fastapi import APIRouter, HTTPException, Depends
from app.models.schemas import LoginRequest
from app.services.auth import AuthService
from app.api.deps import get_auth_service
from app.core.security import create_access_token

router = APIRouter()

@router.post("/register")
async def register(request: LoginRequest, auth_service: AuthService = Depends(get_auth_service)):
    success, message = auth_service.create_user(request.email, request.password, request.dob)
    if not success:
        raise HTTPException(status_code=400, detail=message)
    return {"message": message}

@router.post("/login")
async def login(request: LoginRequest, auth_service: AuthService = Depends(get_auth_service)):
    success, message = auth_service.authenticate_user(request.email, request.password, request.dob)
    if not success:
        raise HTTPException(status_code=401, detail=message)
    
    # Create Access Token
    access_token = create_access_token(data={"sub": request.email})
    
    # Fetch usage and role
    usage = auth_service.get_usage(request.email)
    
    return {
        "access_token": access_token, 
        "token_type": "bearer",
        "email": request.email,
        "role": usage.get('role', 'user'),
        "limits": {
            "max_storage_bytes": usage.get('max_storage_bytes'),
            "max_runs_count": usage.get('max_runs_count')
        }
    }

from app.api.deps import get_current_user

@router.get("/usage_stats")
async def get_stats(
    current_user: str = Depends(get_current_user),
    auth_service: AuthService = Depends(get_auth_service)
):
    """Returns storage and run usage for the logged-in user."""
    return auth_service.get_usage(current_user)
