from __future__ import annotations

from dataclasses import dataclass, field
import re
from types import MappingProxyType
from typing import Final, Iterator, Mapping

from .concepts import CONCEPT_CODE_PATTERN
from .registry import ConceptLexiconRegistry
from .schemas import AssertionStatus, RedFlagUrgency


RULE_ID_PATTERN: Final[re.Pattern[str]] = re.compile(
    r"^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$"
)

WARNING_KEY_PATTERN: Final[re.Pattern[str]] = re.compile(
    r"^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$"
)


@dataclass(frozen=True, slots=True)
class RedFlagEvidenceRequirement:
    """
    Defines one medical concept required by a red-flag rule.

    The evidence is considered acceptable only when the detected concept
    has one of the explicitly allowed assertion statuses.
    """

    concept_code: str
    accepted_assertion_statuses: tuple[AssertionStatus, ...]

    def __post_init__(self) -> None:
        if not isinstance(self.concept_code, str):
            raise TypeError("concept_code must be a string.")

        if not CONCEPT_CODE_PATTERN.fullmatch(self.concept_code):
            raise ValueError(
                "concept_code must use lowercase snake_case."
            )

        if not isinstance(self.accepted_assertion_statuses, tuple):
            raise TypeError(
                "accepted_assertion_statuses must be a tuple."
            )

        if not self.accepted_assertion_statuses:
            raise ValueError(
                "accepted_assertion_statuses must not be empty."
            )

        seen_statuses: set[AssertionStatus] = set()

        for status in self.accepted_assertion_statuses:
            if not isinstance(status, AssertionStatus):
                raise TypeError(
                    "every accepted assertion status must be an "
                    "AssertionStatus instance."
                )

            if status in seen_statuses:
                raise ValueError(
                    "duplicate accepted assertion statuses are not allowed."
                )

            seen_statuses.add(status)


@dataclass(frozen=True, slots=True)
class RedFlagRule:
    """
    Declarative definition of one deterministic medical red-flag rule.

    All required evidence items use AND semantics. Rule evaluation is
    intentionally implemented by a separate component.
    """

    rule_id: str
    version: int
    required_evidence: tuple[RedFlagEvidenceRequirement, ...]
    urgency: RedFlagUrgency
    warning_key: str

    def __post_init__(self) -> None:
        if not isinstance(self.rule_id, str):
            raise TypeError("rule_id must be a string.")

        if not RULE_ID_PATTERN.fullmatch(self.rule_id):
            raise ValueError(
                "rule_id must use lowercase snake_case."
            )

        if isinstance(self.version, bool) or not isinstance(
            self.version,
            int,
        ):
            raise TypeError("version must be an integer.")

        if self.version < 1:
            raise ValueError(
                "version must be greater than or equal to 1."
            )

        if not isinstance(self.required_evidence, tuple):
            raise TypeError("required_evidence must be a tuple.")

        if not self.required_evidence:
            raise ValueError(
                "a red-flag rule must contain required evidence."
            )

        seen_concept_codes: set[str] = set()

        for evidence_requirement in self.required_evidence:
            if not isinstance(
                evidence_requirement,
                RedFlagEvidenceRequirement,
            ):
                raise TypeError(
                    "every required evidence item must be a "
                    "RedFlagEvidenceRequirement instance."
                )

            if evidence_requirement.concept_code in seen_concept_codes:
                raise ValueError(
                    "duplicate concept codes are not allowed within "
                    "the same rule."
                )

            seen_concept_codes.add(
                evidence_requirement.concept_code
            )

        if not isinstance(self.urgency, RedFlagUrgency):
            raise TypeError(
                "urgency must be a RedFlagUrgency instance."
            )

        if not isinstance(self.warning_key, str):
            raise TypeError("warning_key must be a string.")

        if not WARNING_KEY_PATTERN.fullmatch(self.warning_key):
            raise ValueError(
                "warning_key must be a namespaced lowercase key, "
                "for example 'red_flags.chest_pain_warning'."
            )


@dataclass(frozen=True, slots=True)
class RedFlagRuleRegistry:
    """
    Immutable registry containing validated red-flag rule definitions.

    The registry guarantees:
    - Unique rule IDs.
    - Valid references to registered medical concepts.
    - Constant-time lookup by rule ID.
    - Stable rule ordering.
    """

    rules: tuple[RedFlagRule, ...]
    concept_registry: ConceptLexiconRegistry = field(repr=False)

    _rules_by_id: Mapping[str, RedFlagRule] = field(
        init=False,
        repr=False,
    )

    def __post_init__(self) -> None:
        if not isinstance(self.rules, tuple):
            raise TypeError(
                "rules must be a tuple of RedFlagRule instances."
            )

        if not isinstance(
            self.concept_registry,
            ConceptLexiconRegistry,
        ):
            raise TypeError(
                "concept_registry must be a "
                "ConceptLexiconRegistry instance."
            )

        rules_by_id: dict[str, RedFlagRule] = {}

        for rule in self.rules:
            if not isinstance(rule, RedFlagRule):
                raise TypeError(
                    "every registry item must be a RedFlagRule instance."
                )

            if rule.rule_id in rules_by_id:
                raise ValueError(
                    f"duplicate red-flag rule ID: {rule.rule_id!r}"
                )

            for evidence_requirement in rule.required_evidence:
                concept_code = evidence_requirement.concept_code

                if self.concept_registry.get(concept_code) is None:
                    raise ValueError(
                        f"red-flag rule {rule.rule_id!r} references "
                        f"unknown medical concept code: {concept_code!r}"
                    )

            rules_by_id[rule.rule_id] = rule

        object.__setattr__(
            self,
            "_rules_by_id",
            MappingProxyType(rules_by_id),
        )

    @property
    def rule_ids(self) -> tuple[str, ...]:
        """Return registered rule IDs in deterministic definition order."""

        return tuple(self._rules_by_id)

    def get(self, rule_id: str) -> RedFlagRule | None:
        """Return a rule by ID, or None when it does not exist."""

        if not isinstance(rule_id, str):
            raise TypeError("rule_id must be a string.")

        return self._rules_by_id.get(rule_id)

    def require(self, rule_id: str) -> RedFlagRule:
        """Return a rule by ID, raising KeyError when it is not registered."""

        rule = self.get(rule_id)

        if rule is None:
            raise KeyError(
                f"unknown red-flag rule ID: {rule_id!r}"
            )

        return rule

    def __iter__(self) -> Iterator[RedFlagRule]:
        return iter(self.rules)

    def __len__(self) -> int:
        return len(self.rules)
