from fastapi import APIRouter, HTTPException, Depends
from typing import List
from app.api.deps import get_auth_service, get_admin_user
from app.services.auth import AuthService
from app.models.schemas import UserListResponse, UserLimitUpdate, UserInfo

router = APIRouter(prefix="/admin", tags=["Admin"])

@router.get("/users", response_model=UserListResponse)
async def list_users(
    admin_user: str = Depends(get_admin_user),
    auth_service: AuthService = Depends(get_auth_service)
):
    """Returns a list of all users and their current usage/limits."""
    users = auth_service.list_all_users()
    return {"users": users}

@router.patch("/users/{email}/limits")
async def update_user_limits(
    email: str,
    updates: UserLimitUpdate,
    admin_user: str = Depends(get_admin_user),
    auth_service: AuthService = Depends(get_auth_service)
):
    """Updates the max storage or run limits for a specific user."""
    # Prevent admins from updating their OWN limits? (Optional safeguard)
    # if email == admin_user:
    #    raise HTTPException(status_code=400, detail="Admins cannot update their own limits via this API")

    success, message = auth_service.update_user_limits(
        email, 
        max_storage=updates.max_storage_bytes,
        max_runs=updates.max_runs_count
    )
    
    if not success:
        raise HTTPException(status_code=400, detail=message)
        
    return {"message": message}
