from __future__ import annotations

from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone

from patients.models import PatientHealthProfile


_MAX_LIST_ITEMS = 50
_MAX_ITEM_LENGTH = 200

_LIST_FIELDS = frozenset(
    {
        "chronic_conditions",
        "allergies",
        "current_medications",
        "previous_surgeries",
    }
)

_SCALAR_FIELD_CHOICES = {
    "smoking_status": frozenset(
        value
        for value, _label
        in PatientHealthProfile.SmokingStatus.choices
    ),
    "alcohol_use": frozenset(
        value
        for value, _label
        in PatientHealthProfile.AlcoholUse.choices
    ),
    "pregnancy_status": frozenset(
        value
        for value, _label
        in PatientHealthProfile.PregnancyStatus.choices
    ),
}


class ClinicalMemoryValidationError(ValueError):
    """Raised when a confirmed clinical-memory update is invalid."""


@transaction.atomic
def apply_confirmed_clinical_memory_update(
    *,
    user,
    field_name: str,
    operation: str,
    value: str,
) -> PatientHealthProfile:
    """
    Apply one patient-confirmed update to the long-term health profile.

    This service accepts only explicitly supported health-profile fields
    and operations. It does not infer facts and must never be called as
    an automatic consequence of an AI-generated clinical inference.
    """

    _validate_user(user)

    normalized_field = _validate_field_name(field_name)
    normalized_operation = _validate_operation(operation)

    profile = (
        PatientHealthProfile.objects
        .select_for_update()
        .filter(user_id=user.pk)
        .first()
    )

    if profile is None:
        profile = PatientHealthProfile.objects.create(
            user=user,
        )

    if normalized_field in _LIST_FIELDS:
        _apply_list_field_update(
            profile=profile,
            field_name=normalized_field,
            operation=normalized_operation,
            value=value,
        )
    else:
        _apply_scalar_field_update(
            profile=profile,
            field_name=normalized_field,
            operation=normalized_operation,
            value=value,
        )

    profile.last_reviewed_at = timezone.now()
    profile.save(
        update_fields=[
            normalized_field,
            "last_reviewed_at",
            "updated_at",
        ]
    )

    return profile


def _validate_user(user) -> None:
    user_model = get_user_model()

    if not isinstance(user, user_model):
        raise TypeError(
            "user must be an instance of the configured user model."
        )

    if user._state.adding or user.pk is None:
        raise ValueError(
            "user must be saved before updating clinical memory."
        )


def _validate_field_name(field_name: str) -> str:
    if not isinstance(field_name, str):
        raise TypeError("field_name must be a string.")

    normalized_field = field_name.strip()

    allowed_fields = _LIST_FIELDS.union(
        _SCALAR_FIELD_CHOICES.keys()
    )

    if normalized_field not in allowed_fields:
        raise ClinicalMemoryValidationError(
            "Unsupported clinical-memory field."
        )

    return normalized_field


def _validate_operation(operation: str) -> str:
    if not isinstance(operation, str):
        raise TypeError("operation must be a string.")

    normalized_operation = operation.strip().lower()

    if normalized_operation not in {
        "add",
        "remove",
        "set",
    }:
        raise ClinicalMemoryValidationError(
            "Unsupported clinical-memory operation."
        )

    return normalized_operation


def _normalize_text_value(value: str) -> str:
    if not isinstance(value, str):
        raise TypeError("value must be a string.")

    normalized_value = value.strip()

    if not normalized_value:
        raise ClinicalMemoryValidationError(
            "Clinical-memory value cannot be blank."
        )

    if len(normalized_value) > _MAX_ITEM_LENGTH:
        raise ClinicalMemoryValidationError(
            "Clinical-memory value cannot exceed 200 characters."
        )

    return normalized_value


def _apply_list_field_update(
    *,
    profile: PatientHealthProfile,
    field_name: str,
    operation: str,
    value: str,
) -> None:
    if operation not in {"add", "remove"}:
        raise ClinicalMemoryValidationError(
            "List clinical-memory fields support only add or remove."
        )

    normalized_value = _normalize_text_value(value)

    current_values = getattr(profile, field_name)

    if not isinstance(current_values, list):
        raise ClinicalMemoryValidationError(
            "Stored clinical-memory list data is invalid."
        )

    if any(
        not isinstance(item, str)
        for item in current_values
    ):
        raise ClinicalMemoryValidationError(
            "Stored clinical-memory list data is invalid."
        )

    target_key = normalized_value.casefold()

    matching_indexes = [
        index
        for index, item in enumerate(current_values)
        if item.strip().casefold() == target_key
    ]

    if operation == "add":
        if matching_indexes:
            return

        if len(current_values) >= _MAX_LIST_ITEMS:
            raise ClinicalMemoryValidationError(
                "Clinical-memory list cannot contain more than 50 items."
            )

        setattr(
            profile,
            field_name,
            [
                *current_values,
                normalized_value,
            ],
        )
        return

    setattr(
        profile,
        field_name,
        [
            item
            for item in current_values
            if item.strip().casefold() != target_key
        ],
    )


def _apply_scalar_field_update(
    *,
    profile: PatientHealthProfile,
    field_name: str,
    operation: str,
    value: str,
) -> None:
    if operation != "set":
        raise ClinicalMemoryValidationError(
            "Scalar clinical-memory fields support only set."
        )

    normalized_value = _normalize_text_value(
        value
    ).lower()

    if normalized_value not in _SCALAR_FIELD_CHOICES[field_name]:
        raise ClinicalMemoryValidationError(
            "Invalid value for clinical-memory field."
        )

    setattr(
        profile,
        field_name,
        normalized_value,
    )