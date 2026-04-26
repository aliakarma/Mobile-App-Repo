from pydantic import BaseModel, Field, field_validator, model_validator


class CVAnalysisRequest(BaseModel):
    cv_text: str | None = Field(
        default=None,
        max_length=50000,
        description="Full CV or resume text",
    )
    cv_pdf_base64: str | None = Field(
        default=None,
        description="Base64-encoded PDF bytes for CV/resume",
    )
    cv_pdf_filename: str | None = Field(
        default=None,
        max_length=255,
        description="Optional PDF filename for logging and diagnostics",
    )
    target_opportunity: str = Field(
        ...,
        min_length=10,
        max_length=3000,
        description="Target scholarship or internship title and description",
    )

    @field_validator("cv_text")
    @classmethod
    def normalize_cv_text(cls, value: str | None) -> str | None:
        if value is None:
            return None

        stripped = value.strip()
        if not stripped:
            return None

        return stripped

    @field_validator("target_opportunity")
    @classmethod
    def validate_target_opportunity(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("target_opportunity must not be empty.")
        return stripped

    @model_validator(mode="after")
    def validate_cv_source(self) -> "CVAnalysisRequest":
        has_text = bool(self.cv_text and self.cv_text.strip())
        has_pdf = bool(self.cv_pdf_base64 and self.cv_pdf_base64.strip())

        if not has_text and not has_pdf:
            raise ValueError("Provide either cv_text or cv_pdf_base64.")

        if has_text and self.cv_text is not None and len(self.cv_text) < 100:
            raise ValueError("cv_text must be at least 100 characters when provided.")

        return self


class CVAnalysisResponse(BaseModel):
    overall_fit_score: int          # 0–100
    strengths: list[str]            # what the CV does well for this opportunity
    gaps: list[str]                 # what is missing or weak
    tailoring_suggestions: list[str]   # specific edits to improve fit
    missing_keywords: list[str]     # keywords from opportunity not found in CV
    recommended_sections: list[str] # sections the CV should add or strengthen
