from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Final

from .schemas import (
    DetectedLanguage,
    RedFlagCheckResult,
    RedFlagMatch,
    RedFlagUrgency,
)


RESPONSE_POLICY_VERSION: Final[str] = "hakim-response-policy-v1"


class SafetyDecisionType(str, Enum):
    """Backend-controlled decisions produced by the response policy."""

    CONTINUE = "continue"
    URGENT = "urgent"
    EMERGENCY = "emergency"


@dataclass(frozen=True, slots=True)
class SafetyDecisionReason:
    """A non-sensitive reference to one rule that influenced the decision."""

    rule_id: str
    rule_version: int
    urgency: RedFlagUrgency
    warning_key: str

    def __post_init__(self) -> None:
        if not isinstance(self.rule_id, str):
            raise TypeError("rule_id must be a string.")

        if not self.rule_id.strip():
            raise ValueError("rule_id must not be empty.")

        if (
            isinstance(self.rule_version, bool)
            or not isinstance(self.rule_version, int)
        ):
            raise TypeError("rule_version must be an integer.")

        if self.rule_version < 1:
            raise ValueError(
                "rule_version must be greater than or equal to 1."
            )

        if not isinstance(self.urgency, RedFlagUrgency):
            raise TypeError(
                "urgency must be a RedFlagUrgency instance."
            )

        if not isinstance(self.warning_key, str):
            raise TypeError("warning_key must be a string.")

        if not self.warning_key.strip():
            raise ValueError("warning_key must not be empty.")


def _urgency_sort_priority(
    urgency: RedFlagUrgency,
) -> int:
    """Return deterministic priority, with emergency reasons first."""
    if urgency == RedFlagUrgency.EMERGENCY:
        return 0

    if urgency == RedFlagUrgency.URGENT:
        return 1

    raise ValueError("Unsupported red-flag urgency.")


def _reason_sort_key(
    reason: SafetyDecisionReason,
) -> tuple[int, str, int, str]:
    """Return the canonical deterministic ordering key."""
    return (
        _urgency_sort_priority(reason.urgency),
        reason.rule_id,
        reason.rule_version,
        reason.warning_key,
    )


def _highest_urgency_from_reasons(
    reasons: tuple[SafetyDecisionReason, ...],
) -> RedFlagUrgency | None:
    if any(
        reason.urgency == RedFlagUrgency.EMERGENCY
        for reason in reasons
    ):
        return RedFlagUrgency.EMERGENCY

    if any(
        reason.urgency == RedFlagUrgency.URGENT
        for reason in reasons
    ):
        return RedFlagUrgency.URGENT

    return None


def _decision_for_urgency(
    highest_urgency: RedFlagUrgency | None,
) -> SafetyDecisionType:
    if highest_urgency == RedFlagUrgency.EMERGENCY:
        return SafetyDecisionType.EMERGENCY

    if highest_urgency == RedFlagUrgency.URGENT:
        return SafetyDecisionType.URGENT

    if highest_urgency is None:
        return SafetyDecisionType.CONTINUE

    raise ValueError("Unsupported highest urgency.")


@dataclass(frozen=True, slots=True)
class StructuredSafetyDecision:
    """
    Immutable response-policy decision consumed by future chat orchestration.

    The object contains localization keys and rule identifiers only. It does
    not expose matched patient text or raw medical evidence.
    """

    decision: SafetyDecisionType
    reasons: tuple[SafetyDecisionReason, ...]
    highest_urgency: RedFlagUrgency | None
    must_override_model: bool
    should_short_circuit_llm: bool
    source_engine_version: str
    policy_version: str = RESPONSE_POLICY_VERSION

    def __post_init__(self) -> None:
        if not isinstance(self.decision, SafetyDecisionType):
            raise TypeError(
                "decision must be a SafetyDecisionType instance."
            )

        if not isinstance(self.reasons, tuple):
            raise TypeError("reasons must be a tuple.")

        for reason in self.reasons:
            if not isinstance(reason, SafetyDecisionReason):
                raise TypeError(
                    "every reason must be a "
                    "SafetyDecisionReason instance."
                )

        canonical_reasons = tuple(
            sorted(
                self.reasons,
                key=_reason_sort_key,
            )
        )

        if self.reasons != canonical_reasons:
            raise ValueError(
                "reasons must use the canonical deterministic ordering."
            )

        reason_identities = {
            (
                reason.rule_id,
                reason.rule_version,
            )
            for reason in self.reasons
        }

        if len(reason_identities) != len(self.reasons):
            raise ValueError(
                "duplicate rule identities are not allowed."
            )

        if (
            self.highest_urgency is not None
            and not isinstance(
                self.highest_urgency,
                RedFlagUrgency,
            )
        ):
            raise TypeError(
                "highest_urgency must be a RedFlagUrgency "
                "instance or None."
            )

        if type(self.must_override_model) is not bool:
            raise TypeError(
                "must_override_model must be a boolean."
            )

        if type(self.should_short_circuit_llm) is not bool:
            raise TypeError(
                "should_short_circuit_llm must be a boolean."
            )

        if not isinstance(self.source_engine_version, str):
            raise TypeError(
                "source_engine_version must be a string."
            )

        if not self.source_engine_version.strip():
            raise ValueError(
                "source_engine_version must not be empty."
            )

        if not isinstance(self.policy_version, str):
            raise TypeError("policy_version must be a string.")

        if not self.policy_version.strip():
            raise ValueError("policy_version must not be empty.")

        expected_highest_urgency = _highest_urgency_from_reasons(
            self.reasons
        )
        expected_override = bool(self.reasons)
        expected_short_circuit = (
            expected_highest_urgency
            == RedFlagUrgency.EMERGENCY
        )
        expected_decision = _decision_for_urgency(
            expected_highest_urgency
        )

        if self.highest_urgency != expected_highest_urgency:
            raise ValueError(
                "highest_urgency is inconsistent with reasons."
            )

        if self.must_override_model != expected_override:
            raise ValueError(
                "must_override_model is inconsistent with reasons."
            )

        if (
            self.should_short_circuit_llm
            != expected_short_circuit
        ):
            raise ValueError(
                "should_short_circuit_llm is inconsistent "
                "with highest_urgency."
            )

        if self.decision != expected_decision:
            raise ValueError(
                "decision is inconsistent with highest_urgency."
            )

    @property
    def warning_keys(self) -> tuple[str, ...]:
        """Return localization keys in canonical decision order."""
        return tuple(
            reason.warning_key
            for reason in self.reasons
        )

    @property
    def primary_warning_key(self) -> str | None:
        """Return the highest-priority localization key, if present."""
        if not self.reasons:
            return None

        return self.reasons[0].warning_key


def _validate_red_flag_result(
    red_flag_result: RedFlagCheckResult,
) -> None:
    """Validate the response-policy input boundary."""
    if not isinstance(red_flag_result, RedFlagCheckResult):
        raise TypeError(
            "red_flag_result must be a RedFlagCheckResult instance."
        )

    if not isinstance(red_flag_result.language, DetectedLanguage):
        raise TypeError(
            "red_flag_result.language must be a "
            "DetectedLanguage instance."
        )

    if not isinstance(red_flag_result.engine_version, str):
        raise TypeError(
            "red_flag_result.engine_version must be a string."
        )

    if not red_flag_result.engine_version.strip():
        raise ValueError(
            "red_flag_result.engine_version must not be empty."
        )

    if not isinstance(red_flag_result.matches, tuple):
        raise TypeError(
            "red_flag_result.matches must be a tuple."
        )

    rule_identities: set[tuple[str, int]] = set()

    for match in red_flag_result.matches:
        if not isinstance(match, RedFlagMatch):
            raise TypeError(
                "every red-flag result match must be a "
                "RedFlagMatch instance."
            )

        if not isinstance(match.rule_id, str):
            raise TypeError("match.rule_id must be a string.")

        if not match.rule_id.strip():
            raise ValueError("match.rule_id must not be empty.")

        if (
            isinstance(match.rule_version, bool)
            or not isinstance(match.rule_version, int)
        ):
            raise TypeError(
                "match.rule_version must be an integer."
            )

        if match.rule_version < 1:
            raise ValueError(
                "match.rule_version must be greater than "
                "or equal to 1."
            )

        if not isinstance(match.urgency, RedFlagUrgency):
            raise TypeError(
                "match.urgency must be a "
                "RedFlagUrgency instance."
            )

        if not isinstance(match.warning_key, str):
            raise TypeError(
                "match.warning_key must be a string."
            )

        if not match.warning_key.strip():
            raise ValueError(
                "match.warning_key must not be empty."
            )

        rule_identity = (
            match.rule_id,
            match.rule_version,
        )

        if rule_identity in rule_identities:
            raise ValueError(
                "duplicate red-flag rule identities "
                "are not allowed."
            )

        rule_identities.add(rule_identity)

    highest_urgency = red_flag_result.highest_urgency
    must_override_model = red_flag_result.must_override_model
    should_short_circuit_llm = (
        red_flag_result.should_short_circuit_llm
    )

    if (
        highest_urgency is not None
        and not isinstance(
            highest_urgency,
            RedFlagUrgency,
        )
    ):
        raise TypeError(
            "highest_urgency must be a RedFlagUrgency "
            "instance or None."
        )

    if type(must_override_model) is not bool:
        raise TypeError(
            "must_override_model must be a boolean."
        )

    if type(should_short_circuit_llm) is not bool:
        raise TypeError(
            "should_short_circuit_llm must be a boolean."
        )

    expected_highest_urgency = (
        _highest_urgency_from_matches(
            red_flag_result.matches
        )
    )
    expected_override = bool(red_flag_result.matches)
    expected_short_circuit = (
        expected_highest_urgency
        == RedFlagUrgency.EMERGENCY
    )

    if highest_urgency != expected_highest_urgency:
        raise ValueError(
            "red_flag_result.highest_urgency is inconsistent "
            "with matches."
        )

    if must_override_model != expected_override:
        raise ValueError(
            "red_flag_result.must_override_model is "
            "inconsistent with matches."
        )

    if should_short_circuit_llm != expected_short_circuit:
        raise ValueError(
            "red_flag_result.should_short_circuit_llm is "
            "inconsistent with matches."
        )


def _highest_urgency_from_matches(
    matches: tuple[RedFlagMatch, ...],
) -> RedFlagUrgency | None:
    if any(
        match.urgency == RedFlagUrgency.EMERGENCY
        for match in matches
    ):
        return RedFlagUrgency.EMERGENCY

    if any(
        match.urgency == RedFlagUrgency.URGENT
        for match in matches
    ):
        return RedFlagUrgency.URGENT

    return None


def apply_response_policy(
    red_flag_result: RedFlagCheckResult,
) -> StructuredSafetyDecision:
    """
    Convert a red-flag result into a deterministic safety decision.

    Emergency:
    - overrides the model
    - short-circuits the normal LLM response path

    Urgent:
    - overrides any lower model urgency
    - does not automatically short-circuit the LLM

    Continue:
    - permits the normal chat flow
    """
    _validate_red_flag_result(red_flag_result)

    reasons = tuple(
        sorted(
            (
                SafetyDecisionReason(
                    rule_id=match.rule_id,
                    rule_version=match.rule_version,
                    urgency=match.urgency,
                    warning_key=match.warning_key,
                )
                for match in red_flag_result.matches
            ),
            key=_reason_sort_key,
        )
    )

    highest_urgency = red_flag_result.highest_urgency

    return StructuredSafetyDecision(
        decision=_decision_for_urgency(
            highest_urgency
        ),
        reasons=reasons,
        highest_urgency=highest_urgency,
        must_override_model=(
            red_flag_result.must_override_model
        ),
        should_short_circuit_llm=(
            red_flag_result.should_short_circuit_llm
        ),
        source_engine_version=(
            red_flag_result.engine_version
        ),
    )
