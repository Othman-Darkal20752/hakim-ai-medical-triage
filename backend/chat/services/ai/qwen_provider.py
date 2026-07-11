from collections.abc import Sequence
from typing import Any

import requests

from .config import AIProviderConfig, load_ai_provider_config
from .exceptions import (
    AIConfigurationError,
    AIInvalidResponseError,
    AIProviderConnectionError,
    AIProviderTimeoutError,
)
from .provider import AIMessage, AIProvider, AIProviderResult


class QwenProvider(AIProvider):
    """
    Qwen implementation using the OpenAI-compatible Chat Completions API.

    This class performs provider communication only. Medical prompting,
    red-flag detection, response validation, and database access belong
    to higher application layers.
    """

    def __init__(
        self,
        config: AIProviderConfig | None = None,
    ) -> None:
        self._config = config or load_ai_provider_config()

        if self._config.provider != "qwen":
            raise AIConfigurationError(
                "QwenProvider requires AI_PROVIDER to be set to 'qwen'."
            )

        self._endpoint = (
            f"{self._config.api_base_url.rstrip('/')}/chat/completions"
        )

    def generate_structured(
        self,
        *,
        messages: Sequence[AIMessage],
    ) -> AIProviderResult:
        payload = {
            "model": self._config.model,
            "messages": [
                {
                    "role": message.role,
                    "content": message.content,
                }
                for message in messages
            ],
            "stream": False,
        }

        headers = {
            "Authorization": f"Bearer {self._config.api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

        try:
            response = requests.post(
                self._endpoint,
                headers=headers,
                json=payload,
                timeout=self._config.timeout_seconds,
            )
            response.raise_for_status()

        except requests.Timeout as exc:
            raise AIProviderTimeoutError() from exc

        except requests.HTTPError as exc:
            status_code = (
                exc.response.status_code
                if exc.response is not None
                else None
            )

            if (
                status_code is not None
                and 400 <= status_code < 500
                and status_code not in {408, 429}
            ):
                raise AIConfigurationError(
                    f"The AI provider rejected the request "
                    f"with HTTP status {status_code}."
                ) from exc

            raise AIProviderConnectionError(
                self._build_http_error_message(status_code)
            ) from exc

        except requests.ConnectionError as exc:
            raise AIProviderConnectionError() from exc

        except requests.RequestException as exc:
            raise AIProviderConnectionError() from exc

        response_data = self._parse_response(response)

        return AIProviderResult(
            provider="qwen",
            model=str(
                response_data.get("model") or self._config.model
            ),
            raw_json=response_data["content"],
            request_id=response_data.get("request_id"),
        )

    @staticmethod
    def _parse_response(
        response: requests.Response,
    ) -> dict[str, Any]:
        try:
            response_body = response.json()

            choices = response_body["choices"]

            if not isinstance(choices, list) or not choices:
                raise ValueError("Response choices are missing.")

            first_choice = choices[0]

            if not isinstance(first_choice, dict):
                raise ValueError("The first response choice is invalid.")

            message = first_choice["message"]

            if not isinstance(message, dict):
                raise ValueError("The response message is invalid.")

            content = message["content"]

            if not isinstance(content, str) or not content.strip():
                raise ValueError("The response content is empty.")

            request_id = response_body.get("id")

            if request_id is not None:
                request_id = str(request_id)

            model = response_body.get("model")

            return {
                "content": content.strip(),
                "request_id": request_id,
                "model": model,
            }

        except (
            KeyError,
            TypeError,
            ValueError,
            requests.JSONDecodeError,
        ) as exc:
            raise AIInvalidResponseError() from exc

    @staticmethod
    def _build_http_error_message(
        status_code: int | None,
    ) -> str:
        if status_code is None:
            return "The AI provider request failed."

        return (
            "The AI provider request failed "
            f"with HTTP status {status_code}."
        )