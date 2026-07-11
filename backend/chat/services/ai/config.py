from dataclasses import dataclass

from django.conf import settings

from .exceptions import (
    AIConfigurationError,
    AIIntegrationDisabledError,
)


@dataclass(frozen=True)
class AIProviderConfig:
    """
    Validated provider-independent AI configuration.

    The API key must never be printed, logged, or returned through an API.
    """

    provider: str
    api_base_url: str
    api_key: str
    model: str
    timeout_seconds: int
    max_context_messages: int


def load_ai_provider_config() -> AIProviderConfig:
    """
    Load and validate AI settings before any external provider request.

    Raises:
        AIIntegrationDisabledError:
            When AI integration is disabled.

        AIConfigurationError:
            When required configuration is missing or invalid.
    """

    if not settings.AI_ENABLED:
        raise AIIntegrationDisabledError()

    provider = str(settings.AI_PROVIDER).strip().lower()
    api_base_url = str(settings.AI_API_BASE_URL).strip()
    api_key = str(settings.AI_API_KEY).strip()
    model = str(settings.AI_MODEL).strip()

    missing_settings: list[str] = []

    if not provider:
        missing_settings.append("AI_PROVIDER")

    if not api_base_url:
        missing_settings.append("AI_API_BASE_URL")

    if not api_key:
        missing_settings.append("AI_API_KEY")

    if not model:
        missing_settings.append("AI_MODEL")

    if missing_settings:
        missing = ", ".join(missing_settings)
        raise AIConfigurationError(
            f"Missing required AI settings: {missing}."
        )

    timeout_seconds = settings.AI_TIMEOUT_SECONDS
    max_context_messages = settings.AI_MAX_CONTEXT_MESSAGES

    if timeout_seconds <= 0:
        raise AIConfigurationError(
            "AI_TIMEOUT_SECONDS must be greater than zero."
        )

    if not 1 <= max_context_messages <= 50:
        raise AIConfigurationError(
            "AI_MAX_CONTEXT_MESSAGES must be between 1 and 50."
        )

    return AIProviderConfig(
        provider=provider,
        api_base_url=api_base_url,
        api_key=api_key,
        model=model,
        timeout_seconds=timeout_seconds,
        max_context_messages=max_context_messages,
    )