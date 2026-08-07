from __future__ import annotations

from typing import Any

from django.db import transaction

from doctors.models import Specialty

from ..models import (
    ChatMessage,
    ChatSession,
    ConversationClinicalState,
)
from .ai.schemas import TriageResponse
from .chat_orchestrator import ChatOrchestrationResult
from .triage.red_flags.response_policy import (
    StructuredSafetyDecision,
)


CLINICAL_STATE_SCHEMA_VERSION = 1


@transaction.atomic
def persist_clinical_state(
    *,
    session: ChatSession,
    last_processed_message: ChatMessage,
    orchestration_result: ChatOrchestrationResult,
) -> ConversationClinicalState:
    """
    Persist the current validated clinical snapshot for one chat session.

    Only provider-independent triage data and sanitized backend safety
    metadata are persisted. Raw provider JSON and raw red-flag evidence
    must never cross this persistence boundary.
    """

    _validate_inputs(
        session=session,
        last_processed_message=last_processed_message,
        orchestration_result=orchestration_result,
    )

    locked_session = ChatSession.objects.select_for_update().get(
        pk=session.pk,
    )

    locked_message = ChatMessage.objects.select_for_update().get(
        pk=last_processed_message.pk,
        session=locked_session,
    )

    if locked_message.sender != ChatMessage.Sender.USER:
        raise ValueError(
            "last_processed_message must be a user message."
        )

    triage_response = orchestration_result.triage_response

    if triage_response is None:
        urgency = (
            orchestration_result.safety_decision.decision.value
        )
        suggested_specialty_code = ""
    else:
        urgency = triage_response.urgency
        suggested_specialty_code = (
            triage_response.suggested_specialty_code or ""
        )

    suggested_specialty = _resolve_specialty(
        suggested_specialty_code
    )

    try:
        clinical_state = (
            ConversationClinicalState.objects
            .select_for_update()
            .get(session=locked_session)
        )
    except ConversationClinicalState.DoesNotExist:
        clinical_state = ConversationClinicalState(
            session=locked_session,
        )

    clinical_state.last_processed_message = locked_message
    clinical_state.schema_version = CLINICAL_STATE_SCHEMA_VERSION
    clinical_state.structured_state = _build_structured_state(
        orchestration_result
    )
    clinical_state.urgency = urgency
    clinical_state.safety_decision = (
        orchestration_result.safety_decision.decision.value
    )
    clinical_state.execution_path = (
        orchestration_result.execution_path.value
    )
    clinical_state.suggested_specialty = suggested_specialty
    clinical_state.suggested_specialty_code = (
        suggested_specialty_code
    )

    clinical_state.full_clean()
    clinical_state.save()

    return clinical_state


def _validate_inputs(
    *,
    session: ChatSession,
    last_processed_message: ChatMessage,
    orchestration_result: ChatOrchestrationResult,
) -> None:
    if not isinstance(session, ChatSession):
        raise TypeError("session must be a ChatSession instance.")

    if not isinstance(last_processed_message, ChatMessage):
        raise TypeError(
            "last_processed_message must be a ChatMessage instance."
        )

    if not isinstance(
        orchestration_result,
        ChatOrchestrationResult,
    ):
        raise TypeError(
            "orchestration_result must be a "
            "ChatOrchestrationResult instance."
        )

    if session._state.adding:
        raise ValueError("session must be saved before persistence.")

    if last_processed_message._state.adding:
        raise ValueError(
            "last_processed_message must be saved before persistence."
        )

    if last_processed_message.session_id != session.pk:
        raise ValueError(
            "last_processed_message must belong to the supplied session."
        )

    if last_processed_message.sender != ChatMessage.Sender.USER:
        raise ValueError(
            "last_processed_message must be a user message."
        )


def _resolve_specialty(
    specialty_code: str,
) -> Specialty | None:
    """
    Resolve the specialty FK while preserving the code as a snapshot.

    Active-specialty validation belongs to orchestration. Persistence
    does not re-validate that decision because the specialty may have
    been deactivated between orchestration and database persistence.
    """

    if not specialty_code:
        return None

    return Specialty.objects.filter(
        code=specialty_code,
    ).first()


def _build_structured_state(
    orchestration_result: ChatOrchestrationResult,
) -> dict[str, Any]:
    return {
        "triage_response": _serialize_triage_response(
            orchestration_result.triage_response
        ),
        "safety": _serialize_safety_decision(
            orchestration_result.safety_decision
        ),
    }


def _serialize_triage_response(
    triage_response: TriageResponse | None,
) -> dict[str, Any] | None:
    if triage_response is None:
        return None

    return {
        "symptom_summary": list(
            triage_response.symptom_summary
        ),
        "follow_up_questions": list(
            triage_response.follow_up_questions
        ),
        "needs_more_information": (
            triage_response.needs_more_information
        ),
        "emergency_warning": (
            triage_response.emergency_warning
        ),
        "safety_disclaimer": (
            triage_response.safety_disclaimer
        ),
    }


def _serialize_safety_decision(
    safety_decision: StructuredSafetyDecision,
) -> dict[str, Any]:
    highest_urgency = safety_decision.highest_urgency

    return {
        "reasons": [
            {
                "rule_id": reason.rule_id,
                "rule_version": reason.rule_version,
                "urgency": reason.urgency.value,
                "warning_key": reason.warning_key,
            }
            for reason in safety_decision.reasons
        ],
        "highest_urgency": (
            highest_urgency.value
            if highest_urgency is not None
            else None
        ),
        "must_override_model": (
            safety_decision.must_override_model
        ),
        "should_short_circuit_llm": (
            safety_decision.should_short_circuit_llm
        ),
        "source_engine_version": (
            safety_decision.source_engine_version
        ),
        "policy_version": safety_decision.policy_version,
    }