from __future__ import annotations

from .chat_orchestrator import (
    ChatExecutionPath,
    ChatOrchestrationResult,
)


_SUPPORTED_LANGUAGES = {"ar", "en"}

_BACKEND_EMERGENCY_REPLIES = {
    "en": (
        "The symptoms you reported may indicate a medical emergency. "
        "Seek immediate emergency medical care now and do not wait for "
        "further chat responses. "
        "This is preliminary medical guidance and not a final diagnosis."
    ),
    "ar": (
        "قد تشير الأعراض التي ذكرتها إلى حالة طبية طارئة. "
        "اطلب الرعاية الطبية الإسعافية فورًا ولا تنتظر ردودًا إضافية "
        "في المحادثة. "
        "هذا إرشاد طبي أولي ولا يُعد تشخيصًا نهائيًا."
    ),
}


def build_patient_reply(
    *,
    orchestration_result: ChatOrchestrationResult,
    response_language: str,
    specialty_name: str | None = None,
) -> str:
    """
    Build patient-facing text from one validated orchestration result.

    Backend emergency responses are fully controlled by the backend.
    AI-provider responses use only validated TriageResponse fields.

    Internal rule identifiers, warning keys, execution paths, and
    specialty codes must never be exposed through this function.
    """
    if not isinstance(
        orchestration_result,
        ChatOrchestrationResult,
    ):
        raise TypeError(
            "orchestration_result must be a "
            "ChatOrchestrationResult instance."
        )

    language = _validate_response_language(response_language)

    if (
        orchestration_result.execution_path
        == ChatExecutionPath.BACKEND_SAFETY_RESPONSE
    ):
        return _BACKEND_EMERGENCY_REPLIES[language]

    triage_response = orchestration_result.triage_response

    if triage_response is None:
        raise ValueError(
            "triage_response is required for the AI provider path."
        )

    sections: list[str] = []

    sections.extend(triage_response.symptom_summary)

    if triage_response.urgency == "emergency":
        if triage_response.emergency_warning is not None:
            sections.append(triage_response.emergency_warning)
    else:
        sections.extend(triage_response.follow_up_questions)

        normalized_specialty_name = _normalize_optional_text(
            specialty_name
        )
        if normalized_specialty_name is not None:
            sections.append(
                _format_specialty(
                    specialty_name=normalized_specialty_name,
                    language=language,
                )
            )

    sections.append(triage_response.safety_disclaimer)

    return "\n\n".join(sections)


def _validate_response_language(response_language: str) -> str:
    if not isinstance(response_language, str):
        raise TypeError("response_language must be a string.")

    language = response_language.strip().lower()

    if language not in _SUPPORTED_LANGUAGES:
        raise ValueError(
            "response_language must be either 'ar' or 'en'."
        )

    return language


def _normalize_optional_text(value: str | None) -> str | None:
    if value is None:
        return None

    if not isinstance(value, str):
        raise TypeError("specialty_name must be a string or None.")

    normalized_value = value.strip()

    return normalized_value or None


def _format_specialty(
    *,
    specialty_name: str,
    language: str,
) -> str:
    if language == "ar":
        return f"الاختصاص الطبي المقترح: {specialty_name}"

    return f"Suggested medical specialty: {specialty_name}"