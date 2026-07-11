from __future__ import annotations

from dataclasses import dataclass, field
from types import MappingProxyType
from typing import Mapping

from .concepts import ConceptLanguage, MedicalConcept


@dataclass(frozen=True, slots=True)
class ConceptLexiconRegistry:
    """
    Immutable registry for validated medical concepts.

    The registry guarantees:
    - Unique concept codes.
    - Unique aliases across concepts within the same language.
    - Constant-time lookup by concept code.
    - Constant-time exact lookup by normalized alias and language.

    This class does not normalize text and does not perform phrase matching.
    """

    concepts: tuple[MedicalConcept, ...]

    _concepts_by_code: Mapping[str, MedicalConcept] = field(
        init=False,
        repr=False,
    )
    _concepts_by_alias: Mapping[
        tuple[ConceptLanguage, str],
        MedicalConcept,
    ] = field(
        init=False,
        repr=False,
    )
    _aliases_by_language: Mapping[
        ConceptLanguage,
        tuple[str, ...],
    ] = field(
        init=False,
        repr=False,
    )

    def __post_init__(self) -> None:
        if not isinstance(self.concepts, tuple):
            raise TypeError("concepts must be a tuple of MedicalConcept instances")

        concepts_by_code: dict[str, MedicalConcept] = {}
        concepts_by_alias: dict[
            tuple[ConceptLanguage, str],
            MedicalConcept,
        ] = {}
        aliases_by_language: dict[ConceptLanguage, list[str]] = {
            language: [] for language in ConceptLanguage
        }

        for concept in self.concepts:
            if not isinstance(concept, MedicalConcept):
                raise TypeError(
                    "every registry item must be a MedicalConcept instance"
                )

            existing_code_owner = concepts_by_code.get(concept.code)
            if existing_code_owner is not None:
                raise ValueError(
                    f"duplicate medical concept code: {concept.code!r}"
                )

            concepts_by_code[concept.code] = concept

            for language in ConceptLanguage:
                for alias in concept.aliases_for(language):
                    alias_key = (language, alias)
                    existing_alias_owner = concepts_by_alias.get(alias_key)

                    if existing_alias_owner is not None:
                        raise ValueError(
                            "alias conflict detected: "
                            f"{alias!r} in language {language.value!r} "
                            f"is assigned to both "
                            f"{existing_alias_owner.code!r} and "
                            f"{concept.code!r}"
                        )

                    concepts_by_alias[alias_key] = concept
                    aliases_by_language[language].append(alias)

        immutable_aliases_by_language = {
            language: tuple(aliases)
            for language, aliases in aliases_by_language.items()
        }

        object.__setattr__(
            self,
            "_concepts_by_code",
            MappingProxyType(concepts_by_code),
        )
        object.__setattr__(
            self,
            "_concepts_by_alias",
            MappingProxyType(concepts_by_alias),
        )
        object.__setattr__(
            self,
            "_aliases_by_language",
            MappingProxyType(immutable_aliases_by_language),
        )

    def get(self, code: str) -> MedicalConcept | None:
        """Return a concept by code, or None when it does not exist."""

        if not isinstance(code, str):
            raise TypeError("code must be a string")

        return self._concepts_by_code.get(code)

    def require(self, code: str) -> MedicalConcept:
        """Return a concept by code, raising KeyError when not registered."""

        concept = self.get(code)

        if concept is None:
            raise KeyError(f"unknown medical concept code: {code!r}")

        return concept

    def concept_for_alias(
        self,
        language: ConceptLanguage,
        alias: str,
    ) -> MedicalConcept | None:
        """
        Return the concept owning an exact normalized alias.

        This is an exact registry lookup, not free-text matching.
        """

        if not isinstance(language, ConceptLanguage):
            raise TypeError("language must be a ConceptLanguage instance")

        if not isinstance(alias, str):
            raise TypeError("alias must be a string")

        return self._concepts_by_alias.get((language, alias))

    def aliases_for(
        self,
        language: ConceptLanguage,
    ) -> tuple[str, ...]:
        """Return all registered aliases for one language."""

        if not isinstance(language, ConceptLanguage):
            raise TypeError("language must be a ConceptLanguage instance")

        return self._aliases_by_language[language]

    def __len__(self) -> int:
        return len(self.concepts)