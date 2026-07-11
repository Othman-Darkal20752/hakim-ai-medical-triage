from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional, Sequence


@dataclass(frozen=True)
class AIMessage:
    """
    A provider-independent chat message.

    Allowed roles will be validated later by the prompt/orchestrator layer.
    """

    role: str
    content: str


@dataclass(frozen=True)
class AIProviderResult:
    """
    Raw structured response returned by an AI provider.

    The raw_json value must still be validated before it is treated
    as a medical triage result.
    """

    provider: str
    model: str
    raw_json: str
    request_id: Optional[str] = None


class AIProvider(ABC):
    """
    Common contract for all external AI providers.

    Implementations must not access Flutter tokens, user credentials,
    or database models directly.
    """

    @abstractmethod
    def generate_structured(
        self,
        *,
        messages: Sequence[AIMessage],
    ) -> AIProviderResult:
        """
        Generate a structured JSON response from the supplied messages.

        Raises:
            AI provider-specific exceptions that will later be converted
            into safe application errors by the orchestrator.
        """

        raise NotImplementedError