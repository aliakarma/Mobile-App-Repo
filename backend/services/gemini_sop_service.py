from __future__ import annotations

import json
import os
import time
from typing import Any

import requests

from models.sop import SOPAnalysisResponse

GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
GEMINI_API_URL_TEMPLATE = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)

PROMPT_TEMPLATE = """You are an admissions evaluation assistant.
Analyze the following Statement of Purpose (SOP) and return ONLY valid JSON.
Do not include markdown, explanations, or extra text.

Return schema exactly:
{
  "score": number from 0 to 100,
  "strengths": ["short bullet point", "..."],
  "weaknesses": ["short bullet point", "..."],
  "suggestions": ["actionable suggestion", "..."]
}

Rules:
- Keep each list concise (2 to 5 items).
- Be realistic and constructive.
- Score must reflect writing quality, clarity, motivation, evidence, and fit.

SOP TEXT:
{input_text}
"""


class GeminiServiceError(Exception):
    """Raised when Gemini API interaction fails."""


def build_prompt(sop_text: str) -> str:
    return PROMPT_TEMPLATE.format(input_text=sop_text.strip())


def analyze_sop_with_gemini(sop_text: str) -> SOPAnalysisResponse:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise GeminiServiceError("Missing GEMINI_API_KEY environment variable.")

    prompt = build_prompt(sop_text)
    url = GEMINI_API_URL_TEMPLATE.format(model=GEMINI_MODEL)

    payload = {
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

    response = _request_with_retry(
        url=url,
        api_key=api_key,
        payload=payload,
        max_attempts=3,
        timeout_seconds=15,
    )

    if response.status_code != 200:
        detail = _safe_error_detail(response)
        raise GeminiServiceError(
            f"Gemini API returned {response.status_code}: {detail}"
        )

    try:
        data = response.json()
    except ValueError as exc:
        raise GeminiServiceError("Gemini response is not valid JSON.") from exc

    text_output = _extract_text_output(data)
    if not text_output:
        raise GeminiServiceError("Gemini response did not include text output.")

    parsed = _parse_json_text(text_output)

    try:
        return SOPAnalysisResponse.model_validate(parsed)
    except Exception as exc:  # noqa: BLE001
        raise GeminiServiceError(
            "Gemini returned JSON that does not match the required schema."
        ) from exc


def _extract_text_output(data: dict[str, Any]) -> str:
    candidates = data.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        return ""

    first_candidate = candidates[0]
    if not isinstance(first_candidate, dict):
        return ""

    content = first_candidate.get("content")
    if not isinstance(content, dict):
        return ""

    parts = content.get("parts")
    if not isinstance(parts, list) or not parts:
        return ""

    first_part = parts[0]
    if not isinstance(first_part, dict):
        return ""

    text = first_part.get("text")
    if not isinstance(text, str):
        return ""

    return text.strip()


def _parse_json_text(text: str) -> dict[str, Any]:
    cleaned = text.strip()

    if cleaned.startswith("```"):
        cleaned = cleaned.strip("`")
        if cleaned.startswith("json"):
            cleaned = cleaned[4:].strip()

    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start != -1 and end != -1 and end > start:
        cleaned = cleaned[start : end + 1]

    try:
        parsed = json.loads(cleaned)
    except json.JSONDecodeError as exc:
        raise GeminiServiceError("Failed to parse JSON payload from Gemini output.") from exc

    if not isinstance(parsed, dict):
        raise GeminiServiceError("Gemini output JSON must be an object.")

    return parsed


def _safe_error_detail(response: requests.Response) -> str:
    try:
        body = response.json()
    except ValueError:
        return response.text[:200] if response.text else "Unknown error"

    if isinstance(body, dict):
        error = body.get("error")
        if isinstance(error, dict):
            message = error.get("message")
            if isinstance(message, str) and message.strip():
                return message.strip()

    return "Unknown error"


def _request_with_retry(
    *,
    url: str,
    api_key: str,
    payload: dict[str, Any],
    max_attempts: int,
    timeout_seconds: int,
) -> requests.Response:
    last_error: Exception | None = None

    for attempt in range(1, max_attempts + 1):
        try:
            return requests.post(
                url,
                params={"key": api_key},
                json=payload,
                timeout=timeout_seconds,
            )
        except requests.Timeout as exc:
            last_error = exc
        except requests.RequestException as exc:
            last_error = exc

        if attempt < max_attempts:
            time.sleep(0.5 * attempt)

    raise GeminiServiceError(f"Gemini request failed after retries: {last_error}")
