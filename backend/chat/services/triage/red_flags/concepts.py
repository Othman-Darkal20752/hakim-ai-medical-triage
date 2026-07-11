from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
import re
from typing import Final

from .normalization import normalize_text


CONCEPT_CODE_PATTERN: Final[re.Pattern[str]] = re.compile(
    r"^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$"
)

MAX_CONCEPT_ALIAS_LENGTH: Final[int] = 120


class ConceptLanguage(str, Enum):
    """Supported languages for medical concept aliases."""

    ARABIC = "ar"
    ENGLISH = "en"


@dataclass(frozen=True, slots=True)
class ConceptAlias:
    """
    A normalized phrase that may represent a medical concept.

    Alias text must already be normalized using normalize_text().
    This keeps lexicon entries deterministic and avoids repeated
    normalization during each request.
    """

    text: str
    language: ConceptLanguage

    def __post_init__(self) -> None:
        if not isinstance(self.text, str):
            raise TypeError("Concept alias text must be a string.")

        if not isinstance(self.language, ConceptLanguage):
            raise TypeError(
                "Concept alias language must be a ConceptLanguage."
            )

        if not self.text:
            raise ValueError("Concept alias text must not be empty.")

        if len(self.text) > MAX_CONCEPT_ALIAS_LENGTH:
            raise ValueError(
                "Concept alias text exceeds the maximum allowed length."
            )

        normalized = normalize_text(self.text).normalized

        if normalized != self.text:
            raise ValueError(
                "Concept alias text must already be normalized."
            )


@dataclass(frozen=True, slots=True)
class MedicalConcept:
    """
    A language-independent medical concept with bilingual aliases.

    This object defines vocabulary only. It does not assign urgency,
    detect negation, or decide whether a red-flag rule matched.
    """

    code: str
    aliases: tuple[ConceptAlias, ...]

    def __post_init__(self) -> None:
        if not isinstance(self.code, str):
            raise TypeError("Medical concept code must be a string.")

        if not CONCEPT_CODE_PATTERN.fullmatch(self.code):
            raise ValueError(
                "Medical concept code must use lowercase snake_case."
            )

        if not isinstance(self.aliases, tuple):
            raise TypeError(
                "Medical concept aliases must be a tuple."
            )

        if not self.aliases:
            raise ValueError(
                "A medical concept must contain at least one alias."
            )

        seen_aliases: set[tuple[ConceptLanguage, str]] = set()

        for alias in self.aliases:
            if not isinstance(alias, ConceptAlias):
                raise TypeError(
                    "Medical concept aliases must be ConceptAlias instances."
                )

            alias_key = (alias.language, alias.text)

            if alias_key in seen_aliases:
                raise ValueError(
                    "Duplicate concept aliases are not allowed."
                )

            seen_aliases.add(alias_key)

    def aliases_for(
        self,
        language: ConceptLanguage,
    ) -> tuple[str, ...]:
        """Return aliases belonging to the requested language."""

        if not isinstance(language, ConceptLanguage):
            raise TypeError(
                "language must be a ConceptLanguage."
            )

        return tuple(
            alias.text
            for alias in self.aliases
            if alias.language == language
        )
