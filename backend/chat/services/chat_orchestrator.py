from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from enum import Enum

from .triage.red_flags.response_policy import (
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
    Immutable result describing how one patient message should proceed.

    This public orchestration result contains only the sanitized safety
    decision. It must not contain raw red-flag evidence, matched patient
    text, or unvalidated AI provider output.
    """

    execution_path: ChatExecutionPath
    safety_decision: StructuredSafetyDecision

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

    @property
    def should_call_ai_provider(self) -> bool:
        """Return whether the message may proceed to an AI provider."""

        return self.execution_path == ChatExecutionPath.AI_PROVIDER


def orchestrate_chat(
    patient_text: str,
    *,
    safety_evaluator: SafetyEvaluator = evaluate_chat_safety,
) -> ChatOrchestrationResult:
    """
    Route one patient message through the deterministic safety boundary.

    Emergency decisions short-circuit the future AI provider path.
    Urgent and continue decisions may proceed to the AI provider later.

    This function does not call an AI provider, access the database,
    generate patient-facing text, or persist messages and sessions.
    """

    safety_decision = safety_evaluator(patient_text)

    execution_path = (
        ChatExecutionPath.BACKEND_SAFETY_RESPONSE
        if safety_decision.should_short_circuit_llm
        else ChatExecutionPath.AI_PROVIDER
    )

    return ChatOrchestrationResult(
        execution_path=execution_path,
        safety_decision=safety_decision,
    )
