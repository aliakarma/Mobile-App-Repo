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
import os

from pypdf import PdfReader

from ..models.cv import CVAnalysisResponse
from .gemini_client import (
    DEFAULT_PROMPT_CHAR_LIMIT,
    GeminiRequestError,
    GeminiRequestOptions,
    call_gemini_with_fallback,
    chunk_large_input,
    extract_gemini_text_output,
    parse_gemini_json_text,
    trim_prompt,
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

CV_PDF_PROMPT_TEMPLATE = """You are an expert scholarship and internship application reviewer with 15 years of experience evaluating CVs for competitive academic programmes at universities like MIT, Stanford, NUS, KAUST, and MBZUAI.

You will receive a CV as an attached PDF document. Read the PDF content (including scanned pages) and analyse it against the target opportunity below.

TARGET OPPORTUNITY:
{target_opportunity}

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
- Return ONLY valid JSON. No markdown, no explanation, no preamble.
- overall_fit_score must reflect genuine fit: 0-40 poor, 41-65 moderate, 66-80 strong, 81-100 exceptional.
- Each list should contain 3-6 concise, specific items.
- Be honest and constructively critical.
"""

CV_PROMPT_CHAR_LIMIT = 9000
CV_TEXT_CHAR_LIMIT = 5000
CV_TARGET_CHAR_LIMIT = 3500


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

    prompt = _build_prompt(
        cv_text=cv_text,
        target_opportunity=target_opportunity,
        cv_pdf_base64=cv_pdf_base64,
        cv_pdf_filename=cv_pdf_filename,
    )

    try:
        response = call_gemini_with_fallback(
            prompt,
            GeminiRequestOptions(
                api_key=api_key,
                operation="analyze_cv",
                timeout_seconds=int(os.getenv("GEMINI_CV_TIMEOUT_SECONDS", "45")),
                max_retries=int(os.getenv("GEMINI_MAX_RETRIES", "2")),
                prompt_char_limit=DEFAULT_PROMPT_CHAR_LIMIT,
                request_payload_builder=_build_request_payload,
            ),
        )
    except GeminiRequestError as exc:
        raise GeminiCVServiceError(str(exc)) from exc

    try:
        data = response.json()
    except ValueError as exc:
        raise GeminiCVServiceError("Gemini response is not valid JSON.") from exc

    text_output = extract_gemini_text_output(data)
    if not text_output:
        raise GeminiCVServiceError("Gemini response contained no text output.")

    parsed = parse_gemini_json_text(text_output, error_prefix="CV analysis:")

    if "overall_fit_score" in parsed:
        parsed["overall_fit_score"] = max(0, min(100, int(parsed["overall_fit_score"])))

    try:
        return CVAnalysisResponse.model_validate(parsed)
    except Exception as exc:  # noqa: BLE001
        raise GeminiCVServiceError(
            "Gemini output does not match the CVAnalysisResponse schema."
        ) from exc


def _build_prompt(
    *,
    cv_text: str | None,
    target_opportunity: str,
    cv_pdf_base64: str | None,
    cv_pdf_filename: str | None,
) -> str:
    target_text = trim_prompt(target_opportunity, CV_TARGET_CHAR_LIMIT)

    if cv_pdf_base64 and cv_pdf_base64.strip():
        cleaned_pdf = cv_pdf_base64.strip()
        extracted_text = _extract_pdf_text_from_base64(
            cleaned_pdf,
            cv_pdf_filename=cv_pdf_filename,
        )

        if len(extracted_text) >= 100:
            compact_cv_text = _compact_text_for_prompt(extracted_text, CV_TEXT_CHAR_LIMIT)
            prompt = CV_PROMPT_TEMPLATE.format(
                cv_text=compact_cv_text,
                target_opportunity=target_text,
            )
            return trim_prompt(prompt, CV_PROMPT_CHAR_LIMIT)

        prompt = CV_PDF_PROMPT_TEMPLATE.format(target_opportunity=target_text)
        return trim_prompt(prompt, CV_PROMPT_CHAR_LIMIT)

    if cv_text and cv_text.strip():
        compact_cv_text = _compact_text_for_prompt(cv_text, CV_TEXT_CHAR_LIMIT)
        prompt = CV_PROMPT_TEMPLATE.format(
            cv_text=compact_cv_text,
            target_opportunity=target_text,
        )
        return trim_prompt(prompt, CV_PROMPT_CHAR_LIMIT)

    raise GeminiCVServiceError("Provide cv_text or cv_pdf_base64 for CV analysis.")


def _compact_text_for_prompt(text: str, limit: int) -> str:
    cleaned = text.strip()
    if len(cleaned) <= limit:
        return cleaned

    chunks = chunk_large_input(cleaned, chunk_size=limit, overlap=min(250, limit // 10))
    if not chunks:
        return trim_prompt(cleaned, limit)

    first_chunk = chunks[0]
    last_chunk = chunks[-1]
    if first_chunk == last_chunk:
        return first_chunk

    combined = f"{first_chunk}\n\n[...middle sections omitted for brevity...]\n\n{last_chunk}"
    return trim_prompt(combined, limit)


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
            "temperature": 0.15,
            "responseMimeType": "application/json",
        },
    }


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
    except Exception:  # noqa: BLE001
        return ""

    return "\n".join(extracted_pages).strip()
