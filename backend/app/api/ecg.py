from fastapi import APIRouter, HTTPException, Depends
from app.models.schemas import ECGAnalysisRequest
from app.services.ecg import ECGAnalyzer
from app.api.deps import get_ecg_analyzer, get_current_user, get_auth_service, AuthService
import base64

router = APIRouter()

@router.post("/analyze")
async def analyze_ecg(
    request: ECGAnalysisRequest,
    ecg_analyzer: ECGAnalyzer = Depends(get_ecg_analyzer),
    auth_service: AuthService = Depends(get_auth_service),
    current_user: str = Depends(get_current_user)
):
    """
    Analyzes a scanned paper ECG image.
    Processes digitization, clinical metrics, and AI findings.
    """
    # 1. Check Usage Limits
    allowed, message = auth_service.check_limits(current_user)
    if not allowed:
        raise HTTPException(status_code=403, detail=f"Quota Exceeded: {message}")

    try:
        # Decode image
        def decode_image(b64_str):
            if not b64_str: return None
            if "," in b64_str:
                _, encoded = b64_str.split(",", 1)
            else:
                encoded = b64_str
            return base64.b64decode(encoded)

        image_bytes = decode_image(request.image)
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Invalid image data")

        # 2. Perform Analysis
        result = ecg_analyzer.digitize_and_analyze(image_bytes)
        
        if "error" in result:
             raise HTTPException(status_code=500, detail=result["message"])

        # 3. Increment Run Count (Same as X-ray)
        auth_service.increment_runs(current_user)

        return result
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in ECG analyze endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
