from __future__ import annotations

import json
import logging
import time
from dataclasses import dataclass
from typing import Any, Callable

import httpx

GEMINI_API_URL_TEMPLATE = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)
GEMINI_MODEL_ORDER: tuple[str, ...] = (
    "gemini-2.5-flash-lite",
    "gemini-2.5-flash",
    "gemini-1.5-flash",
)

DEFAULT_PROMPT_CHAR_LIMIT = 9000
DEFAULT_TIMEOUT_SECONDS = 45
DEFAULT_MAX_RETRIES = 2
DEFAULT_BACKOFF_SECONDS = 1.0
DEFAULT_CIRCUIT_BREAKER_THRESHOLD = 4
DEFAULT_CIRCUIT_BREAKER_COOLDOWN_SECONDS = 60.0
PROMPT_TRUNCATION_MARKER = "\n\n[...prompt truncated to fit request budget...]\n\n"

logger = logging.getLogger(__name__)

_circuit_breaker_state: dict[str, dict[str, float | int]] = {}


@dataclass(frozen=True)
class GeminiRequestOptions:
    api_key: str
    request_payload_builder: Callable[[str], dict[str, Any]]
    operation: str
    timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS
    max_retries: int = DEFAULT_MAX_RETRIES
    prompt_char_limit: int = DEFAULT_PROMPT_CHAR_LIMIT
    base_backoff_seconds: float = DEFAULT_BACKOFF_SECONDS
    metrics_hook: Callable[[dict[str, Any]], None] | None = None


class GeminiRequestError(Exception):
    """Raised when all Gemini models and retries fail."""


class GeminiTimeoutError(GeminiRequestError):
    """Raised when a Gemini request times out."""


class GeminiNetworkError(GeminiRequestError):
    """Raised when Gemini cannot be reached because of a network failure."""


class GeminiAPIError(GeminiRequestError):
    """Raised when Gemini returns a non-200 response."""


def call_gemini_with_fallback(
    prompt: str,
    options: GeminiRequestOptions,
) -> httpx.Response:
    """Call Gemini using the fixed fallback chain and per-model retry policy."""

    if not options.api_key:
        raise GeminiRequestError("Missing Gemini API key.")

    prompt_text = trim_prompt(prompt, options.prompt_char_limit)
    payload = options.request_payload_builder(prompt_text)
    prompt_length = len(prompt_text)
    failures: list[str] = []

    for model_index, model in enumerate(GEMINI_MODEL_ORDER, start=1):
        if _is_circuit_open(model):
            failures.append(f"{model}: circuit_open")
            _emit_attempt_log(
                level=logging.WARNING,
                event={
                    "event": "gemini_attempt",
                    "operation": options.operation,
                    "model": model,
                    "model_index": model_index,
                    "attempt": 0,
                    "max_retries": options.max_retries,
                    "prompt_length": prompt_length,
                    "timeout_seconds": options.timeout_seconds,
                    "status_code": None,
                    "response_time_ms": 0,
                    "error_type": "circuit_open",
                    "error_message": "Circuit breaker is open for this model.",
                    "trimmed_prompt": prompt_length != len(prompt),
                    "final": False,
                },
            )
            continue

        total_attempts = max(1, options.max_retries + 1)

        for attempt in range(1, total_attempts + 1):
            start_time = time.perf_counter()
            response: httpx.Response | None = None
            error_type: str | None = None
            error_message: str | None = None
            response_time_ms = 0

            try:
                with httpx.Client(timeout=httpx.Timeout(options.timeout_seconds)) as client:
                    response = client.post(
                        GEMINI_API_URL_TEMPLATE.format(model=model),
                        params={"key": options.api_key},
                        json=payload,
                    )

                response_time_ms = int((time.perf_counter() - start_time) * 1000)
                if response.status_code == 200:
                    _clear_model_failure(model)
                    _emit_attempt_log(
                        level=logging.INFO,
                        event={
                            "event": "gemini_attempt",
                            "operation": options.operation,
                            "model": model,
                            "model_index": model_index,
                            "attempt": attempt,
                            "max_retries": options.max_retries,
                            "prompt_length": prompt_length,
                            "timeout_seconds": options.timeout_seconds,
                            "status_code": response.status_code,
                            "response_time_ms": response_time_ms,
                            "error_type": None,
                            "error_message": None,
                            "trimmed_prompt": prompt_length != len(prompt),
                            "final": True,
                        },
                    )
                    _emit_metrics(
                        options.metrics_hook,
                        {
                            "operation": options.operation,
                            "model": model,
                            "attempt": attempt,
                            "prompt_length": prompt_length,
                            "response_time_ms": response_time_ms,
                            "status_code": response.status_code,
                            "error_type": None,
                        },
                    )
                    return response

                error_type = "api_error"
                error_message = safe_error_detail(response)
                failures.append(
                    f"{model}: api_error {response.status_code} ({error_message})"
                )
            except httpx.TimeoutException as exc:
                response_time_ms = int((time.perf_counter() - start_time) * 1000)
                error_type = "timeout"
                error_message = str(exc) or "request timed out"
                failures.append(f"{model}: timeout ({error_message})")
            except httpx.NetworkError as exc:
                response_time_ms = int((time.perf_counter() - start_time) * 1000)
                error_type = "network_error"
                error_message = str(exc) or "network error"
                failures.append(f"{model}: network_error ({error_message})")
            except httpx.HTTPError as exc:
                response_time_ms = int((time.perf_counter() - start_time) * 1000)
                error_type = "network_error"
                error_message = str(exc) or "http error"
                failures.append(f"{model}: network_error ({error_message})")

            if response is not None and response.status_code != 200:
                _record_model_failure(model)
            elif error_type is not None:
                _record_model_failure(model)

            _emit_attempt_log(
                level=logging.WARNING,
                event={
                    "event": "gemini_attempt",
                    "operation": options.operation,
                    "model": model,
                    "model_index": model_index,
                    "attempt": attempt,
                    "max_retries": options.max_retries,
                    "prompt_length": prompt_length,
                    "timeout_seconds": options.timeout_seconds,
                    "status_code": None if response is None else response.status_code,
                    "response_time_ms": response_time_ms,
                    "error_type": error_type,
                    "error_message": error_message,
                    "trimmed_prompt": prompt_length != len(prompt),
                    "final": attempt == total_attempts,
                },
            )
            _emit_metrics(
                options.metrics_hook,
                {
                    "operation": options.operation,
                    "model": model,
                    "attempt": attempt,
                    "prompt_length": prompt_length,
                    "response_time_ms": response_time_ms,
                    "status_code": None if response is None else response.status_code,
                    "error_type": error_type,
                },
            )

            if attempt < total_attempts:
                time.sleep(options.base_backoff_seconds * (2 ** (attempt - 1)))

    summary = "; ".join(failures) if failures else "No Gemini models were available."
    raise GeminiRequestError(
        f"Gemini request failed after trying all fallback models: {summary}"
    )


def trim_prompt(prompt: str, max_chars: int) -> str:
    """Hard-cap the request payload without dropping the full instruction block."""

    cleaned = prompt.strip()
    if max_chars <= 0 or len(cleaned) <= max_chars:
        return cleaned

    if max_chars <= len(PROMPT_TRUNCATION_MARKER):
        return cleaned[:max_chars]

    available = max_chars - len(PROMPT_TRUNCATION_MARKER)
    head_chars = max(1, int(available * 0.7))
    tail_chars = max(1, available - head_chars)
    return (
        cleaned[:head_chars].rstrip()
        + PROMPT_TRUNCATION_MARKER
        + cleaned[-tail_chars:].lstrip()
    )


def chunk_large_input(
    text: str,
    *,
    chunk_size: int = 6000,
    overlap: int = 200,
) -> list[str]:
    """Split very large inputs for future multi-pass processing."""

    cleaned = text.strip()
    if not cleaned:
        return []

    if chunk_size <= 0:
        raise ValueError("chunk_size must be greater than zero.")

    if overlap < 0 or overlap >= chunk_size:
        raise ValueError("overlap must be >= 0 and smaller than chunk_size.")

    if len(cleaned) <= chunk_size:
        return [cleaned]

    chunks: list[str] = []
    step = chunk_size - overlap
    for start in range(0, len(cleaned), step):
        chunks.append(cleaned[start : start + chunk_size])

    return chunks


def extract_gemini_text_output(data: dict[str, Any]) -> str:
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


def parse_gemini_json_text(text: str, *, error_prefix: str) -> dict[str, Any]:
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
        raise GeminiRequestError(
            f"{error_prefix} Failed to parse JSON payload from Gemini output."
        ) from exc

    if not isinstance(parsed, dict):
        raise GeminiRequestError(f"{error_prefix} Gemini output JSON must be an object.")

    return parsed


def safe_error_detail(response: httpx.Response) -> str:
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


def _emit_attempt_log(*, level: int, event: dict[str, Any]) -> None:
    logger.log(level, json.dumps(event, ensure_ascii=False, default=str))


def _emit_metrics(
    hook: Callable[[dict[str, Any]], None] | None,
    event: dict[str, Any],
) -> None:
    if hook is None:
        return

    try:
        hook(event)
    except Exception:  # noqa: BLE001
        logger.debug("Gemini metrics hook failed", exc_info=True)


def _record_model_failure(model: str) -> None:
    entry = _circuit_breaker_state.setdefault(
        model,
        {"failures": 0, "opened_at": 0.0},
    )
    entry["failures"] = int(entry.get("failures", 0)) + 1

    if entry["failures"] >= DEFAULT_CIRCUIT_BREAKER_THRESHOLD:
        entry["opened_at"] = time.time()


def _clear_model_failure(model: str) -> None:
    _circuit_breaker_state.pop(model, None)


def _is_circuit_open(model: str) -> bool:
    entry = _circuit_breaker_state.get(model)
    if not entry:
        return False

    failures = int(entry.get("failures", 0))
    opened_at = float(entry.get("opened_at", 0.0))
    if failures < DEFAULT_CIRCUIT_BREAKER_THRESHOLD:
        return False

    if time.time() - opened_at < DEFAULT_CIRCUIT_BREAKER_COOLDOWN_SECONDS:
        return True

    _circuit_breaker_state.pop(model, None)
    return False