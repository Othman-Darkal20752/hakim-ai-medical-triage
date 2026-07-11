from __future__ import annotations

from .red_flags.pipeline import check_red_flags
from .red_flags.response_policy import (
    StructuredSafetyDecision,
    apply_response_policy,
)
from .red_flags.rulebook import RED_FLAG_RULE_REGISTRY
from .red_flags.rules import RedFlagRuleRegistry


def evaluate_chat_safety(
    patient_text: str,
    *,
    rule_registry: RedFlagRuleRegistry = RED_FLAG_RULE_REGISTRY,
) -> StructuredSafetyDecision:
    """
    Evaluate patient text through the deterministic chat safety gate.

    Flow:
    patient text
    -> backend-controlled red-flag detection
    -> deterministic response policy
    -> sanitized StructuredSafetyDecision

    The returned decision does not expose matched patient text or raw
    red-flag evidence. This function does not call an LLM, access the
    database, or perform specialty recommendation.
    """
    red_flag_result = check_red_flags(
        patient_text,
        rule_registry=rule_registry,
    )

    return apply_response_policy(red_flag_result)
