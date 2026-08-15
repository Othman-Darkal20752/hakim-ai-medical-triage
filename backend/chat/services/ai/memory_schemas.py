from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Literal

from .exceptions import AIInvalidResponseError


MemoryOperation = Literal[
    "add",
    "remove",
    "set",
]

MemoryField = Literal[
    "chronic_conditions",
    "allergies",
    "current_medications",
    "previous_surgeries",
    "smoking_status",
    "alcohol_use",
    "pregnancy_status",
]


LIST_MEMORY_FIELDS = frozenset(
    {
        "chronic_conditions",
        "allergies",
        "current_medications",
        "previous_surgeries",
    }
)

SCALAR_MEMORY_FIELD_VALUES = {
    "smoking_status": frozenset(
        {
            "never",
            "former",
            "current",
        }
    ),
    "alcohol_use": frozenset(
        {
            "never",
            "former",
            "current",
        }
    ),
    "pregnancy_status": frozenset(
        {
            "not_pregnant",
            "pregnant",
        }
    ),
}

_REQUIRED_RESPONSE_FIELDS = {
    "candidates",
}

_REQUIRED_CANDIDATE_FIELDS = {
    "field",
    "operation",
    "value",
}

_MAX_CANDIDATES = 8
_MAX_VALUE_LENGTH = 200


@dataclass(frozen=True, slots=True)
class MemoryCandidate:
    """
    One validated patient-reported clinical-memory candidate.

    A candidate is not confirmed medical information and must never be
    persisted automatically. It requires explicit patient confirmation
    before it may be passed to the confirmed clinical-memory service.
    """

    field: MemoryField
    operation: MemoryOperation
    value: str

    def to_dict(self) -> dict[str, str]:
        return {
            "field": self.field,
            "operation": self.operation,
            "value": self.value,
        }


@dataclass(frozen=True, slots=True)
class MemoryCandidateExtraction:
    """
    Validated result of one clinical-memory extraction request.

    This object contains candidate updates only. It does not represent
    confirmed or medically verified patient information.
    """

    candidates: tuple[MemoryCandidate, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "candidates": [
                candidate.to_dict()
                for candidate in self.candidates
            ],
        }


def parse_memory_candidate_extraction(
    raw_json: str,
) -> MemoryCandidateExtraction:
    """
    Parse and strictly validate AI-generated memory-candidate JSON.

    The parser accepts only the explicitly supported long-term health
    profile fields and operations. It does not infer facts, access the
    database, or confirm any candidate.

    Raises:
        AIInvalidResponseError:
            When the response is invalid JSON or violates the expected
            memory-candidate structure.
    """

    if not isinstance(raw_json, str) or not raw_json.strip():
        raise AIInvalidResponseError()

    try:
        payload = json.loads(raw_json)
    except (json.JSONDecodeError, TypeError) as exc:
        raise AIInvalidResponseError() from exc

    if not isinstance(payload, dict):
        raise AIInvalidResponseError()

    if set(payload.keys()) != _REQUIRED_RESPONSE_FIELDS:
        raise AIInvalidResponseError()

    raw_candidates = payload["candidates"]

    if not isinstance(raw_candidates, list):
        raise AIInvalidResponseError()

    if len(raw_candidates) > _MAX_CANDIDATES:
        raise AIInvalidResponseError()

    validated_candidates: list[MemoryCandidate] = []
    seen_candidates: set[tuple[str, str, str]] = set()

    for raw_candidate in raw_candidates:
        candidate = _parse_memory_candidate(raw_candidate)

        candidate_identity = (
            candidate.field,
            candidate.operation,
            (
                candidate.value.casefold()
                if candidate.field in LIST_MEMORY_FIELDS
                else candidate.value
            ),
        )

        if candidate_identity in seen_candidates:
            raise AIInvalidResponseError()

        seen_candidates.add(candidate_identity)
        validated_candidates.append(candidate)

    return MemoryCandidateExtraction(
        candidates=tuple(validated_candidates),
    )


def _parse_memory_candidate(
    value: Any,
) -> MemoryCandidate:
    if not isinstance(value, dict):
        raise AIInvalidResponseError()

    if set(value.keys()) != _REQUIRED_CANDIDATE_FIELDS:
        raise AIInvalidResponseError()

    field = _validate_required_string(
        value["field"],
        maximum_length=50,
    ).lower()

    operation = _validate_required_string(
        value["operation"],
        maximum_length=20,
    ).lower()

    candidate_value = _validate_required_string(
        value["value"],
        maximum_length=_MAX_VALUE_LENGTH,
    )

    if field in LIST_MEMORY_FIELDS:
        if operation not in {"add", "remove"}:
            raise AIInvalidResponseError()

        return MemoryCandidate(
            field=field,
            operation=operation,
            value=candidate_value,
        )

    if field in SCALAR_MEMORY_FIELD_VALUES:
        if operation != "set":
            raise AIInvalidResponseError()

        normalized_value = candidate_value.lower()

        if (
            normalized_value
            not in SCALAR_MEMORY_FIELD_VALUES[field]
        ):
            raise AIInvalidResponseError()

        return MemoryCandidate(
            field=field,
            operation=operation,
            value=normalized_value,
        )

    raise AIInvalidResponseError()


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
