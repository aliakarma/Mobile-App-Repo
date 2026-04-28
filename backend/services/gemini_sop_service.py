from __future__ import annotations

import os

from ..models.sop import SOPAnalysisResponse
from .gemini_client import (
    DEFAULT_PROMPT_CHAR_LIMIT,
    GeminiRequestError,
    GeminiRequestOptions,
    call_gemini_with_fallback,
    extract_gemini_text_output,
    parse_gemini_json_text,
    trim_prompt,
)

PROMPT_TEMPLATE = """You are an admissions evaluation assistant.
Analyze the following Statement of Purpose (SOP) and return ONLY valid JSON.
Do not include markdown, explanations, or extra text.

Return schema exactly:
{{
  "score": number from 0 to 100,
  "strengths": ["short bullet point", "..."],
  "weaknesses": ["short bullet point", "..."],
  "suggestions": ["actionable suggestion", "..."]
}}

Rules:
- Keep each list concise (2 to 5 items).
- Be realistic and constructive.
- Score must reflect writing quality, clarity, motivation, evidence, and fit.

SOP TEXT:
{input_text}
"""

SOP_PROMPT_CHAR_LIMIT = 8500
SOP_INPUT_CHAR_LIMIT = 7000


class GeminiServiceError(Exception):
    """Raised when Gemini API interaction fails."""


def build_prompt(sop_text: str) -> str:
    input_text = trim_prompt(sop_text, SOP_INPUT_CHAR_LIMIT)
    prompt = PROMPT_TEMPLATE.format(input_text=input_text)
    return trim_prompt(prompt, SOP_PROMPT_CHAR_LIMIT)


def analyze_sop_with_gemini(sop_text: str) -> SOPAnalysisResponse:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise GeminiServiceError("Missing GEMINI_API_KEY environment variable.")

    prompt = build_prompt(sop_text)

    try:
        response = call_gemini_with_fallback(
            prompt,
            GeminiRequestOptions(
                api_key=api_key,
                operation="analyze_sop",
                timeout_seconds=int(os.getenv("GEMINI_TIMEOUT_SECONDS", "45")),
                max_retries=int(os.getenv("GEMINI_MAX_RETRIES", "2")),
                prompt_char_limit=DEFAULT_PROMPT_CHAR_LIMIT,
                request_payload_builder=_build_request_payload,
            ),
        )
    except GeminiRequestError as exc:
        raise GeminiServiceError(str(exc)) from exc

    try:
        data = response.json()
    except ValueError as exc:
        raise GeminiServiceError("Gemini response is not valid JSON.") from exc

    text_output = extract_gemini_text_output(data)
    if not text_output:
        raise GeminiServiceError("Gemini response did not include text output.")

    parsed = parse_gemini_json_text(text_output, error_prefix="SOP analysis:")

    try:
        return SOPAnalysisResponse.model_validate(parsed)
    except Exception as exc:  # noqa: BLE001
        raise GeminiServiceError(
            "Gemini returned JSON that does not match the required schema."
        ) from exc


def _build_request_payload(prompt: str) -> dict[str, object]:
    return {
        "contents": [
            {
                "parts": [
                    {
                        "text": prompt,
                    }
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.2,
            "responseMimeType": "application/json",
        },
    }
