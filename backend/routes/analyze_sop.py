from fastapi import APIRouter

from models.sop import SOPAnalysisResponse, SOPRequest

router = APIRouter(tags=["sop"])


@router.post("/analyze-sop", response_model=SOPAnalysisResponse)
def analyze_sop(payload: SOPRequest) -> SOPAnalysisResponse:
    text = payload.text.strip()
    lowered = text.lower()

    strengths: list[str] = []
    weaknesses: list[str] = []
    suggestions: list[str] = []

    score = 50

    if len(text) >= 600:
        strengths.append("SOP has good detail and sufficient length.")
        score += 15
    else:
        weaknesses.append("SOP is too short and may lack depth.")
        suggestions.append("Expand your motivation, projects, and long-term goals.")
        score -= 10

    if any(keyword in lowered for keyword in ["research", "project", "internship"]):
        strengths.append("Highlights academic or practical experience.")
        score += 10
    else:
        weaknesses.append("Missing concrete academic/project experience examples.")
        suggestions.append("Add specific projects, internships, or research work.")
        score -= 5

    if any(keyword in lowered for keyword in ["goal", "future", "impact"]):
        strengths.append("Shows future vision and purpose.")
        score += 10
    else:
        weaknesses.append("Future goals are not clearly defined.")
        suggestions.append("State clear short-term and long-term career goals.")
        score -= 5

    if "why" in lowered and "university" in lowered:
        strengths.append("Contains a program/university motivation narrative.")
        score += 10
    else:
        suggestions.append("Explain why this specific university or program is a strong fit.")

    score = max(0, min(100, score))

    if not strengths:
        strengths.append("SOP has a foundational structure to build on.")

    if not weaknesses:
        weaknesses.append("Minor improvements can still improve clarity and impact.")

    if not suggestions:
        suggestions.append("Refine wording for clarity and keep a strong narrative flow.")

    return SOPAnalysisResponse(
        score=score,
        strengths=strengths,
        weaknesses=weaknesses,
        suggestions=suggestions,
    )
