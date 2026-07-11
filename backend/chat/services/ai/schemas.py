import json
from collections.abc import Collection
from dataclasses import dataclass
from typing import Any, Literal

from .exceptions import AIInvalidResponseError


TriageUrgency = Literal[
    "routine",
    "soon",
    "urgent",
    "emergency",
]

_ALLOWED_URGENCY_VALUES = {
    "routine",
    "soon",
    "urgent",
    "emergency",
}

_REQUIRED_FIELDS = {
    "symptom_summary",
    "follow_up_questions",
    "urgency",
    "suggested_specialty_code",
    "needs_more_information",
    "emergency_warning",
    "safety_disclaimer",
}

_MAX_SUMMARY_ITEMS = 8
_MAX_FOLLOW_UP_QUESTIONS = 4
_MAX_ITEM_LENGTH = 500
_MAX_DISCLAIMER_LENGTH = 800


@dataclass(frozen=True)
class TriageResponse:
    """
    Validated and provider-independent medical triage response.

    This object represents preliminary guidance only and must still pass
    server-side red-flag and response-safety rules.
    """

    symptom_summary: tuple[str, ...]
    follow_up_questions: tuple[str, ...]
    urgency: TriageUrgency
    suggested_specialty_code: str | None
    needs_more_information: bool
    emergency_warning: str | None
    safety_disclaimer: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "symptom_summary": list(self.symptom_summary),
            "follow_up_questions": list(self.follow_up_questions),
            "urgency": self.urgency,
            "suggested_specialty_code": self.suggested_specialty_code,
            "needs_more_information": self.needs_more_information,
            "emergency_warning": self.emergency_warning,
            "safety_disclaimer": self.safety_disclaimer,
        }


def parse_triage_response(
    raw_json: str,
    *,
    allowed_specialty_codes: Collection[str],
) -> TriageResponse:
    """
    Parse and strictly validate an AI-generated triage JSON response.

    Raises:
        AIInvalidResponseError:
            When the response is not valid JSON or violates the expected
            medical triage response structure.
    """

    if not isinstance(raw_json, str) or not raw_json.strip():
        raise AIInvalidResponseError()

    try:
        payload = json.loads(raw_json)
    except (json.JSONDecodeError, TypeError) as exc:
        raise AIInvalidResponseError() from exc

    if not isinstance(payload, dict):
        raise AIInvalidResponseError()

    if set(payload.keys()) != _REQUIRED_FIELDS:
        raise AIInvalidResponseError()

    symptom_summary = _validate_string_list(
        payload["symptom_summary"],
        minimum_items=1,
        maximum_items=_MAX_SUMMARY_ITEMS,
    )

    follow_up_questions = _validate_string_list(
        payload["follow_up_questions"],
        minimum_items=0,
        maximum_items=_MAX_FOLLOW_UP_QUESTIONS,
    )

    urgency = payload["urgency"]

    if not isinstance(urgency, str):
        raise AIInvalidResponseError()

    urgency = urgency.strip().lower()

    if urgency not in _ALLOWED_URGENCY_VALUES:
        raise AIInvalidResponseError()

    needs_more_information = payload["needs_more_information"]

    if type(needs_more_information) is not bool:
        raise AIInvalidResponseError()

    suggested_specialty_code = _validate_specialty_code(
        payload["suggested_specialty_code"],
        allowed_specialty_codes=allowed_specialty_codes,
    )

    emergency_warning = _validate_optional_string(
        payload["emergency_warning"],
        maximum_length=_MAX_ITEM_LENGTH,
    )

    safety_disclaimer = _validate_required_string(
        payload["safety_disclaimer"],
        maximum_length=_MAX_DISCLAIMER_LENGTH,
    )

    if needs_more_information and suggested_specialty_code is not None:
        raise AIInvalidResponseError()

    if urgency == "emergency":
        if emergency_warning is None:
            raise AIInvalidResponseError()

        if follow_up_questions:
            raise AIInvalidResponseError()
    elif emergency_warning is not None:
        raise AIInvalidResponseError()

    return TriageResponse(
        symptom_summary=symptom_summary,
        follow_up_questions=follow_up_questions,
        urgency=urgency,
        suggested_specialty_code=suggested_specialty_code,
        needs_more_information=needs_more_information,
        emergency_warning=emergency_warning,
        safety_disclaimer=safety_disclaimer,
    )


def _validate_string_list(
    value: Any,
    *,
    minimum_items: int,
    maximum_items: int,
) -> tuple[str, ...]:
    if not isinstance(value, list):
        raise AIInvalidResponseError()

    if not minimum_items <= len(value) <= maximum_items:
        raise AIInvalidResponseError()

    validated_items: list[str] = []

    for item in value:
        validated_items.append(
            _validate_required_string(
                item,
                maximum_length=_MAX_ITEM_LENGTH,
            )
        )

    return tuple(validated_items)


def _validate_required_string(
    value: Any,
    *,
    maximum_length: int,
) -> str:
    if not isinstance(value, str):
        raise AIInvalidResponseError()

    normalized_value = value.strip()

    if not normalized_value:
        raise AIInvalidResponseError()

    if len(normalized_value) > maximum_length:
        raise AIInvalidResponseError()

    return normalized_value


def _validate_optional_string(
    value: Any,
    *,
    maximum_length: int,
) -> str | None:
    if value is None:
        return None

    return _validate_required_string(
        value,
        maximum_length=maximum_length,
    )


def _validate_specialty_code(
    value: Any,
    *,
    allowed_specialty_codes: Collection[str],
) -> str | None:
    if value is None:
        return None

    if not isinstance(value, str):
        raise AIInvalidResponseError()

    normalized_value = value.strip().lower()

    if not normalized_value:
        raise AIInvalidResponseError()

    normalized_allowed_codes = {
        str(code).strip().lower()
        for code in allowed_specialty_codes
        if str(code).strip()
    }

    if normalized_value not in normalized_allowed_codes:
        raise AIInvalidResponseError()

    return normalized_value