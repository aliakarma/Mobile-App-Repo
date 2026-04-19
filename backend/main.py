from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from routes.analyze_cv import router as analyze_cv_router
from routes.analyze_sop import router as analyze_sop_router
from routes.live_opportunities import router as live_opportunities_router
from routes.opportunities import router as opportunities_router

app = FastAPI(
    title="Smart Application Intelligence System API",
    version="2.0.0",
    description=(
        "AI-powered backend for student scholarship and internship tracking. "
        "Provides live opportunity fetching, Gemini SOP analysis, and CV analysis."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(HTTPException)
async def http_exception_handler(
    _request: Request, exc: HTTPException
) -> JSONResponse:
    detail = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": "request_error", "detail": detail},
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    _request: Request, exc: RequestValidationError
) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"error": "validation_error", "detail": str(exc)},
    )


@app.exception_handler(Exception)
async def generic_exception_handler(_request: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content={"error": "internal_error", "detail": str(exc)},
    )


# Routers
app.include_router(opportunities_router)          # GET /opportunities  (static JSON)
app.include_router(live_opportunities_router)     # GET /opportunities/live  (scraped)
app.include_router(analyze_sop_router)            # POST /analyze-sop
app.include_router(analyze_cv_router)             # POST /analyze-cv


@app.get("/")
def health_check() -> dict[str, str]:
    return {
        "message": "Smart Application Intelligence System API is running",
        "version": "2.0.0",
        "endpoints": "/opportunities | /opportunities/live | /analyze-sop | /analyze-cv",
    }
