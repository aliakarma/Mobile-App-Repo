from __future__ import annotations

import unittest
from collections import deque
from unittest.mock import patch

import httpx

from backend.services.gemini_client import (
    GeminiRequestError,
    GeminiRequestOptions,
    call_gemini_with_fallback,
    trim_prompt,
)


class FakeResponse:
    def __init__(self, status_code: int, payload: dict[str, object] | None = None):
        self.status_code = status_code
        self._payload = payload or {}
        self.text = ""

    def json(self) -> dict[str, object]:
        return self._payload


class FakeClient:
    requested_models: list[str] = []
    actions: deque[object] = deque()

    def __init__(self, timeout: httpx.Timeout) -> None:
        self.timeout = timeout

    def __enter__(self) -> "FakeClient":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        return None

    def post(self, url: str, params: dict[str, str], json: dict[str, object]) -> FakeResponse:
        del params, json
        model = url.split("/models/")[1].split(":", 1)[0]
        self.requested_models.append(model)

        if not self.actions:
            raise AssertionError("No fake action configured for Gemini request")

        action = self.actions.popleft()
        if isinstance(action, Exception):
            raise action

        if not isinstance(action, FakeResponse):
            raise AssertionError("Fake action must be a FakeResponse or Exception")

        return action


class GeminiClientTests(unittest.TestCase):
    def setUp(self) -> None:
        FakeClient.requested_models = []
        FakeClient.actions = deque()

    def test_call_gemini_retries_each_model_then_moves_to_next(self) -> None:
        FakeClient.actions = deque(
            [
                httpx.TimeoutException("timeout 1"),
                httpx.TimeoutException("timeout 2"),
                FakeResponse(500, {"error": {"message": "server error"}}),
                FakeResponse(200, {"candidates": []}),
            ]
        )

        with patch("backend.services.gemini_client.httpx.Client", FakeClient), patch(
            "backend.services.gemini_client.time.sleep",
            return_value=None,
        ):
            response = call_gemini_with_fallback(
                "hello world",
                GeminiRequestOptions(
                    api_key="test-key",
                    operation="unit_test",
                    timeout_seconds=1,
                    max_retries=1,
                    request_payload_builder=lambda prompt: {
                        "contents": [{"parts": [{"text": prompt}]}]
                    },
                ),
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            FakeClient.requested_models,
            [
                "gemini-2.5-flash-lite",
                "gemini-2.5-flash-lite",
                "gemini-2.5-flash",
                "gemini-2.5-flash",
            ],
        )

    def test_call_gemini_raises_after_all_models_and_retries_fail(self) -> None:
        FakeClient.actions = deque(
            [
                httpx.TimeoutException("timeout") for _ in range(6)
            ]
        )

        with patch("backend.services.gemini_client.httpx.Client", FakeClient), patch(
            "backend.services.gemini_client.time.sleep",
            return_value=None,
        ):
            with self.assertRaises(GeminiRequestError) as context:
                call_gemini_with_fallback(
                    "hello world",
                    GeminiRequestOptions(
                        api_key="test-key",
                        operation="unit_test",
                        timeout_seconds=1,
                        max_retries=1,
                        request_payload_builder=lambda prompt: {
                            "contents": [{"parts": [{"text": prompt}]}]
                        },
                    ),
                )

        self.assertIn("gemini-2.5-flash-lite", str(context.exception))
        self.assertIn("gemini-1.5-flash", str(context.exception))
        self.assertEqual(len(FakeClient.requested_models), 6)

    def test_trim_prompt_enforces_hard_cap(self) -> None:
        prompt = "x" * 10000
        trimmed = trim_prompt(prompt, 9000)

        self.assertLessEqual(len(trimmed), 9000)
        self.assertIn("prompt truncated", trimmed)


if __name__ == "__main__":
    unittest.main()