from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Final


RED_FLAG_ENGINE_VERSION: Final[str] = "hakim-red-flags-v1"


class RedFlagUrgency(str, Enum):
    """Urgency levels that can be enforced by the Red Flag Engine."""

    URGENT = "urgent"
    EMERGENCY = "emergency"


class AssertionStatus(str, Enum):
    """Describes how a detected medical concept is asserted in the text."""

    PRESENT = "present"
    NEGATED = "negated"
    UNCERTAIN = "uncertain"
    HISTORICAL = "historical"
    HYPOTHETICAL = "hypothetical"
    OTHER_PERSON = "other_person"


class DetectedLanguage(str, Enum):
    """Language detected in the text evaluated by the engine."""

    ARABIC = "ar"
    ENGLISH = "en"
    MIXED = "mixed"
    UNKNOWN = "unknown"


@dataclass(frozen=True, slots=True)
class RedFlagEvidence:
    """
    A medical concept occurrence used as evidence for a matched rule.

    Character offsets refer to the text representation evaluated by the
    engine. Evidence text must not be written to production logs.
    """

    concept_code: str
    matched_text: str
    assertion: AssertionStatus
    start_char: int
    end_char: int
    segment_index: int

    def __post_init__(self) -> None:
        if not self.concept_code.strip():
            raise ValueError("concept_code must not be empty.")

        if not self.matched_text.strip():
            raise ValueError("matched_text must not be empty.")

        if self.start_char < 0:
            raise ValueError("start_char must be greater than or equal to zero.")

        if self.end_char <= self.start_char:
            raise ValueError("end_char must be greater than start_char.")

        if self.segment_index < 0:
            raise ValueError(
                "segment_index must be greater than or equal to zero."
            )


@dataclass(frozen=True, slots=True)
class RedFlagMatch:
    """A single medical red-flag rule matched by the engine."""

    rule_id: str
    rule_version: int
    urgency: RedFlagUrgency
    warning_key: str
    evidence: tuple[RedFlagEvidence, ...]

    def __post_init__(self) -> None:
        if not self.rule_id.strip():
            raise ValueError("rule_id must not be empty.")

        if self.rule_version < 1:
            raise ValueError("rule_version must be greater than or equal to 1.")

        if not self.warning_key.strip():
            raise ValueError("warning_key must not be empty.")

        if not self.evidence:
            raise ValueError("A red-flag match must contain evidence.")


@dataclass(frozen=True, slots=True)
class RedFlagCheckResult:
    """Structured result returned after evaluating red-flag rules."""

    language: DetectedLanguage
    matches: tuple[RedFlagMatch, ...] = ()
    engine_version: str = RED_FLAG_ENGINE_VERSION

    def __post_init__(self) -> None:
        if not self.engine_version.strip():
            raise ValueError("engine_version must not be empty.")

    @property
    def matched(self) -> bool:
        return bool(self.matches)

    @property
    def highest_urgency(self) -> RedFlagUrgency | None:
        if any(
            match.urgency == RedFlagUrgency.EMERGENCY
            for match in self.matches
        ):
            return RedFlagUrgency.EMERGENCY

        if any(
            match.urgency == RedFlagUrgency.URGENT
            for match in self.matches
        ):
            return RedFlagUrgency.URGENT

        return None

    @property
    def must_override_model(self) -> bool:
        """
        A matched backend rule establishes an urgency floor that the LLM
        must never downgrade.
        """

        return self.matched

    @property
    def should_short_circuit_llm(self) -> bool:
        """
        Emergency rules should return a fixed backend-controlled warning
        without depending on the language model response.
        """

        return self.highest_urgency == RedFlagUrgency.EMERGENCY