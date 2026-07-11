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
from chat.services.triage.red_flags.matching import match_medical_concepts
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


class MedicalConceptMatchingTests(SimpleTestCase):
    def test_english_matches_respect_boundaries_and_original_offsets(
        self,
    ) -> None:
        text = "Chest pain, chest painx, and (chest pain)."

        result = match_medical_concepts(text)

        self.assertEqual(
            result.normalized_text,
            "chest pain, chest painx, and (chest pain).",
        )
        self.assertTrue(result.has_matches)
        self.assertEqual(len(result.matches), 2)

        first_match, second_match = result.matches

        self.assertEqual(
            first_match.concept_code,
            "chest_pain",
        )
        self.assertEqual(
            first_match.language,
            ConceptLanguage.ENGLISH,
        )
        self.assertEqual(
            first_match.matched_alias,
            "chest pain",
        )
        self.assertEqual(
            (
                first_match.normalized_start,
                first_match.normalized_end,
            ),
            (0, 10),
        )
        self.assertEqual(
            (
                first_match.original_start,
                first_match.original_end,
            ),
            (0, 10),
        )
        self.assertEqual(
            first_match.original_text,
            "Chest pain",
        )

        self.assertEqual(
            second_match.original_text,
            "chest pain",
        )

    def test_arabic_match_restores_diacritized_original_evidence(
        self,
    ) -> None:
        arabic_evidence = (
            "\u0623\u064e\u0644\u064e\u0645\u064c "
            "\u0641\u064a "
            "\u0627\u0644\u0635\u062f\u0631"
        )

        invalid_longer_word = (
            ARABIC_CHEST_PAIN
            + "\u064a"
        )

        text = (
            "\u0644\u062f\u064a "
            + arabic_evidence
            + "\u060c "
            + invalid_longer_word
            + "."
        )

        result = match_medical_concepts(text)

        self.assertEqual(len(result.matches), 1)

        match = result.matches[0]

        self.assertEqual(
            match.concept_code,
            "chest_pain",
        )
        self.assertEqual(
            match.language,
            ConceptLanguage.ARABIC,
        )
        self.assertEqual(
            match.matched_alias,
            ARABIC_CHEST_PAIN,
        )
        self.assertEqual(
            match.original_text,
            arabic_evidence,
        )
        self.assertEqual(
            result.original_text[
                match.original_start:match.original_end
            ],
            arabic_evidence,
        )
        self.assertEqual(
            result.normalized_text[
                match.normalized_start:match.normalized_end
            ],
            ARABIC_CHEST_PAIN,
        )

    def test_multiple_concepts_are_returned_in_text_order(self) -> None:
        result = match_medical_concepts(
            "Chest pain and shortness of breath."
        )

        self.assertEqual(
            tuple(
                match.concept_code
                for match in result.matches
            ),
            (
                "chest_pain",
                "shortness_of_breath",
            ),
        )
        self.assertEqual(
            result.concept_codes,
            (
                "chest_pain",
                "shortness_of_breath",
            ),
        )

    def test_longest_alias_wins_when_candidates_start_together(
        self,
    ) -> None:
        short_concept = MedicalConcept(
            code="chest",
            aliases=(
                ConceptAlias(
                    text="chest",
                    language=ConceptLanguage.ENGLISH,
                ),
            ),
        )

        long_concept = MedicalConcept(
            code="chest_pain_phrase",
            aliases=(
                ConceptAlias(
                    text="chest pain",
                    language=ConceptLanguage.ENGLISH,
                ),
            ),
        )

        test_lexicon = ConceptLexiconRegistry(
            concepts=(
                short_concept,
                long_concept,
            ),
        )

        result = match_medical_concepts(
            "Chest pain.",
            lexicon=test_lexicon,
        )

        self.assertEqual(len(result.matches), 1)
        self.assertEqual(
            result.matches[0].concept_code,
            "chest_pain_phrase",
        )
        self.assertEqual(
            result.matches[0].matched_alias,
            "chest pain",
        )

    def test_text_without_known_aliases_returns_empty_result(
        self,
    ) -> None:
        result = match_medical_concepts(
            "The sky is blue."
        )

        self.assertFalse(result.has_matches)
        self.assertEqual(result.matches, ())
        self.assertEqual(result.concept_codes, ())
