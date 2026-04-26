"""
gemini_cv_service.py

Uses the Gemini API to analyse a CV/resume against a target scholarship or
internship opportunity. Returns structured feedback covering fit score,
strengths, gaps, tailoring suggestions, missing keywords, and recommended
sections.

Shares retry/extraction utilities from gemini_sop_service.py architecture.
"""

from __future__ import annotations

import base64
import binascii
import io
import json
import os
import time
from typing import Any

import requests
from pypdf import PdfReader

from models.cv import CVAnalysisResponse

GEMINI_API_URL_TEMPLATE = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_MODEL_FALLBACKS = os.getenv(
    "GEMINI_MODEL_FALLBACKS", "gemini-2.5-flash-lite,gemini-1.5-flash"
)

CV_PROMPT_TEMPLATE = """You are an expert scholarship and internship application reviewer with 15 years of experience evaluating CVs for competitive academic programmes at universities like MIT, Stanford, NUS, KAUST, and MBZUAI.

Your task: Analyse the provided CV against the target opportunity and return ONLY valid JSON. No markdown, no explanation, no preamble.

TARGET OPPORTUNITY:
{target_opportunity}

APPLICANT CV:
{cv_text}

Return this JSON schema exactly:
{{
  "overall_fit_score": <integer 0-100>,
  "strengths": ["<what the CV does well for THIS specific opportunity>", ...],
  "gaps": ["<specific weakness relative to THIS opportunity>", ...],
  "tailoring_suggestions": ["<concrete, actionable edit the applicant should make>", ...],
  "missing_keywords": ["<important term from the opportunity description absent from the CV>", ...],
  "recommended_sections": ["<section the CV should add or expand, e.g. 'Research Publications', 'Technical Skills'>", ...]
}}

Rules:
- overall_fit_score must reflect genuine fit: 0–40 = poor, 41–65 = moderate, 66–80 = strong, 81–100 = exceptional.
- Each list should contain 3–6 concise, specific items. No vague generalities.
- tailoring_suggestions must be actionable ("Add a bullet under your GOMDP project describing the MARL algorithm used and the benchmark results") not vague ("improve your research section").
- missing_keywords should be exact phrases from the opportunity description that a keyword-scanning reviewer would look for.
- Be honest and constructively critical. Do not flatter the applicant.
"""


class GeminiCVServiceError(Exception):
    """Raised when Gemini CV analysis fails."""


def analyze_cv_with_gemini(
    cv_text: str | None,
    target_opportunity: str,
    cv_pdf_base64: str | None = None,
    cv_pdf_filename: str | None = None,
) -> CVAnalysisResponse:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise GeminiCVServiceError("Missing GEMINI_API_KEY environment variable.")

    resolved_cv_text = _resolve_cv_text(
        cv_text=cv_text,
        cv_pdf_base64=cv_pdf_base64,
        cv_pdf_filename=cv_pdf_filename,
    )

    prompt = CV_PROMPT_TEMPLATE.format(
        cv_text=resolved_cv_text,
        target_opportunity=target_opportunity.strip(),
    )

    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.15,
            "responseMimeType": "application/json",
        },
    }

    response = _request_with_model_fallback(
        api_key=api_key,
        payload=payload,
        timeout_seconds=20,
    )

    if response.status_code != 200:
        detail = _safe_error_detail(response)
        raise GeminiCVServiceError(
            f"Gemini API returned {response.status_code}: {detail}"
        )

    try:
        data = response.json()
    except ValueError as exc:
        raise GeminiCVServiceError("Gemini response is not valid JSON.") from exc

    text_output = _extract_text_output(data)
    if not text_output:
        raise GeminiCVServiceError("Gemini response contained no text output.")

    parsed = _parse_json_text(text_output)

    # Clamp fit score to valid range
    if "overall_fit_score" in parsed:
        parsed["overall_fit_score"] = max(0, min(100, int(parsed["overall_fit_score"])))

    try:
        return CVAnalysisResponse.model_validate(parsed)
    except Exception as exc:  # noqa: BLE001
        raise GeminiCVServiceError(
            "Gemini output does not match the CVAnalysisResponse schema."
        ) from exc


def _resolve_cv_text(
    *,
    cv_text: str | None,
    cv_pdf_base64: str | None,
    cv_pdf_filename: str | None,
) -> str:
    if cv_pdf_base64 and cv_pdf_base64.strip():
        return _extract_pdf_text_from_base64(
            cv_pdf_base64.strip(),
            cv_pdf_filename=cv_pdf_filename,
        )

    if cv_text and cv_text.strip():
        return cv_text.strip()

    raise GeminiCVServiceError("Provide cv_text or cv_pdf_base64 for CV analysis.")


def _extract_pdf_text_from_base64(pdf_b64: str, cv_pdf_filename: str | None) -> str:
    try:
        pdf_bytes = base64.b64decode(pdf_b64, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise GeminiCVServiceError("Invalid base64 payload for CV PDF.") from exc

    if not pdf_bytes:
        raise GeminiCVServiceError("Uploaded CV PDF is empty.")

    try:
        reader = PdfReader(io.BytesIO(pdf_bytes))
        extracted_pages = [page.extract_text() or "" for page in reader.pages]
    except Exception as exc:  # noqa: BLE001
        filename_label = cv_pdf_filename or "Uploaded PDF"
        raise GeminiCVServiceError(
            f"Failed to read {filename_label}. Ensure it is a valid text-based PDF."
        ) from exc

    extracted_text = "\n".join(extracted_pages).strip()
    if len(extracted_text) < 100:
        raise GeminiCVServiceError(
            "Could not extract enough text from PDF. Try a text-based PDF or paste CV text."
        )

    return extracted_text


# ---------------------------------------------------------------------------
# Shared internal helpers (mirrors gemini_sop_service.py pattern)
# ---------------------------------------------------------------------------

def _extract_text_output(data: dict[str, Any]) -> str:
    candidates = data.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        return ""
    first = candidates[0]
    if not isinstance(first, dict):
        return ""
    content = first.get("content")
    if not isinstance(content, dict):
        return ""
    parts = content.get("parts")
    if not isinstance(parts, list) or not parts:
        return ""
    first_part = parts[0]
    if not isinstance(first_part, dict):
        return ""
    text = first_part.get("text")
    return text.strip() if isinstance(text, str) else ""


def _parse_json_text(text: str) -> dict[str, Any]:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.strip("`")
        if cleaned.startswith("json"):
            cleaned = cleaned[4:].strip()
    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start != -1 and end != -1 and end > start:
        cleaned = cleaned[start: end + 1]
    try:
        parsed = json.loads(cleaned)
    except json.JSONDecodeError as exc:
        raise GeminiCVServiceError("Failed to parse JSON from Gemini CV output.") from exc
    if not isinstance(parsed, dict):
        raise GeminiCVServiceError("Gemini CV output must be a JSON object.")
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


def _request_with_model_fallback(
    *,
    api_key: str,
    payload: dict[str, Any],
    timeout_seconds: int,
) -> requests.Response:
    last_response: requests.Response | None = None

    for model in _candidate_models():
        response = _request_with_retry(
            url=GEMINI_API_URL_TEMPLATE.format(model=model),
            api_key=api_key,
            payload=payload,
            max_attempts=3,
            timeout_seconds=timeout_seconds,
        )

        if response.status_code == 200:
            return response

        if not _is_model_not_supported(response):
            return response

        last_response = response

    if last_response is not None:
        return last_response

    raise GeminiCVServiceError("No Gemini model candidates were configured.")


def _candidate_models() -> list[str]:
    models: list[str] = []
    for value in [GEMINI_MODEL, GEMINI_MODEL_FALLBACKS]:
        for model in value.split(","):
            cleaned = model.strip()
            if cleaned and cleaned not in models:
                models.append(cleaned)
    return models


def _is_model_not_supported(response: requests.Response) -> bool:
    if response.status_code not in {400, 404}:
        return False

    detail = _safe_error_detail(response).lower()
    return "not found" in detail or "not supported" in detail


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
    raise GeminiCVServiceError(f"Gemini CV request failed after retries: {last_error}")
