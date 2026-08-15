from __future__ import annotations

from .ai.exceptions import AIServiceError
from .ai.memory_prompt import build_memory_candidate_prompt
from .ai.memory_schemas import (
    MemoryCandidateExtraction,
    parse_memory_candidate_extraction,
)
from .ai.provider import AIMessage, AIProvider


def extract_memory_candidates(
    *,
    ai_provider: AIProvider,
    current_patient_message: str,
    previous_assistant_message: str | None = None,
) -> MemoryCandidateExtraction | None:
    """
    Extract unconfirmed long-term clinical-memory candidates.

    Only expected AI integration failures are handled fail-soft by
    returning None. Programming errors and invalid caller usage remain
    visible to the application and test layers.

    This service never persists clinical memory.
    """

    patient_message = _validate_required_message(
        current_patient_message,
        field_name="current_patient_message",
    )

    assistant_message = _validate_optional_message(
        previous_assistant_message,
        field_name="previous_assistant_message",
    )

    messages = [
        AIMessage(
            role="system",
            content=build_memory_candidate_prompt(),
        ),
    ]

    if assistant_message is not None:
        messages.append(
            AIMessage(
                role="assistant",
                content=assistant_message,
            )
        )

    messages.append(
        AIMessage(
            role="user",
            content=patient_message,
        )
    )

    try:
        provider_result = ai_provider.generate_structured(
            messages=tuple(messages),
        )

        return parse_memory_candidate_extraction(
            provider_result.raw_json,
        )
    except AIServiceError:
        return None


def _validate_required_message(
    value: str,
    *,
    field_name: str,
) -> str:
    if not isinstance(value, str):
        raise TypeError(
            f"{field_name} must be a string."
        )

    normalized_value = value.strip()

    if not normalized_value:
        raise ValueError(
            f"{field_name} must not be blank."
        )

    return normalized_value


def _validate_optional_message(
    value: str | None,
    *,
    field_name: str,
) -> str | None:
    if value is None:
        return None

    return _validate_required_message(
        value,
        field_name=field_name,
    )
