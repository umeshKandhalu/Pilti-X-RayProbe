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
    
    return {
        "access_token": access_token, 
        "token_type": "bearer",
        "email": request.email
    }
