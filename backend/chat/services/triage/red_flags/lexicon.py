from __future__ import annotations

from typing import Final

from .concepts import (
    ConceptAlias,
    ConceptLanguage,
    MedicalConcept,
)
from .registry import ConceptLexiconRegistry


LEXICON_VERSION: Final[str] = "1.1.0"


CHEST_PAIN: Final[MedicalConcept] = MedicalConcept(
    code="chest_pain",
    aliases=(
        ConceptAlias(
            text="الم في الصدر",
            language=ConceptLanguage.ARABIC,
        ),
        ConceptAlias(
            text="وجع في الصدر",
            language=ConceptLanguage.ARABIC,
        ),
        ConceptAlias(
            text="chest pain",
            language=ConceptLanguage.ENGLISH,
        ),
    ),
)

SHORTNESS_OF_BREATH: Final[MedicalConcept] = MedicalConcept(
    code="shortness_of_breath",
    aliases=(
        ConceptAlias(
            text="ضيق التنفس",
            language=ConceptLanguage.ARABIC,
        ),
        ConceptAlias(
            text="صعوبة التنفس",
            language=ConceptLanguage.ARABIC,
        ),
        ConceptAlias(
            text="shortness of breath",
            language=ConceptLanguage.ENGLISH,
        ),
        ConceptAlias(
            text="difficulty breathing",
            language=ConceptLanguage.ENGLISH,
        ),
    ),
)

LOSS_OF_CONSCIOUSNESS: Final[MedicalConcept] = MedicalConcept(
    code="loss_of_consciousness",
    aliases=(
        ConceptAlias(
            text="فقدان الوعي",
            language=ConceptLanguage.ARABIC,
        ),
        ConceptAlias(
            text="فقد الوعي",
            language=ConceptLanguage.ARABIC,
        ),
        ConceptAlias(
            text="loss of consciousness",
            language=ConceptLanguage.ENGLISH,
        ),
    ),
)


# Only medically and linguistically reviewed concepts may be added here.
# Draft, generated, or externally supplied concepts must not be loaded
# into the production registry.
APPROVED_CONCEPTS: Final[tuple[MedicalConcept, ...]] = (
    CHEST_PAIN,
    SHORTNESS_OF_BREATH,
    LOSS_OF_CONSCIOUSNESS,
)

CONCEPT_LEXICON: Final[ConceptLexiconRegistry] = ConceptLexiconRegistry(
    concepts=APPROVED_CONCEPTS,
)
