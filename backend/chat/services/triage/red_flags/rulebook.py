from __future__ import annotations

from typing import Final

from .lexicon import CONCEPT_LEXICON
from .rules import (
    RedFlagEvidenceRequirement,
    RedFlagRule,
    RedFlagRuleRegistry,
)
from .schemas import AssertionStatus, RedFlagUrgency


_PRESENT_ONLY: Final[tuple[AssertionStatus, ...]] = (
    AssertionStatus.PRESENT,
)


LOSS_OF_CONSCIOUSNESS_PRESENT: Final[
    RedFlagEvidenceRequirement
] = RedFlagEvidenceRequirement(
    concept_code="loss_of_consciousness",
    accepted_assertion_statuses=_PRESENT_ONLY,
)


CHEST_PAIN_PRESENT: Final[
    RedFlagEvidenceRequirement
] = RedFlagEvidenceRequirement(
    concept_code="chest_pain",
    accepted_assertion_statuses=_PRESENT_ONLY,
)


SHORTNESS_OF_BREATH_PRESENT: Final[
    RedFlagEvidenceRequirement
] = RedFlagEvidenceRequirement(
    concept_code="shortness_of_breath",
    accepted_assertion_statuses=_PRESENT_ONLY,
)


LOSS_OF_CONSCIOUSNESS_EMERGENCY: Final[
    RedFlagRule
] = RedFlagRule(
    rule_id="loss_of_consciousness_emergency",
    version=1,
    required_evidence=(
        LOSS_OF_CONSCIOUSNESS_PRESENT,
    ),
    urgency=RedFlagUrgency.EMERGENCY,
    warning_key=(
        "red_flags.loss_of_consciousness_emergency"
    ),
)


CHEST_PAIN_WITH_SHORTNESS_OF_BREATH_EMERGENCY: Final[
    RedFlagRule
] = RedFlagRule(
    rule_id=(
        "chest_pain_with_shortness_of_breath_emergency"
    ),
    version=1,
    required_evidence=(
        CHEST_PAIN_PRESENT,
        SHORTNESS_OF_BREATH_PRESENT,
    ),
    urgency=RedFlagUrgency.EMERGENCY,
    warning_key=(
        "red_flags."
        "chest_pain_with_shortness_of_breath_emergency"
    ),
)


APPROVED_RED_FLAG_RULES: Final[
    tuple[RedFlagRule, ...]
] = (
    LOSS_OF_CONSCIOUSNESS_EMERGENCY,
    CHEST_PAIN_WITH_SHORTNESS_OF_BREATH_EMERGENCY,
)


RED_FLAG_RULE_REGISTRY: Final[
    RedFlagRuleRegistry
] = RedFlagRuleRegistry(
    rules=APPROVED_RED_FLAG_RULES,
    concept_registry=CONCEPT_LEXICON,
)