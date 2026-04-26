from pathlib import Path
import logging
import os

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

logger = logging.getLogger(__name__)

from .routes.analyze_cv import router as analyze_cv_router
from .routes.analyze_sop import router as analyze_sop_router
from .routes.auth import router as auth_router
from .routes.live_opportunities import router as live_opportunities_router
from .routes.opportunities import router as opportunities_router
from .services.auth_service import init_auth_db
from .services.opportunities_cache_service import init_opportunities_db
from .services.opportunities_cache_service import refresh_live_opportunities_cache

app = FastAPI(
    title="Smart Application Intelligence System API",
    version="2.0.0",
    description=(
        "AI-powered backend for student scholarship and internship tracking. "
        "Provides live opportunity fetching, Gemini SOP analysis, and CV analysis."
    ),
)


def _is_debug_mode() -> bool:
    return os.getenv("DEBUG", "false").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


def _load_allowed_origins() -> list[str]:
    raw = os.getenv("ALLOWED_ORIGINS", "")
    origins = [origin.strip() for origin in raw.split(",") if origin.strip()]
    origins = [origin for origin in origins if origin != "*"]

    if origins:
        return origins

    if _is_debug_mode():
        return [
            "http://localhost:3000",
            "http://localhost:5173",
            "http://localhost:8000",
            "http://127.0.0.1:3000",
            "http://127.0.0.1:5173",
            "http://127.0.0.1:8000",
        ]

    return []


def _error_payload(*, code: str, user_message: str, retryable: bool) -> dict[str, object]:
    return {
        "code": code,
        "user_message": user_message,
        "retryable": retryable,
    }

app.add_middleware(
    CORSMiddleware,
    allow_origins=_load_allowed_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup_event() -> None:
    init_auth_db()
    init_opportunities_db()
    # Warm the cache on startup (scraping is best-effort and failures are tolerated).
    try:
        refresh_live_opportunities_cache()
    except Exception as exc:  # noqa: BLE001
        logger.warning("Failed to warm opportunities cache on startup: %s", exc)


@app.exception_handler(HTTPException)
async def http_exception_handler(
    _request: Request, exc: HTTPException
) -> JSONResponse:
    code = "request_error"
    retryable = False
    user_message = "Request failed."

    if exc.status_code == status.HTTP_401_UNAUTHORIZED:
        code = "unauthorized"
        user_message = "Authentication is required or has expired."
    elif exc.status_code == status.HTTP_403_FORBIDDEN:
        code = "forbidden"
        user_message = "You do not have permission to perform this action."
    elif exc.status_code == status.HTTP_404_NOT_FOUND:
        code = "not_found"
        user_message = "The requested resource was not found."
    elif exc.status_code == status.HTTP_429_TOO_MANY_REQUESTS:
        code = "rate_limited"
        user_message = "Too many requests. Please try again later."
        retryable = True
    elif 400 <= exc.status_code < 500:
        detail = exc.detail if isinstance(exc.detail, str) else None
        user_message = detail or "The request was invalid."
        code = "bad_request"
    elif exc.status_code >= 500:
        code = "server_error"
        user_message = "The server could not process your request."
        retryable = True

    return JSONResponse(
        status_code=exc.status_code,
        content=_error_payload(
            code=code,
            user_message=user_message,
            retryable=retryable,
        ),
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    _request: Request, exc: RequestValidationError
) -> JSONResponse:
    logger.info("Validation error: %s", exc)
    return JSONResponse(
        status_code=422,
        content=_error_payload(
            code="validation_error",
            user_message="Some fields are invalid. Please review your input.",
            retryable=False,
        ),
    )


@app.exception_handler(Exception)
async def generic_exception_handler(_request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled exception", exc_info=exc)
    return JSONResponse(
        status_code=500,
        content=_error_payload(
            code="internal_error",
            user_message="Something went wrong on our side. Please try again.",
            retryable=True,
        ),
    )


# Routers
app.include_router(opportunities_router)          # GET /opportunities  (static JSON)
app.include_router(live_opportunities_router)     # GET /opportunities/live  (scraped)
app.include_router(analyze_sop_router)            # POST /analyze-sop
app.include_router(analyze_cv_router)             # POST /analyze-cv
app.include_router(auth_router)                   # /auth/*


@app.get("/")
def health_check() -> dict[str, str]:
    return {
        "message": "Smart Application Intelligence System API is running",
        "version": "2.0.0",
        "endpoints": (
            "/opportunities | /opportunities/live | /analyze-sop | "
            "/analyze-cv | /auth/signup | /auth/login | /auth/me | /auth/logout"
        ),
    }
