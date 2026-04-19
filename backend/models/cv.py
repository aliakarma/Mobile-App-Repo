from pydantic import BaseModel, Field, field_validator


class CVAnalysisRequest(BaseModel):
    cv_text: str = Field(
        ...,
        min_length=100,
        max_length=50000,
        description="Full CV or resume text",
    )
    target_opportunity: str = Field(
        ...,
        min_length=10,
        max_length=3000,
        description="Target scholarship or internship title and description",
    )

    @field_validator("cv_text", "target_opportunity")
    @classmethod
    def strip_and_validate(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("Field must not be empty after stripping whitespace.")
        return stripped


class CVAnalysisResponse(BaseModel):
    overall_fit_score: int          # 0–100
    strengths: list[str]            # what the CV does well for this opportunity
    gaps: list[str]                 # what is missing or weak
    tailoring_suggestions: list[str]   # specific edits to improve fit
    missing_keywords: list[str]     # keywords from opportunity not found in CV
    recommended_sections: list[str] # sections the CV should add or strengthen
