from __future__ import annotations

from collections.abc import Callable, Collection, Sequence
from dataclasses import dataclass, replace
from enum import Enum

from .ai.provider import AIMessage, AIProvider
from .ai.schemas import TriageResponse, parse_triage_response
from .triage.red_flags.response_policy import (
    SafetyDecisionType,
    StructuredSafetyDecision,
)
from .triage.safety_gate import evaluate_chat_safety


SafetyEvaluator = Callable[
    [str],
    StructuredSafetyDecision,
]


class ChatExecutionPath(str, Enum):
    """Backend-controlled execution paths for one patient message."""

    BACKEND_SAFETY_RESPONSE = "backend_safety_response"
    AI_PROVIDER = "ai_provider"


@dataclass(frozen=True, slots=True)
class ChatOrchestrationResult:
    """
    Immutable result describing how one patient message was processed.

    The result contains only the sanitized backend safety decision and,
    when the AI path was used, a validated provider-independent triage
    response.

    It must not contain raw red-flag evidence, matched patient text,
    AIProviderResult, or raw provider JSON.
    """

    execution_path: ChatExecutionPath
    safety_decision: StructuredSafetyDecision
    triage_response: TriageResponse | None

    def __post_init__(self) -> None:
        if not isinstance(
            self.execution_path,
            ChatExecutionPath,
        ):
            raise TypeError(
                "execution_path must be a ChatExecutionPath instance."
            )

        if not isinstance(
            self.safety_decision,
            StructuredSafetyDecision,
        ):
            raise TypeError(
                "safety_decision must be a "
                "StructuredSafetyDecision instance."
            )

        if (
            self.triage_response is not None
            and not isinstance(
                self.triage_response,
                TriageResponse,
            )
        ):
            raise TypeError(
                "triage_response must be a "
                "TriageResponse instance or None."
            )

        expected_execution_path = (
            ChatExecutionPath.BACKEND_SAFETY_RESPONSE
            if self.safety_decision.should_short_circuit_llm
            else ChatExecutionPath.AI_PROVIDER
        )

        if self.execution_path != expected_execution_path:
            raise ValueError(
                "execution_path is inconsistent with "
                "safety_decision.should_short_circuit_llm."
            )

        if (
            self.execution_path
            == ChatExecutionPath.BACKEND_SAFETY_RESPONSE
            and self.triage_response is not None
        ):
            raise ValueError(
                "triage_response must be None for the "
                "backend safety response path."
            )

        if (
            self.execution_path
            == ChatExecutionPath.AI_PROVIDER
            and self.triage_response is None
        ):
            raise ValueError(
                "triage_response is required for the "
                "AI provider execution path."
            )

    @property
    def should_call_ai_provider(self) -> bool:
        """Return whether this result used the AI-provider path."""

        return self.execution_path == ChatExecutionPath.AI_PROVIDER


def orchestrate_chat(
    patient_text: str,
    *,
    ai_provider: AIProvider,
    ai_messages: Sequence[AIMessage],
    allowed_specialty_codes: Collection[str],
    safety_evaluator: SafetyEvaluator = evaluate_chat_safety,
) -> ChatOrchestrationResult:
    """
    Process one patient message through the deterministic safety boundary.

    Emergency decisions are controlled entirely by the backend and
    short-circuit the AI provider.

    Urgent and continue decisions proceed to the injected AI provider.
    The provider JSON is strictly validated by parse_triage_response()
    before it can become part of the orchestration result.

    For urgent backend decisions, the final validated model urgency may
    not be lower than "urgent". A model-provided "emergency" urgency is
    never reduced.

    This function does not access the database, persist conversations,
    build patient-facing text, or expose raw provider JSON.
    """

    safety_decision = safety_evaluator(patient_text)

    if safety_decision.should_short_circuit_llm:
        return ChatOrchestrationResult(
            execution_path=(
                ChatExecutionPath.BACKEND_SAFETY_RESPONSE
            ),
            safety_decision=safety_decision,
            triage_response=None,
        )

    provider_result = ai_provider.generate_structured(
        messages=ai_messages,
    )

    triage_response = parse_triage_response(
        provider_result.raw_json,
        allowed_specialty_codes=allowed_specialty_codes,
    )

    final_triage_response = _apply_urgency_floor(
        triage_response=triage_response,
        safety_decision=safety_decision,
    )

    return ChatOrchestrationResult(
        execution_path=ChatExecutionPath.AI_PROVIDER,
        safety_decision=safety_decision,
        triage_response=final_triage_response,
    )


def _apply_urgency_floor(
    *,
    triage_response: TriageResponse,
    safety_decision: StructuredSafetyDecision,
) -> TriageResponse:
    """
    Apply the authoritative backend urgency floor after AI validation.

    An urgent backend decision upgrades model values "routine" and
    "soon" to "urgent". Existing "urgent" and "emergency" values are
    preserved.
    """

    if (
        safety_decision.decision == SafetyDecisionType.URGENT
        and triage_response.urgency in {"routine", "soon"}
    ):
        return replace(
            triage_response,
            urgency="urgent",
        )

    return triage_response
