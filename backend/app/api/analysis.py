from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from fastapi.responses import JSONResponse
from app.api.deps import get_analyzer, get_current_user

router = APIRouter()

@router.post("/analyze")
async def analyze_xray(file: UploadFile = File(...), current_user: str = Depends(get_current_user)):
# I need to import get_current_user
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")
    
    try:
        analyzer = get_analyzer()
        if not analyzer:
             raise HTTPException(status_code=503, detail="Model not loaded")

        contents = await file.read()
        result = analyzer.predict(contents)
        
        return JSONResponse(content=result)
    except Exception as e:
        print(f"Error during analysis: {e}")
        raise HTTPException(status_code=500, detail=str(e))
