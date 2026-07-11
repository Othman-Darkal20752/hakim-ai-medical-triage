from django.test import SimpleTestCase

from chat.services.triage.red_flags.concepts import (
    ConceptAlias,
    ConceptLanguage,
    MedicalConcept,
)
from chat.services.triage.red_flags.lexicon import (
    APPROVED_CONCEPTS,
    CONCEPT_LEXICON,
    LEXICON_VERSION,
)
from chat.services.triage.red_flags.normalization import normalize_text
from chat.services.triage.red_flags.registry import ConceptLexiconRegistry


ARABIC_CHEST_PAIN = (
    "\u0627\u0644\u0645 \u0641\u064a "
    "\u0627\u0644\u0635\u062f\u0631"
)

ARABIC_SHORTNESS_OF_BREATH = (
    "\u0636\u064a\u0642 "
    "\u0627\u0644\u062a\u0646\u0641\u0633"
)


class ConceptLexiconRegistryTests(SimpleTestCase):
    def test_valid_registry_supports_code_and_alias_lookup(self) -> None:
        chest_pain = MedicalConcept(
            code="chest_pain",
            aliases=(
                ConceptAlias(
                    text=ARABIC_CHEST_PAIN,
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
                    text=ARABIC_SHORTNESS_OF_BREATH,
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
                ARABIC_CHEST_PAIN,
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
                    text=ARABIC_CHEST_PAIN,
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
                    text=ARABIC_CHEST_PAIN,
                    language=ConceptLanguage.ARABIC,
                ),
            ),
        )

        second_concept = MedicalConcept(
            code="cardiac_discomfort",
            aliases=(
                ConceptAlias(
                    text=ARABIC_CHEST_PAIN,
                    language=ConceptLanguage.ARABIC,
                ),
            ),
        )

        with self.assertRaises(ValueError) as context:
            ConceptLexiconRegistry(
                concepts=(first_concept, second_concept),
            )

        self.assertEqual(
            str(context.exception),
            (
                "alias conflict detected: "
                f"{ARABIC_CHEST_PAIN!r} in language 'ar' "
                "is assigned to both "
                "'chest_pain' and 'cardiac_discomfort'"
            ),
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


class MedicalConceptLexiconTests(SimpleTestCase):
    def test_lexicon_version_and_registry_size(self) -> None:
        self.assertEqual(LEXICON_VERSION, "1.1.0")
        self.assertEqual(len(APPROVED_CONCEPTS), 3)
        self.assertEqual(len(CONCEPT_LEXICON), 3)
        self.assertEqual(
            CONCEPT_LEXICON.concepts,
            APPROVED_CONCEPTS,
        )

    def test_lexicon_supports_code_and_exact_alias_lookup(self) -> None:
        self.assertEqual(
            CONCEPT_LEXICON.require("chest_pain").code,
            "chest_pain",
        )

        arabic_result = CONCEPT_LEXICON.concept_for_alias(
            ConceptLanguage.ARABIC,
            ARABIC_CHEST_PAIN,
        )

        english_result = CONCEPT_LEXICON.concept_for_alias(
            ConceptLanguage.ENGLISH,
            "difficulty breathing",
        )

        self.assertIsNotNone(arabic_result)
        self.assertIsNotNone(english_result)

        self.assertEqual(
            arabic_result.code,
            "chest_pain",
        )
        self.assertEqual(
            english_result.code,
            "shortness_of_breath",
        )

    def test_every_approved_concept_has_bilingual_aliases(self) -> None:
        for concept in APPROVED_CONCEPTS:
            with self.subTest(concept=concept.code):
                self.assertTrue(
                    concept.aliases_for(ConceptLanguage.ARABIC),
                )
                self.assertTrue(
                    concept.aliases_for(ConceptLanguage.ENGLISH),
                )

    def test_every_approved_alias_is_pre_normalized(self) -> None:
        for concept in APPROVED_CONCEPTS:
            for alias in concept.aliases:
                with self.subTest(
                    concept=concept.code,
                    alias=ascii(alias.text),
                ):
                    self.assertEqual(
                        normalize_text(alias.text).normalized,
                        alias.text,
                    )
