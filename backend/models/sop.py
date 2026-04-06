from pydantic import BaseModel, Field, field_validator


class SOPRequest(BaseModel):
    text: str = Field(
        ...,
        min_length=50,
        max_length=20000,
        description="Statement of Purpose text",
    )

    @field_validator("text")
    @classmethod
    def validate_text(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("SOP text must not be empty.")
        return stripped


class SOPAnalysisResponse(BaseModel):
    score: int
    strengths: list[str]
    weaknesses: list[str]
    suggestions: list[str]
