class AIServiceError(Exception):
    """
    Base exception for provider-independent AI integration errors.

    User-facing API responses must not expose the original provider
    exception or sensitive configuration details.
    """

    code = "ai_service_error"
    retryable = False
    default_message = "The AI service could not complete the request."

    def __init__(self, message: str | None = None) -> None:
        super().__init__(message or self.default_message)


class AIIntegrationDisabledError(AIServiceError):
    code = "ai_integration_disabled"
    default_message = "The AI integration is currently disabled."


class AIConfigurationError(AIServiceError):
    code = "ai_configuration_error"
    default_message = "The AI provider configuration is incomplete or invalid."


class AIProviderTimeoutError(AIServiceError):
    code = "ai_provider_timeout"
    retryable = True
    default_message = "The AI provider request timed out."


class AIProviderConnectionError(AIServiceError):
    code = "ai_provider_connection_error"
    retryable = True
    default_message = "The AI provider could not be reached."


class AIInvalidResponseError(AIServiceError):
    code = "ai_invalid_response"
    default_message = "The AI provider returned an invalid response."