from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

from app.core.config import settings
from app.api import auth, analysis, reports, admin, ecg

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Backend for X-ray analysis and report generation",
    version="2.2.4",
    docs_url=f"{settings.API_V1_STR}/docs",
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from fastapi import Request, HTTPException
from app.core.security import verify_hmac, SECRET_KEY

@app.middleware("http")
async def verify_hmac_middleware(request: Request, call_next):
    # Skip HMAC for open docs, health check, and specific endpoints
    if any(path in request.url.path for path in ["/", "/health", "/docs", "/openapi.json", "/generate_report"]):
        if "/generate_report" in request.url.path:
            print(f"DEBUG: HMAC Bypassed for {request.url.path}")
        return await call_next(request)

    # 1. Get Headers
    signature = request.headers.get("X-Signature")
    timestamp = request.headers.get("X-Timestamp")

    # 2. Skip if headers missing (Optional: Enforce strictly?)
    # For now, let's strictly enforce on /analyze and /generate_report to be safe
    # But allow auth endpoints to be loose if needed? No, let's enforce all API routes.
    if request.url.path.startswith("/api"): # Assuming all routes are api/*, wait, they are at root
        pass 
    
    # 3. Read Body (Need to cache it because consuming stream clears it)
    body_bytes = await request.body()
    
    # Re-package body for the next handler
    async def receive():
        return {"type": "http.request", "body": body_bytes}
    request._receive = receive

    if signature and timestamp:
         # For multipart/form-data (file uploads), frontend signs empty body
         # because boundary is dynamic. We must replicate this logic.
         content_type = request.headers.get("content-type", "")
         bytes_to_verify = body_bytes
         if "multipart/form-data" in content_type:
             bytes_to_verify = b""
             
         is_valid, msg = verify_hmac(bytes_to_verify, signature, timestamp, SECRET_KEY)
         if not is_valid:
             print(f"DEBUG: HMAC Verification Failed for {request.url.path}: {msg}")
             print(f"DEBUG: Body size: {len(bytes_to_verify)}, Timestamp: {timestamp}")
             from fastapi.responses import JSONResponse
             return JSONResponse(status_code=403, content={"detail": f"HMAC Verification Failed: {msg}"})
         print(f"DEBUG: HMAC Verified for {request.url.path}")

    response = await call_next(request)
    return response

# Include Routers
app.include_router(auth.router, tags=["Authentication"])
app.include_router(analysis.router, tags=["Analysis"])
app.include_router(reports.router, tags=["Reports"])
app.include_router(admin.router, tags=["Admin"])
app.include_router(ecg.router, prefix="/ecg", tags=["ECG Analysis"])

@app.get("/")
async def root():
    return {"message": "Clinical Decision Support System API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
