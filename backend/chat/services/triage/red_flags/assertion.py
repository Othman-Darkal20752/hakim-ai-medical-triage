from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Final, Literal

from .matching import MedicalConceptMatch, MedicalConceptMatchResult
from .schemas import AssertionStatus


ASSERTION_DETECTOR_VERSION: Final[str] = "hakim-assertion-v1"
MAX_CONTEXT_TOKENS: Final[int] = 5

_TOKEN_PATTERN: Final[re.Pattern[str]] = re.compile(
    r"[\w']+",
    flags=re.UNICODE,
)

_HARD_BOUNDARY_CHARACTERS: Final[frozenset[str]] = frozenset(
    ".!?؟،,؛;:\n\r"
)

_SOFT_BOUNDARY_TOKENS: Final[frozenset[str]] = frozenset(
    {
        "بس",
        "لكن",
        "ولكن",
        "انما",
        "أما",
        "اما",
        "but",
        "however",
    }
)

_NEGATION_PATTERNS: Final[tuple[tuple[str, ...], ...]] = (
    # Arabic multi-token expressions.
    ("لا", "اعاني", "من"),
    ("لا", "بعاني", "من"),
    ("ما", "عم", "بعاني"),
    ("ما", "عم", "بحس"),
    ("ما", "عم", "حس"),
    ("مو", "عم", "بعاني"),
    ("ليس", "لدي"),
    ("ليست", "لدي"),
    ("ما", "عندي"),
    ("مو", "عندي"),
    ("ما", "في"),
    ("ما", "فيه"),
    ("ما", "بعاني"),
    ("ما", "اعاني"),
    ("ما", "بحس"),
    ("ما", "حسيت"),
    ("ما", "صار", "معي"),
    ("من", "دون"),

    # Arabic single-token and joined colloquial expressions.
    ("لا",),
    ("ليس",),
    ("ليست",),
    ("لست",),
    ("لم",),
    ("لن",),
    ("بدون",),
    ("ولا",),
    ("مو",),
    ("ماني",),
    ("مب",),
    ("مافي",),
    ("مافيه",),
    ("مافيني",),
    ("ماعندي",),
    ("معندي",),
    ("مابعاني",),
    ("مابحس",),
    ("ماحسيت",),

    # English multi-token expressions.
    ("do", "not", "have"),
    ("does", "not", "have"),
    ("did", "not", "have"),
    ("do", "not", "feel"),
    ("does", "not", "feel"),
    ("did", "not", "feel"),
    ("don't", "have"),
    ("doesn't", "have"),
    ("didn't", "have"),
    ("dont", "have"),
    ("doesnt", "have"),
    ("didnt", "have"),
    ("no", "longer"),
    ("no", "longer", "have"),

    # English single-token expressions.
    ("no",),
    ("not",),
    ("without",),
    ("never",),
    ("denies",),
    ("denied",),
)

_POSITIVE_PATTERNS: Final[tuple[tuple[str, ...], ...]] = (
    # Arabic assertion/reset cues.
    ("صار", "معي"),
    ("عم", "بعاني"),
    ("عم", "بحس"),
    ("عندي",),
    ("لدي",),
    ("اعاني",),
    ("بعاني",),
    ("اشعر",),
    ("بشعر",),
    ("بحس",),
    ("حسيت",),

    # English assertion/reset cues.
    ("i", "have"),
    ("i", "feel"),
    ("i", "am", "having"),
    ("i", "am", "experiencing"),
    ("have",),
    ("has",),
    ("having",),
    ("feel",),
    ("feeling",),
    ("experiencing",),
)


@dataclass(frozen=True, slots=True)
class _Token:
    """Internal normalized token with half-open character offsets."""

    text: str
    start: int
    end: int


@dataclass(frozen=True, slots=True)
class _CueCandidate:
    """Internal negation or positive assertion cue."""

    kind: Literal["negation", "positive"]
    text: str
    start: int
    end: int
    token_count: int


@dataclass(frozen=True, slots=True)
class AssertedMedicalConceptMatch:
    """
    One medical concept match annotated with an assertion status.

    The original MedicalConceptMatch object is retained unchanged so its
    original evidence and normalized/original offsets remain available.
    """

    match: MedicalConceptMatch
    assertion: AssertionStatus
    matched_cue: str | None
    normalized_context_start: int
    normalized_context_end: int

    def __post_init__(self) -> None:
        if self.normalized_context_start < 0:
            raise ValueError(
                "normalized_context_start must be greater than or equal to zero."
            )

        if self.normalized_context_end < self.normalized_context_start:
            raise ValueError(
                "normalized_context_end must not precede "
                "normalized_context_start."
            )

        if self.matched_cue is not None and not self.matched_cue.strip():
            raise ValueError("matched_cue must not be blank.")


@dataclass(frozen=True, slots=True)
class AssertionDetectionResult:
    """Structured output of deterministic assertion detection."""

    source: MedicalConceptMatchResult
    matches: tuple[AssertedMedicalConceptMatch, ...]
    detector_version: str = ASSERTION_DETECTOR_VERSION

    def __post_init__(self) -> None:
        if not self.detector_version.strip():
            raise ValueError("detector_version must not be empty.")

    @property
    def has_matches(self) -> bool:
        return bool(self.matches)

    @property
    def present_matches(self) -> tuple[AssertedMedicalConceptMatch, ...]:
        return tuple(
            item
            for item in self.matches
            if item.assertion == AssertionStatus.PRESENT
        )

    @property
    def negated_matches(self) -> tuple[AssertedMedicalConceptMatch, ...]:
        return tuple(
            item
            for item in self.matches
            if item.assertion == AssertionStatus.NEGATED
        )


def _tokenize(
    text: str,
    *,
    offset: int = 0,
) -> tuple[_Token, ...]:
    """Tokenize normalized Arabic or English text while preserving offsets."""

    return tuple(
        _Token(
            text=match.group(0),
            start=offset + match.start(),
            end=offset + match.end(),
        )
        for match in _TOKEN_PATTERN.finditer(text)
    )


def _find_hard_boundary_start(
    text: str,
    concept_start: int,
) -> int:
    """Return the position after the nearest preceding hard boundary."""

    for index in range(concept_start - 1, -1, -1):
        if text[index] in _HARD_BOUNDARY_CHARACTERS:
            return index + 1

    return 0


def _find_context_start(
    text: str,
    concept_start: int,
) -> int:
    """
    Determine the bounded context before a concept.

    Scope is limited by:
    1. The nearest punctuation/newline boundary.
    2. The nearest soft clause boundary.
    3. The final MAX_CONTEXT_TOKENS tokens.
    """

    context_start = _find_hard_boundary_start(
        text=text,
        concept_start=concept_start,
    )

    tokens = _tokenize(
        text[context_start:concept_start],
        offset=context_start,
    )

    for token in reversed(tokens):
        if token.text in _SOFT_BOUNDARY_TOKENS:
            context_start = token.end
            break

    tokens = tuple(
        token
        for token in tokens
        if token.start >= context_start
    )

    if len(tokens) > MAX_CONTEXT_TOKENS:
        context_start = tokens[-MAX_CONTEXT_TOKENS].start

    return context_start


def _collect_pattern_candidates(
    *,
    tokens: tuple[_Token, ...],
    source_text: str,
    patterns: tuple[tuple[str, ...], ...],
    kind: Literal["negation", "positive"],
) -> list[_CueCandidate]:
    """Collect exact token-sequence cue candidates."""

    candidates: list[_CueCandidate] = []
    token_texts = tuple(token.text for token in tokens)

    for pattern in patterns:
        pattern_length = len(pattern)

        if pattern_length > len(tokens):
            continue

        for start_index in range(
            0,
            len(tokens) - pattern_length + 1,
        ):
            end_index = start_index + pattern_length

            if token_texts[start_index:end_index] != pattern:
                continue

            start_token = tokens[start_index]
            end_token = tokens[end_index - 1]

            candidates.append(
                _CueCandidate(
                    kind=kind,
                    text=source_text[start_token.start:end_token.end],
                    start=start_token.start,
                    end=end_token.end,
                    token_count=pattern_length,
                )
            )

    return candidates


def _select_nearest_cue(
    *,
    tokens: tuple[_Token, ...],
    source_text: str,
) -> _CueCandidate | None:
    """
    Select the closest relevant cue before a concept.

    A later positive cue resets an earlier negation scope. When positive and
    negation patterns end at the same position, negation takes precedence so
    phrases such as "ليس لدي" and "do not have" remain negated.
    """

    candidates = _collect_pattern_candidates(
        tokens=tokens,
        source_text=source_text,
        patterns=_NEGATION_PATTERNS,
        kind="negation",
    )

    candidates.extend(
        _collect_pattern_candidates(
            tokens=tokens,
            source_text=source_text,
            patterns=_POSITIVE_PATTERNS,
            kind="positive",
        )
    )

    if not candidates:
        return None

    return max(
        candidates,
        key=lambda candidate: (
            candidate.end,
            1 if candidate.kind == "negation" else 0,
            candidate.token_count,
            candidate.start,
        ),
    )


def detect_assertions(
    match_result: MedicalConceptMatchResult,
) -> AssertionDetectionResult:
    """
    Assign PRESENT or NEGATED to every matched medical concept.

    This detector is deterministic and independent from the LLM. It does not
    implement uncertainty, temporal history, hypothetical statements, other
    persons, urgency, or medical red-flag rules.
    """

    source_text = match_result.normalized_text
    asserted_matches: list[AssertedMedicalConceptMatch] = []

    for match in match_result.matches:
        if match.normalized_start < 0:
            raise ValueError(
                "Medical concept normalized_start must not be negative."
            )

        if match.normalized_end > len(source_text):
            raise ValueError(
                "Medical concept normalized_end exceeds normalized text."
            )

        context_start = _find_context_start(
            text=source_text,
            concept_start=match.normalized_start,
        )
        context_end = match.normalized_start

        context_tokens = _tokenize(
            source_text[context_start:context_end],
            offset=context_start,
        )

        nearest_cue = _select_nearest_cue(
            tokens=context_tokens,
            source_text=source_text,
        )

        assertion = (
            AssertionStatus.NEGATED
            if nearest_cue is not None
            and nearest_cue.kind == "negation"
            else AssertionStatus.PRESENT
        )

        asserted_matches.append(
            AssertedMedicalConceptMatch(
                match=match,
                assertion=assertion,
                matched_cue=(
                    nearest_cue.text
                    if nearest_cue is not None
                    and nearest_cue.kind == "negation"
                    else None
                ),
                normalized_context_start=context_start,
                normalized_context_end=context_end,
            )
        )

    return AssertionDetectionResult(
        source=match_result,
        matches=tuple(asserted_matches),
    )