from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api import auth, analysis, reports

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Backend for X-ray analysis and report generation",
    version="0.1.0",
    docs_url=f"{settings.API_V1_STR}/docs",
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def log_requests(request, call_next):
    print(f"DEBUG REQUEST: {request.method} {request.url} from {request.client.host}")
    response = await call_next(request)
    return response

# Include Routers
app.include_router(auth.router, tags=["Authentication"])
app.include_router(analysis.router, tags=["Analysis"])
app.include_router(reports.router, tags=["Reports"])

@app.get("/")
async def root():
    return {"message": "Clinical Decision Support System API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
