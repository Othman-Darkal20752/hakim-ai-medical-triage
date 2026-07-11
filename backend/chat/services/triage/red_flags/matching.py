from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass

from .concepts import ConceptLanguage
from .lexicon import CONCEPT_LEXICON
from .normalization import NormalizedText, normalize_text
from .registry import ConceptLexiconRegistry


@dataclass(frozen=True, slots=True)
class MedicalConceptMatch:
    """
    A single deterministic medical-concept match.

    All start/end offsets use Python's half-open interval convention:
    [start, end).
    """

    concept_code: str
    language: ConceptLanguage
    matched_alias: str

    normalized_start: int
    normalized_end: int

    original_start: int
    original_end: int
    original_text: str


@dataclass(frozen=True, slots=True)
class MedicalConceptMatchResult:
    """
    Structured result returned by the medical concept matching engine.
    """

    original_text: str
    normalized_text: str
    matches: tuple[MedicalConceptMatch, ...]

    @property
    def has_matches(self) -> bool:
        return bool(self.matches)

    @property
    def concept_codes(self) -> tuple[str, ...]:
        """
        Return unique matched concept codes while preserving match order.
        """

        return tuple(
            dict.fromkeys(match.concept_code for match in self.matches)
        )


@dataclass(frozen=True, slots=True)
class _CandidateMatch:
    """
    Internal match candidate before overlap resolution.
    """

    concept_code: str
    language: ConceptLanguage
    alias_text: str
    normalized_start: int
    normalized_end: int

    @property
    def length(self) -> int:
        return self.normalized_end - self.normalized_start


def _is_word_character(character: str) -> bool:
    """
    Return True when the character belongs to an Arabic or English word.

    str.isalnum() is Unicode-aware, so it supports Arabic letters,
    English letters, and digits. Underscore is treated as part of a word
    to prevent matches inside identifiers such as chest_pain.
    """

    return character.isalnum() or character == "_"


def _has_valid_boundaries(
    text: str,
    start: int,
    end: int,
) -> bool:
    """
    Ensure an alias is not matched inside a longer word.
    """

    has_valid_left_boundary = (
        start == 0
        or not _is_word_character(text[start - 1])
    )

    has_valid_right_boundary = (
        end == len(text)
        or not _is_word_character(text[end])
    )

    return has_valid_left_boundary and has_valid_right_boundary


def _find_alias_occurrences(
    normalized_text: str,
    alias_text: str,
) -> Iterator[tuple[int, int]]:
    """
    Yield all boundary-valid occurrences of one normalized alias.
    """

    if not alias_text:
        return

    search_start = 0

    while True:
        match_start = normalized_text.find(alias_text, search_start)

        if match_start == -1:
            return

        match_end = match_start + len(alias_text)

        if _has_valid_boundaries(
            normalized_text,
            match_start,
            match_end,
        ):
            yield match_start, match_end

        # Advance by one character so overlapping candidate occurrences
        # can still be discovered before deterministic overlap resolution.
        search_start = match_start + 1


def _collect_candidates(
    normalized: NormalizedText,
    lexicon: ConceptLexiconRegistry,
) -> list[_CandidateMatch]:
    """
    Collect all valid alias occurrences before overlap resolution.
    """

    candidates: list[_CandidateMatch] = []

    for concept in lexicon.concepts:
        for alias in concept.aliases:
            for match_start, match_end in _find_alias_occurrences(
                normalized.normalized,
                alias.text,
            ):
                candidates.append(
                    _CandidateMatch(
                        concept_code=concept.code,
                        language=alias.language,
                        alias_text=alias.text,
                        normalized_start=match_start,
                        normalized_end=match_end,
                    )
                )

    return candidates


def _select_non_overlapping_candidates(
    candidates: list[_CandidateMatch],
) -> tuple[_CandidateMatch, ...]:
    """
    Resolve overlapping candidates using a deterministic leftmost-longest rule.

    Priority:
    1. Earliest normalized start position.
    2. Longest alias at the same start position.
    3. Concept code, alias text, and language as stable tie-breakers.
    """

    ordered_candidates = sorted(
        candidates,
        key=lambda candidate: (
            candidate.normalized_start,
            -candidate.length,
            candidate.concept_code,
            candidate.alias_text,
            candidate.language.value,
        ),
    )

    selected: list[_CandidateMatch] = []
    covered_until = 0

    for candidate in ordered_candidates:
        if candidate.normalized_start < covered_until:
            continue

        selected.append(candidate)
        covered_until = candidate.normalized_end

    return tuple(selected)


def match_medical_concepts(
    text: str,
    *,
    lexicon: ConceptLexiconRegistry = CONCEPT_LEXICON,
) -> MedicalConceptMatchResult:
    """
    Match normalized medical concept aliases inside patient text.

    This function performs lexical concept matching only. It does not apply
    negation detection, urgency classification, red-flag rules, specialty
    recommendation, or LLM logic.
    """

    normalized = normalize_text(text)

    candidates = _collect_candidates(
        normalized=normalized,
        lexicon=lexicon,
    )

    selected_candidates = _select_non_overlapping_candidates(candidates)

    matches: list[MedicalConceptMatch] = []

    for candidate in selected_candidates:
        original_start, original_end = normalized.original_span(
            candidate.normalized_start,
            candidate.normalized_end,
        )

        matches.append(
            MedicalConceptMatch(
                concept_code=candidate.concept_code,
                language=candidate.language,
                matched_alias=candidate.alias_text,
                normalized_start=candidate.normalized_start,
                normalized_end=candidate.normalized_end,
                original_start=original_start,
                original_end=original_end,
                original_text=normalized.original_slice(
                    candidate.normalized_start,
                    candidate.normalized_end,
                ),
            )
        )

    return MedicalConceptMatchResult(
        original_text=normalized.original,
        normalized_text=normalized.normalized,
        matches=tuple(matches),
    )