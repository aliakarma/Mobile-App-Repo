from fastapi import APIRouter, HTTPException

from models.cv import CVAnalysisRequest, CVAnalysisResponse
from services.gemini_cv_service import GeminiCVServiceError, analyze_cv_with_gemini

router = APIRouter(tags=["cv"])


@router.post("/analyze-cv", response_model=CVAnalysisResponse)
def analyze_cv(payload: CVAnalysisRequest) -> CVAnalysisResponse:
    """
    Analyse a CV/resume against a target scholarship or internship opportunity
    using Gemini. Returns a structured assessment with fit score, strengths,
    gaps, and tailoring suggestions specific to the opportunity.
    """
    try:
        return analyze_cv_with_gemini(
            cv_text=payload.cv_text,
            cv_pdf_base64=payload.cv_pdf_base64,
            cv_pdf_filename=payload.cv_pdf_filename,
            target_opportunity=payload.target_opportunity,
        )
    except GeminiCVServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
