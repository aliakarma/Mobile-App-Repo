from fastapi import APIRouter, HTTPException

from models.sop import SOPAnalysisResponse, SOPRequest
from services.gemini_sop_service import GeminiServiceError, analyze_sop_with_gemini

router = APIRouter(tags=["sop"])


@router.post("/analyze-sop", response_model=SOPAnalysisResponse)
def analyze_sop(payload: SOPRequest) -> SOPAnalysisResponse:
    try:
        return analyze_sop_with_gemini(payload.text)
    except GeminiServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
