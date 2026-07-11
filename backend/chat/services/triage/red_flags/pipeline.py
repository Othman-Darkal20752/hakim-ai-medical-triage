from __future__ import annotations

from .assertion import detect_assertions
from .evaluation import evaluate_red_flag_rules
from .matching import match_medical_concepts
from .rules import RedFlagRuleRegistry
from .schemas import RedFlagCheckResult


def check_red_flags(
    patient_text: str,
    *,
    rule_registry: RedFlagRuleRegistry,
) -> RedFlagCheckResult:
    """
    Run the deterministic backend-controlled red-flag pipeline.

    Pipeline:
    patient text
    -> normalization and medical concept matching
    -> assertion detection
    -> red-flag rule evaluation
    -> structured RedFlagCheckResult

    The rule registry's concept lexicon is used for matching so that rule
    validation and runtime concept matching always use the same registry.
    This function does not call an LLM, access the database, or perform
    specialty recommendation.
    """
    if not isinstance(patient_text, str):
        raise TypeError("patient_text must be a string.")

    if not isinstance(rule_registry, RedFlagRuleRegistry):
        raise TypeError(
            "rule_registry must be a RedFlagRuleRegistry instance."
        )

    concept_match_result = match_medical_concepts(
        patient_text,
        lexicon=rule_registry.concept_registry,
    )

    assertion_result = detect_assertions(
        concept_match_result,
    )

    return evaluate_red_flag_rules(
        assertion_result=assertion_result,
        rule_registry=rule_registry,
    )