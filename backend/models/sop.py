from pydantic import BaseModel, Field


class SOPRequest(BaseModel):
    text: str = Field(..., min_length=1, description="Statement of Purpose text")


class SOPAnalysisResponse(BaseModel):
    score: int
    strengths: list[str]
    weaknesses: list[str]
    suggestions: list[str]
