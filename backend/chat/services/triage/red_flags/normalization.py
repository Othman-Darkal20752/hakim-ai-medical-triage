from __future__ import annotations

from dataclasses import dataclass
from typing import Final


ARABIC_DIACRITICS: Final[frozenset[str]] = frozenset(
    {
        "\u0610",
        "\u0611",
        "\u0612",
        "\u0613",
        "\u0614",
        "\u0615",
        "\u0616",
        "\u0617",
        "\u0618",
        "\u0619",
        "\u061A",
        "\u064B",
        "\u064C",
        "\u064D",
        "\u064E",
        "\u064F",
        "\u0650",
        "\u0651",
        "\u0652",
        "\u0653",
        "\u0654",
        "\u0655",
        "\u0656",
        "\u0657",
        "\u0658",
        "\u0659",
        "\u065A",
        "\u065B",
        "\u065C",
        "\u065D",
        "\u065E",
        "\u065F",
        "\u0670",
    }
)

ARABIC_CHARACTER_MAP: Final[dict[str, str]] = {
    "أ": "ا",
    "إ": "ا",
    "آ": "ا",
    "ٱ": "ا",
    "ى": "ي",
}

ARABIC_TATWEEL: Final[str] = "\u0640"


@dataclass(frozen=True, slots=True)
class NormalizedText:
    """
    Text prepared for deterministic matching.

    source_indexes maps each normalized character to its corresponding
    character position in the original text.
    """

    original: str
    normalized: str
    source_indexes: tuple[int, ...]

    def __post_init__(self) -> None:
        if len(self.normalized) != len(self.source_indexes):
            raise ValueError(
                "normalized and source_indexes must have the same length."
            )

        if any(
            index < 0 or index >= len(self.original)
            for index in self.source_indexes
        ):
            raise ValueError(
                "source_indexes must reference valid original text positions."
            )

        if any(
            current >= following
            for current, following in zip(
                self.source_indexes,
                self.source_indexes[1:],
            )
        ):
            raise ValueError("source_indexes must be strictly increasing.")

    def original_span(
        self,
        normalized_start: int,
        normalized_end: int,
    ) -> tuple[int, int]:
        """
        Convert a half-open normalized span into an original-text span.

        The returned tuple follows Python slicing semantics:
        original[start:end].
        """

        if normalized_start < 0:
            raise ValueError(
                "normalized_start must be greater than or equal to zero."
            )

        if normalized_end <= normalized_start:
            raise ValueError(
                "normalized_end must be greater than normalized_start."
            )

        if normalized_end > len(self.normalized):
            raise ValueError(
                "normalized_end must not exceed normalized text length."
            )

        original_start = self.source_indexes[normalized_start]

        if normalized_end < len(self.normalized):
            original_end = self.source_indexes[normalized_end]
        else:
            original_end = self.source_indexes[normalized_end - 1] + 1

            while original_end < len(self.original):
                character = self.original[original_end]

                if (
                    character in ARABIC_DIACRITICS
                    or character == ARABIC_TATWEEL
                ):
                    original_end += 1
                    continue

                break

        return original_start, original_end

    def original_slice(
        self,
        normalized_start: int,
        normalized_end: int,
    ) -> str:
        """Return original text corresponding to a normalized span."""

        original_start, original_end = self.original_span(
            normalized_start,
            normalized_end,
        )
        return self.original[original_start:original_end]


def normalize_text(text: str) -> NormalizedText:
    """
    Normalize Arabic and English text for deterministic matching.

    Applied transformations:
    - Remove Arabic diacritics and tatweel.
    - Normalize common Arabic Alef variants and Alef Maksura.
    - Convert ASCII English uppercase letters to lowercase.
    - Normalize and collapse whitespace.
    - Preserve punctuation for later sentence and negation analysis.

    This function performs no medical interpretation.
    """

    if not isinstance(text, str):
        raise TypeError("text must be a string.")

    normalized_characters: list[str] = []
    source_indexes: list[int] = []

    for index, character in enumerate(text):
        if character in ARABIC_DIACRITICS or character == ARABIC_TATWEEL:
            continue

        if character.isspace():
            if not normalized_characters:
                continue

            if normalized_characters[-1] == " ":
                continue

            normalized_characters.append(" ")
            source_indexes.append(index)
            continue

        normalized_character = ARABIC_CHARACTER_MAP.get(
            character,
            character,
        )

        if "A" <= normalized_character <= "Z":
            normalized_character = normalized_character.lower()

        normalized_characters.append(normalized_character)
        source_indexes.append(index)

    if normalized_characters and normalized_characters[-1] == " ":
        normalized_characters.pop()
        source_indexes.pop()

    return NormalizedText(
        original=text,
        normalized="".join(normalized_characters),
        source_indexes=tuple(source_indexes),
    )
