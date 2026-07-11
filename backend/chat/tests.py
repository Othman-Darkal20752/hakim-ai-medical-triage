from django.test import SimpleTestCase

from chat.services.triage.red_flags.concepts import (
    ConceptAlias,
    ConceptLanguage,
    MedicalConcept,
)
from chat.services.triage.red_flags.registry import ConceptLexiconRegistry


class ConceptLexiconRegistryTests(SimpleTestCase):
    def test_valid_registry_supports_code_and_alias_lookup(self) -> None:
        chest_pain = MedicalConcept(
            code="chest_pain",
            aliases=(
                ConceptAlias(
                    text="الم صدر",
                    language=ConceptLanguage.ARABIC,
                ),
                ConceptAlias(
                    text="chest pain",
                    language=ConceptLanguage.ENGLISH,
                ),
            ),
        )

        shortness_of_breath = MedicalConcept(
            code="shortness_of_breath",
            aliases=(
                ConceptAlias(
                    text="ضيق تنفس",
                    language=ConceptLanguage.ARABIC,
                ),
                ConceptAlias(
                    text="shortness of breath",
                    language=ConceptLanguage.ENGLISH,
                ),
            ),
        )

        registry = ConceptLexiconRegistry(
            concepts=(chest_pain, shortness_of_breath),
        )

        self.assertEqual(len(registry), 2)

        self.assertIs(
            registry.get("chest_pain"),
            chest_pain,
        )
        self.assertIs(
            registry.require("shortness_of_breath"),
            shortness_of_breath,
        )
        self.assertIsNone(
            registry.get("unknown_concept"),
        )

        self.assertIs(
            registry.concept_for_alias(
                ConceptLanguage.ARABIC,
                "الم صدر",
            ),
            chest_pain,
        )
        self.assertIs(
            registry.concept_for_alias(
                ConceptLanguage.ENGLISH,
                "shortness of breath",
            ),
            shortness_of_breath,
        )

        self.assertEqual(
            registry.aliases_for(ConceptLanguage.ENGLISH),
            (
                "chest pain",
                "shortness of breath",
            ),
        )

    def test_duplicate_concept_code_is_rejected(self) -> None:
        first_concept = MedicalConcept(
            code="chest_pain",
            aliases=(
                ConceptAlias(
                    text="الم صدر",
                    language=ConceptLanguage.ARABIC,
                ),
            ),
        )

        second_concept = MedicalConcept(
            code="chest_pain",
            aliases=(
                ConceptAlias(
                    text="chest discomfort",
                    language=ConceptLanguage.ENGLISH,
                ),
            ),
        )

        with self.assertRaisesRegex(
            ValueError,
            r"duplicate medical concept code: 'chest_pain'",
        ):
            ConceptLexiconRegistry(
                concepts=(first_concept, second_concept),
            )

    def test_same_language_alias_conflict_is_rejected(self) -> None:
        first_concept = MedicalConcept(
            code="chest_pain",
            aliases=(
                ConceptAlias(
                    text="الم صدر",
                    language=ConceptLanguage.ARABIC,
                ),
            ),
        )

        second_concept = MedicalConcept(
            code="cardiac_discomfort",
            aliases=(
                ConceptAlias(
                    text="الم صدر",
                    language=ConceptLanguage.ARABIC,
                ),
            ),
        )

        with self.assertRaisesRegex(
            ValueError,
            (
                r"alias conflict detected: "
                r"'الم صدر' in language 'ar' "
                r"is assigned to both "
                r"'chest_pain' and 'cardiac_discomfort'"
            ),
        ):
            ConceptLexiconRegistry(
                concepts=(first_concept, second_concept),
            )

    def test_identical_alias_is_allowed_across_languages(self) -> None:
        arabic_concept = MedicalConcept(
            code="arabic_concept",
            aliases=(
                ConceptAlias(
                    text="shared alias",
                    language=ConceptLanguage.ARABIC,
                ),
            ),
        )

        english_concept = MedicalConcept(
            code="english_concept",
            aliases=(
                ConceptAlias(
                    text="shared alias",
                    language=ConceptLanguage.ENGLISH,
                ),
            ),
        )

        registry = ConceptLexiconRegistry(
            concepts=(arabic_concept, english_concept),
        )

        self.assertIs(
            registry.concept_for_alias(
                ConceptLanguage.ARABIC,
                "shared alias",
            ),
            arabic_concept,
        )

        self.assertIs(
            registry.concept_for_alias(
                ConceptLanguage.ENGLISH,
                "shared alias",
            ),
            english_concept,
        )

    def test_mutable_concepts_collection_is_rejected(self) -> None:
        concept = MedicalConcept(
            code="chest_pain",
            aliases=(
                ConceptAlias(
                    text="chest pain",
                    language=ConceptLanguage.ENGLISH,
                ),
            ),
        )

        with self.assertRaisesRegex(
            TypeError,
            r"concepts must be a tuple of MedicalConcept instances",
        ):
            ConceptLexiconRegistry(
                concepts=[concept],
            )
    def test_invalid_registry_item_is_rejected(self) -> None:
        with self.assertRaisesRegex(
            TypeError,
            r"every registry item must be a MedicalConcept instance",
        ):
            ConceptLexiconRegistry(
                concepts=("not_a_medical_concept",),
            )