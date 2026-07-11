from __future__ import annotations

from typing import Final

from .assertion import (
    AssertedMedicalConceptMatch,
    AssertionDetectionResult,
)
from .concepts import ConceptLanguage
from .matching import MedicalConceptMatch, MedicalConceptMatchResult
from .rules import (
    RedFlagEvidenceRequirement,
    RedFlagRule,
    RedFlagRuleRegistry,
)
from .schemas import (
    AssertionStatus,
    DetectedLanguage,
    RedFlagCheckResult,
    RedFlagEvidence,
    RedFlagMatch,
)


DEFAULT_SEGMENT_INDEX: Final[int] = 0


def _validate_assertion_result(
    assertion_result: AssertionDetectionResult,
) -> None:
    """
    Validate that assertion detection output is internally consistent.

    AssertionDetectionResult is normally created by detect_assertions(), but
    explicit validation here keeps the evaluation boundary safe when objects
    are manually constructed in tests or by future integrations.
    """
    if not isinstance(assertion_result, AssertionDetectionResult):
        raise TypeError(
            "assertion_result must be an AssertionDetectionResult instance."
        )

    if not isinstance(assertion_result.source, MedicalConceptMatchResult):
        raise TypeError(
            "assertion_result.source must be a "
            "MedicalConceptMatchResult instance."
        )

    if not isinstance(assertion_result.source.original_text, str):
        raise TypeError("source.original_text must be a string.")

    if not isinstance(assertion_result.source.normalized_text, str):
        raise TypeError("source.normalized_text must be a string.")

    if not isinstance(assertion_result.source.matches, tuple):
        raise TypeError("source.matches must be a tuple.")

    if not isinstance(assertion_result.matches, tuple):
        raise TypeError("assertion_result.matches must be a tuple.")

    source_text = assertion_result.source.original_text

    for asserted_match in assertion_result.matches:
        if not isinstance(
            asserted_match,
            AssertedMedicalConceptMatch,
        ):
            raise TypeError(
                "every assertion result match must be an "
                "AssertedMedicalConceptMatch instance."
            )

        concept_match = asserted_match.match

        if not isinstance(concept_match, MedicalConceptMatch):
            raise TypeError(
                "every asserted match must contain a "
                "MedicalConceptMatch instance."
            )

        if concept_match not in assertion_result.source.matches:
            raise ValueError(
                "every asserted medical concept match must originate "
                "from assertion_result.source.matches."
            )

        if not isinstance(asserted_match.assertion, AssertionStatus):
            raise TypeError(
                "every asserted match assertion must be an "
                "AssertionStatus instance."
            )

        if not isinstance(concept_match.language, ConceptLanguage):
            raise TypeError(
                "every medical concept match language must be a "
                "ConceptLanguage instance."
            )

        if not isinstance(concept_match.concept_code, str):
            raise TypeError("concept_code must be a string.")

        if not concept_match.concept_code.strip():
            raise ValueError("concept_code must not be empty.")

        if not isinstance(concept_match.original_text, str):
            raise TypeError("medical concept original_text must be a string.")

        if not concept_match.original_text.strip():
            raise ValueError(
                "medical concept original_text must not be empty."
            )

        if (
            isinstance(concept_match.original_start, bool)
            or not isinstance(concept_match.original_start, int)
        ):
            raise TypeError("original_start must be an integer.")

        if (
            isinstance(concept_match.original_end, bool)
            or not isinstance(concept_match.original_end, int)
        ):
            raise TypeError("original_end must be an integer.")

        if concept_match.original_start < 0:
            raise ValueError(
                "medical concept original_start must not be negative."
            )

        if concept_match.original_end <= concept_match.original_start:
            raise ValueError(
                "medical concept original_end must be greater than "
                "original_start."
            )

        if concept_match.original_end > len(source_text):
            raise ValueError(
                "medical concept original_end exceeds the source text."
            )

        source_slice = source_text[
            concept_match.original_start : concept_match.original_end
        ]

        if source_slice != concept_match.original_text:
            raise ValueError(
                "medical concept original_text does not match its "
                "original source offsets."
            )


def _detect_language(
    assertion_result: AssertionDetectionResult,
) -> DetectedLanguage:
    """
    Infer the evaluated language from matched medical-concept aliases.

    No language model or probabilistic detector is used.
    """
    languages = {
        asserted_match.match.language
        for asserted_match in assertion_result.matches
    }

    if not languages:
        return DetectedLanguage.UNKNOWN

    if languages == {ConceptLanguage.ARABIC}:
        return DetectedLanguage.ARABIC

    if languages == {ConceptLanguage.ENGLISH}:
        return DetectedLanguage.ENGLISH

    return DetectedLanguage.MIXED


def _index_asserted_matches(
    assertion_result: AssertionDetectionResult,
) -> dict[str, tuple[AssertedMedicalConceptMatch, ...]]:
    """
    Group asserted matches by concept code while preserving source order.
    """
    mutable_index: dict[str, list[AssertedMedicalConceptMatch]] = {}

    for asserted_match in assertion_result.matches:
        concept_code = asserted_match.match.concept_code

        mutable_index.setdefault(
            concept_code,
            [],
        ).append(asserted_match)

    return {
        concept_code: tuple(matches)
        for concept_code, matches in mutable_index.items()
    }


def _select_requirement_evidence(
    requirement: RedFlagEvidenceRequirement,
    asserted_matches_by_code: dict[
        str,
        tuple[AssertedMedicalConceptMatch, ...],
    ],
) -> RedFlagEvidence | None:
    """
    Return the first deterministic occurrence satisfying one requirement.

    A concept is acceptable only when both its code and assertion status
    satisfy the rule requirement.
    """
    candidates = asserted_matches_by_code.get(
        requirement.concept_code,
        (),
    )

    for candidate in candidates:
        if (
            candidate.assertion
            not in requirement.accepted_assertion_statuses
        ):
            continue

        concept_match = candidate.match

        return RedFlagEvidence(
            concept_code=concept_match.concept_code,
            matched_text=concept_match.original_text,
            assertion=candidate.assertion,
            start_char=concept_match.original_start,
            end_char=concept_match.original_end,
            segment_index=DEFAULT_SEGMENT_INDEX,
        )

    return None


def _evaluate_rule(
    rule: RedFlagRule,
    asserted_matches_by_code: dict[
        str,
        tuple[AssertedMedicalConceptMatch, ...],
    ],
) -> RedFlagMatch | None:
    """
    Evaluate one rule using strict AND semantics.

    Every required evidence item must be satisfied. Failure to satisfy one
    requirement causes the entire rule not to match.
    """
    collected_evidence: list[RedFlagEvidence] = []

    seen_evidence: set[
        tuple[
            str,
            AssertionStatus,
            int,
            int,
            int,
        ]
    ] = set()

    for requirement in rule.required_evidence:
        evidence = _select_requirement_evidence(
            requirement=requirement,
            asserted_matches_by_code=asserted_matches_by_code,
        )

        if evidence is None:
            return None

        evidence_identity = (
            evidence.concept_code,
            evidence.assertion,
            evidence.start_char,
            evidence.end_char,
            evidence.segment_index,
        )

        if evidence_identity not in seen_evidence:
            collected_evidence.append(evidence)
            seen_evidence.add(evidence_identity)

    return RedFlagMatch(
        rule_id=rule.rule_id,
        rule_version=rule.version,
        urgency=rule.urgency,
        warning_key=rule.warning_key,
        evidence=tuple(collected_evidence),
    )


def evaluate_red_flag_rules(
    assertion_result: AssertionDetectionResult,
    rule_registry: RedFlagRuleRegistry,
) -> RedFlagCheckResult:
    """
    Evaluate all registered red-flag rules deterministically.

    Guarantees:
    - Rules are evaluated in registry order.
    - Required evidence uses AND semantics.
    - Concept code and assertion status must both match.
    - Multiple rules may match.
    - Evidence order follows rule requirement order.
    - Only one deterministic occurrence is selected per requirement.
    - Original matched text and original offsets are preserved.
    """
    _validate_assertion_result(assertion_result)

    if not isinstance(rule_registry, RedFlagRuleRegistry):
        raise TypeError(
            "rule_registry must be a RedFlagRuleRegistry instance."
        )

    asserted_matches_by_code = _index_asserted_matches(
        assertion_result
    )

    matched_rules: list[RedFlagMatch] = []

    for rule in rule_registry:
        rule_match = _evaluate_rule(
            rule=rule,
            asserted_matches_by_code=asserted_matches_by_code,
        )

        if rule_match is not None:
            matched_rules.append(rule_match)

    return RedFlagCheckResult(
        language=_detect_language(assertion_result),
        matches=tuple(matched_rules),
    )