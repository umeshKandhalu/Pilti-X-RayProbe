from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from fastapi.responses import JSONResponse
from app.api.deps import get_analyzer, get_current_user, AuthService, get_auth_service

router = APIRouter()

@router.post("/analyze")
async def analyze_xray(
    file: UploadFile = File(...),
    current_user: str = Depends(get_current_user),
    auth_service: AuthService = Depends(get_auth_service)
):
    # 1. Check Usage Limits (Runs & Storage)
    allowed, message = auth_service.check_limits(current_user)
    if not allowed:
        raise HTTPException(status_code=403, detail=f"Quota Exceeded: {message}")

    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")
    
    try:
        analyzer = get_analyzer()
        if not analyzer:
             raise HTTPException(status_code=503, detail="Model not loaded")

        contents = await file.read()
        result = analyzer.predict(contents)
        
        # Increment Usage Counter
        auth_service.increment_runs(current_user)
        
        return JSONResponse(content=result)
    except Exception as e:
        print(f"Error during analysis: {e}")
        raise HTTPException(status_code=500, detail=str(e))
