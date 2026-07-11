from dataclasses import FrozenInstanceError

from django.test import SimpleTestCase
from chat.services.triage.red_flags.assertion import detect_assertions
from chat.services.triage.red_flags.pipeline import check_red_flags
from chat.services.triage.safety_gate import evaluate_chat_safety
from chat.services.triage.red_flags.response_policy import (
    RESPONSE_POLICY_VERSION,
    SafetyDecisionType,
    apply_response_policy,
)
from chat.services.triage.red_flags.evaluation import (
    evaluate_red_flag_rules,
)
from chat.services.triage.red_flags.rulebook import (
    APPROVED_RED_FLAG_RULES,
    CHEST_PAIN_WITH_SHORTNESS_OF_BREATH_EMERGENCY,
    LOSS_OF_CONSCIOUSNESS_EMERGENCY,
    RED_FLAG_RULE_REGISTRY,
)
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
from chat.services.triage.red_flags.rules import (
    RedFlagEvidenceRequirement,
    RedFlagRule,
    RedFlagRuleRegistry,
)
from chat.services.triage.red_flags.schemas import (
    AssertionStatus,
    DetectedLanguage,
    RedFlagUrgency,
)


ARABIC_CHEST_PAIN = (
    "\u0627\u0644\u0645 \u0641\u064a "
    "\u0627\u0644\u0635\u062f\u0631"
)

ARABIC_SHORTNESS_OF_BREATH = (
    "\u0636\u064a\u0642 "
    "\u0627\u0644\u062a\u0646\u0641\u0633"
)

ARABIC_LOSS_OF_CONSCIOUSNESS = (
    "\u0641\u0642\u062f\u0627\u0646 "
    "\u0627\u0644\u0648\u0639\u064a"
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

class AssertionDetectionTests(SimpleTestCase):
    def test_present_concept_preserves_original_match(self) -> None:
        concept_result = match_medical_concepts(
            "I have chest pain."
        )

        result = detect_assertions(concept_result)

        self.assertTrue(result.has_matches)
        self.assertIs(result.source, concept_result)
        self.assertEqual(len(result.matches), 1)

        asserted_match = result.matches[0]

        self.assertIs(
            asserted_match.match,
            concept_result.matches[0],
        )
        self.assertEqual(
            asserted_match.assertion,
            AssertionStatus.PRESENT,
        )
        self.assertIsNone(asserted_match.matched_cue)

    def test_formal_arabic_negation_is_detected(self) -> None:
        result = detect_assertions(
            match_medical_concepts(
                f"لا اعاني من {ARABIC_CHEST_PAIN}"
            )
        )

        self.assertEqual(len(result.matches), 1)
        self.assertEqual(
            result.matches[0].assertion,
            AssertionStatus.NEGATED,
        )
        self.assertEqual(
            result.matches[0].matched_cue,
            "لا اعاني من",
        )

    def test_joined_colloquial_negation_and_positive_reset(
        self,
    ) -> None:
        text = (
            f"ماعندي {ARABIC_CHEST_PAIN} "
            f"عندي {ARABIC_SHORTNESS_OF_BREATH}"
        )

        result = detect_assertions(
            match_medical_concepts(text)
        )

        self.assertEqual(len(result.matches), 2)
        self.assertEqual(
            tuple(
                item.assertion
                for item in result.matches
            ),
            (
                AssertionStatus.NEGATED,
                AssertionStatus.PRESENT,
            ),
        )
        self.assertEqual(
            result.matches[0].matched_cue,
            "ماعندي",
        )
        self.assertIsNone(
            result.matches[1].matched_cue,
        )

    def test_without_negates_only_following_concept(
        self,
    ) -> None:
        text = (
            f"عندي {ARABIC_CHEST_PAIN} "
            f"بدون {ARABIC_SHORTNESS_OF_BREATH}"
        )

        result = detect_assertions(
            match_medical_concepts(text)
        )

        self.assertEqual(len(result.matches), 2)
        self.assertEqual(
            result.matches[0].assertion,
            AssertionStatus.PRESENT,
        )
        self.assertEqual(
            result.matches[1].assertion,
            AssertionStatus.NEGATED,
        )
        self.assertEqual(
            result.matches[1].matched_cue,
            "بدون",
        )

    def test_punctuation_stops_negation_scope(self) -> None:
        text = (
            f"لا اعاني من {ARABIC_CHEST_PAIN}. "
            f"{ARABIC_SHORTNESS_OF_BREATH}"
        )

        result = detect_assertions(
            match_medical_concepts(text)
        )

        self.assertEqual(len(result.matches), 2)
        self.assertEqual(
            tuple(
                item.assertion
                for item in result.matches
            ),
            (
                AssertionStatus.NEGATED,
                AssertionStatus.PRESENT,
            ),
        )

    def test_english_clause_boundary_resets_negation(
        self,
    ) -> None:
        result = detect_assertions(
            match_medical_concepts(
                "I do not have chest pain "
                "but I have shortness of breath."
            )
        )

        self.assertEqual(len(result.matches), 2)
        self.assertEqual(
            tuple(
                item.assertion
                for item in result.matches
            ),
            (
                AssertionStatus.NEGATED,
                AssertionStatus.PRESENT,
            ),
        )
        self.assertEqual(
            result.matches[0].matched_cue,
            "do not have",
        )
        self.assertIsNone(
            result.matches[1].matched_cue,
        )

    def test_result_without_concepts_remains_empty(self) -> None:
        concept_result = match_medical_concepts(
            "The sky is blue."
        )

        result = detect_assertions(concept_result)

        self.assertFalse(result.has_matches)
        self.assertEqual(result.matches, ())
        self.assertEqual(result.present_matches, ())
        self.assertEqual(result.negated_matches, ())
        self.assertIs(result.source, concept_result)


class RedFlagRuleSchemaAndRegistryTests(SimpleTestCase):
    def _make_evidence(
        self,
        concept_code: str = "chest_pain",
    ) -> RedFlagEvidenceRequirement:
        return RedFlagEvidenceRequirement(
            concept_code=concept_code,
            accepted_assertion_statuses=(
                AssertionStatus.PRESENT,
            ),
        )

    def _make_rule(
        self,
        rule_id: str = "test_chest_pain_rule",
        concept_code: str = "chest_pain",
    ) -> RedFlagRule:
        return RedFlagRule(
            rule_id=rule_id,
            version=1,
            required_evidence=(
                self._make_evidence(concept_code),
            ),
            urgency=RedFlagUrgency.EMERGENCY,
            warning_key="red_flags.test_chest_pain",
        )

    def test_valid_registry_supports_deterministic_lookup(
        self,
    ) -> None:
        first_rule = self._make_rule(
            rule_id="first_test_rule",
            concept_code="chest_pain",
        )
        second_rule = self._make_rule(
            rule_id="second_test_rule",
            concept_code="shortness_of_breath",
        )

        registry = RedFlagRuleRegistry(
            rules=(first_rule, second_rule),
            concept_registry=CONCEPT_LEXICON,
        )

        self.assertEqual(
            registry.rule_ids,
            ("first_test_rule", "second_test_rule"),
        )
        self.assertEqual(
            tuple(registry),
            (first_rule, second_rule),
        )
        self.assertIs(
            registry.get("first_test_rule"),
            first_rule,
        )
        self.assertIs(
            registry.require("second_test_rule"),
            second_rule,
        )
        self.assertEqual(len(registry), 2)

    def test_empty_registry_is_valid(self) -> None:
        registry = RedFlagRuleRegistry(
            rules=(),
            concept_registry=CONCEPT_LEXICON,
        )

        self.assertEqual(len(registry), 0)
        self.assertEqual(registry.rule_ids, ())
        self.assertEqual(tuple(registry), ())

    def test_evidence_rejects_invalid_concept_code(self) -> None:
        with self.assertRaises(ValueError):
            RedFlagEvidenceRequirement(
                concept_code="Chest Pain",
                accepted_assertion_statuses=(
                    AssertionStatus.PRESENT,
                ),
            )

    def test_evidence_requires_assertion_status_tuple(
        self,
    ) -> None:
        with self.assertRaises(TypeError):
            RedFlagEvidenceRequirement(
                concept_code="chest_pain",
                accepted_assertion_statuses=[
                    AssertionStatus.PRESENT,
                ],
            )

    def test_evidence_rejects_empty_assertion_statuses(
        self,
    ) -> None:
        with self.assertRaises(ValueError):
            RedFlagEvidenceRequirement(
                concept_code="chest_pain",
                accepted_assertion_statuses=(),
            )

    def test_evidence_rejects_duplicate_assertion_statuses(
        self,
    ) -> None:
        with self.assertRaises(ValueError):
            RedFlagEvidenceRequirement(
                concept_code="chest_pain",
                accepted_assertion_statuses=(
                    AssertionStatus.PRESENT,
                    AssertionStatus.PRESENT,
                ),
            )

    def test_evidence_rejects_non_assertion_status(
        self,
    ) -> None:
        with self.assertRaises(TypeError):
            RedFlagEvidenceRequirement(
                concept_code="chest_pain",
                accepted_assertion_statuses=("present",),
            )

    def test_rule_rejects_invalid_rule_id(self) -> None:
        evidence = self._make_evidence()

        with self.assertRaises(ValueError):
            RedFlagRule(
                rule_id="Invalid Rule ID",
                version=1,
                required_evidence=(evidence,),
                urgency=RedFlagUrgency.EMERGENCY,
                warning_key="red_flags.invalid_rule",
            )

    def test_rule_rejects_boolean_version(self) -> None:
        evidence = self._make_evidence()

        with self.assertRaises(TypeError):
            RedFlagRule(
                rule_id="test_rule",
                version=True,
                required_evidence=(evidence,),
                urgency=RedFlagUrgency.EMERGENCY,
                warning_key="red_flags.test_rule",
            )

    def test_rule_requires_evidence_tuple(self) -> None:
        evidence = self._make_evidence()

        with self.assertRaises(TypeError):
            RedFlagRule(
                rule_id="test_rule",
                version=1,
                required_evidence=[evidence],
                urgency=RedFlagUrgency.EMERGENCY,
                warning_key="red_flags.test_rule",
            )

    def test_rule_rejects_duplicate_concept_codes(
        self,
    ) -> None:
        evidence = self._make_evidence()

        with self.assertRaises(ValueError):
            RedFlagRule(
                rule_id="test_rule",
                version=1,
                required_evidence=(evidence, evidence),
                urgency=RedFlagUrgency.EMERGENCY,
                warning_key="red_flags.test_rule",
            )

    def test_rule_rejects_non_urgency_value(self) -> None:
        evidence = self._make_evidence()

        with self.assertRaises(TypeError):
            RedFlagRule(
                rule_id="test_rule",
                version=1,
                required_evidence=(evidence,),
                urgency="emergency",
                warning_key="red_flags.test_rule",
            )

    def test_rule_rejects_invalid_warning_key(self) -> None:
        evidence = self._make_evidence()

        with self.assertRaises(ValueError):
            RedFlagRule(
                rule_id="test_rule",
                version=1,
                required_evidence=(evidence,),
                urgency=RedFlagUrgency.EMERGENCY,
                warning_key="red_flags",
            )

    def test_registry_rejects_duplicate_rule_ids(
        self,
    ) -> None:
        rule = self._make_rule()

        with self.assertRaises(ValueError):
            RedFlagRuleRegistry(
                rules=(rule, rule),
                concept_registry=CONCEPT_LEXICON,
            )

    def test_registry_rejects_unknown_concept_code(
        self,
    ) -> None:
        rule = self._make_rule(
            concept_code="unknown_medical_concept",
        )

        with self.assertRaises(ValueError):
            RedFlagRuleRegistry(
                rules=(rule,),
                concept_registry=CONCEPT_LEXICON,
            )

    def test_registry_require_rejects_unknown_rule_id(
        self,
    ) -> None:
        registry = RedFlagRuleRegistry(
            rules=(),
            concept_registry=CONCEPT_LEXICON,
        )

        self.assertIsNone(registry.get("unknown_rule"))

        with self.assertRaises(KeyError):
            registry.require("unknown_rule")

    def test_rule_and_registry_are_immutable(self) -> None:
        rule = self._make_rule()
        registry = RedFlagRuleRegistry(
            rules=(rule,),
            concept_registry=CONCEPT_LEXICON,
        )

        with self.assertRaises(FrozenInstanceError):
            rule.version = 2

        with self.assertRaises(FrozenInstanceError):
            registry.rules = ()

        with self.assertRaises(TypeError):
            registry._rules_by_id["another_rule"] = rule


class RedFlagRuleEvaluationEngineTests(SimpleTestCase):
    def _make_requirement(
        self,
        concept_code: str,
        accepted_statuses: tuple[AssertionStatus, ...] = (
            AssertionStatus.PRESENT,
        ),
    ) -> RedFlagEvidenceRequirement:
        return RedFlagEvidenceRequirement(
            concept_code=concept_code,
            accepted_assertion_statuses=accepted_statuses,
        )

    def _make_rule(
        self,
        *,
        rule_id: str,
        requirements: tuple[RedFlagEvidenceRequirement, ...],
        urgency: RedFlagUrgency = RedFlagUrgency.EMERGENCY,
    ) -> RedFlagRule:
        return RedFlagRule(
            rule_id=rule_id,
            version=1,
            required_evidence=requirements,
            urgency=urgency,
            warning_key=f"red_flags.test.{rule_id}",
        )

    def _make_registry(
        self,
        *rules: RedFlagRule,
    ) -> RedFlagRuleRegistry:
        return RedFlagRuleRegistry(
            rules=rules,
            concept_registry=CONCEPT_LEXICON,
        )

    def _evaluate(
        self,
        text: str,
        *rules: RedFlagRule,
    ):
        concept_result = match_medical_concepts(text)
        assertion_result = detect_assertions(concept_result)

        return evaluate_red_flag_rules(
            assertion_result=assertion_result,
            rule_registry=self._make_registry(*rules),
        )

    def test_single_requirement_rule_matches_and_preserves_evidence(
        self,
    ) -> None:
        text = "I have Chest pain."

        rule = self._make_rule(
            rule_id="single_chest_pain_rule",
            requirements=(
                self._make_requirement("chest_pain"),
            ),
        )

        result = self._evaluate(text, rule)

        self.assertTrue(result.matched)
        self.assertEqual(
            result.language,
            DetectedLanguage.ENGLISH,
        )
        self.assertEqual(
            result.highest_urgency,
            RedFlagUrgency.EMERGENCY,
        )
        self.assertTrue(result.must_override_model)
        self.assertTrue(result.should_short_circuit_llm)
        self.assertEqual(len(result.matches), 1)

        rule_match = result.matches[0]

        self.assertEqual(
            rule_match.rule_id,
            "single_chest_pain_rule",
        )
        self.assertEqual(rule_match.rule_version, 1)
        self.assertEqual(len(rule_match.evidence), 1)

        evidence = rule_match.evidence[0]
        expected_start = text.index("Chest pain")
        expected_end = expected_start + len("Chest pain")

        self.assertEqual(evidence.concept_code, "chest_pain")
        self.assertEqual(evidence.matched_text, "Chest pain")
        self.assertEqual(
            evidence.assertion,
            AssertionStatus.PRESENT,
        )
        self.assertEqual(evidence.start_char, expected_start)
        self.assertEqual(evidence.end_char, expected_end)
        self.assertEqual(evidence.segment_index, 0)
        self.assertEqual(
            text[evidence.start_char:evidence.end_char],
            evidence.matched_text,
        )

    def test_rule_uses_and_semantics_for_all_requirements(
        self,
    ) -> None:
        rule = self._make_rule(
            rule_id="chest_pain_with_breathing_rule",
            requirements=(
                self._make_requirement("chest_pain"),
                self._make_requirement("shortness_of_breath"),
            ),
        )

        result = self._evaluate(
            "I have chest pain and shortness of breath.",
            rule,
        )

        self.assertTrue(result.matched)
        self.assertEqual(len(result.matches), 1)
        self.assertEqual(
            tuple(
                evidence.concept_code
                for evidence in result.matches[0].evidence
            ),
            (
                "chest_pain",
                "shortness_of_breath",
            ),
        )

    def test_rule_does_not_match_when_requirement_is_missing(
        self,
    ) -> None:
        rule = self._make_rule(
            rule_id="missing_breathing_evidence_rule",
            requirements=(
                self._make_requirement("chest_pain"),
                self._make_requirement("shortness_of_breath"),
            ),
        )

        result = self._evaluate(
            "I have chest pain.",
            rule,
        )

        self.assertFalse(result.matched)
        self.assertEqual(result.matches, ())
        self.assertIsNone(result.highest_urgency)
        self.assertFalse(result.must_override_model)
        self.assertFalse(result.should_short_circuit_llm)

    def test_negated_evidence_does_not_satisfy_present_requirement(
        self,
    ) -> None:
        rule = self._make_rule(
            rule_id="negated_breathing_rule",
            requirements=(
                self._make_requirement("chest_pain"),
                self._make_requirement("shortness_of_breath"),
            ),
        )

        result = self._evaluate(
            (
                "I have chest pain but I do not have "
                "shortness of breath."
            ),
            rule,
        )

        self.assertFalse(result.matched)
        self.assertEqual(result.matches, ())

    def test_requirement_uses_configured_assertion_statuses(
        self,
    ) -> None:
        test_only_rule = self._make_rule(
            rule_id="test_negated_status_rule",
            requirements=(
                self._make_requirement(
                    "chest_pain",
                    accepted_statuses=(
                        AssertionStatus.NEGATED,
                    ),
                ),
            ),
            urgency=RedFlagUrgency.URGENT,
        )

        result = self._evaluate(
            "I do not have chest pain.",
            test_only_rule,
        )

        self.assertTrue(result.matched)
        self.assertEqual(
            result.matches[0].evidence[0].assertion,
            AssertionStatus.NEGATED,
        )
        self.assertEqual(
            result.highest_urgency,
            RedFlagUrgency.URGENT,
        )
        self.assertFalse(result.should_short_circuit_llm)

    def test_multiple_rules_match_in_registry_order(
        self,
    ) -> None:
        breathing_rule = self._make_rule(
            rule_id="first_breathing_rule",
            requirements=(
                self._make_requirement("shortness_of_breath"),
            ),
            urgency=RedFlagUrgency.URGENT,
        )

        chest_rule = self._make_rule(
            rule_id="second_chest_rule",
            requirements=(
                self._make_requirement("chest_pain"),
            ),
            urgency=RedFlagUrgency.EMERGENCY,
        )

        result = self._evaluate(
            "I have chest pain and shortness of breath.",
            breathing_rule,
            chest_rule,
        )

        self.assertEqual(
            tuple(match.rule_id for match in result.matches),
            (
                "first_breathing_rule",
                "second_chest_rule",
            ),
        )
        self.assertEqual(
            result.highest_urgency,
            RedFlagUrgency.EMERGENCY,
        )

    def test_duplicate_occurrences_produce_one_evidence_item(
        self,
    ) -> None:
        text = "Chest pain, then chest pain."

        rule = self._make_rule(
            rule_id="duplicate_chest_occurrence_rule",
            requirements=(
                self._make_requirement("chest_pain"),
            ),
        )

        result = self._evaluate(text, rule)

        self.assertTrue(result.matched)
        self.assertEqual(len(result.matches[0].evidence), 1)

        evidence = result.matches[0].evidence[0]

        self.assertEqual(evidence.matched_text, "Chest pain")
        self.assertEqual(evidence.start_char, 0)
        self.assertEqual(evidence.end_char, len("Chest pain"))

    def test_mixed_language_is_detected_deterministically(
        self,
    ) -> None:
        rule = self._make_rule(
            rule_id="mixed_language_rule",
            requirements=(
                self._make_requirement("chest_pain"),
                self._make_requirement("shortness_of_breath"),
            ),
        )

        result = self._evaluate(
            (
                f"{ARABIC_CHEST_PAIN} "
                "and shortness of breath."
            ),
            rule,
        )

        self.assertTrue(result.matched)
        self.assertEqual(
            result.language,
            DetectedLanguage.MIXED,
        )

    def test_unknown_language_when_no_concepts_are_matched(
        self,
    ) -> None:
        result = self._evaluate(
            "The sky is blue.",
        )

        self.assertFalse(result.matched)
        self.assertEqual(result.matches, ())
        self.assertEqual(
            result.language,
            DetectedLanguage.UNKNOWN,
        )

    def test_invalid_assertion_result_type_is_rejected(
        self,
    ) -> None:
        registry = self._make_registry()

        with self.assertRaisesRegex(
            TypeError,
            (
                "assertion_result must be an "
                "AssertionDetectionResult instance"
            ),
        ):
            evaluate_red_flag_rules(
                assertion_result="invalid assertion result",
                rule_registry=registry,
            )

    def test_invalid_rule_registry_type_is_rejected(
        self,
    ) -> None:
        assertion_result = detect_assertions(
            match_medical_concepts("I have chest pain.")
        )

        with self.assertRaisesRegex(
            TypeError,
            (
                "rule_registry must be a "
                "RedFlagRuleRegistry instance"
            ),
        ):
            evaluate_red_flag_rules(
                assertion_result=assertion_result,
                rule_registry="invalid registry",
            )

class RedFlagPipelineIntegrationTests(SimpleTestCase):
    def _make_requirement(
        self,
        concept_code: str,
        accepted_statuses: tuple[AssertionStatus, ...] = (
            AssertionStatus.PRESENT,
        ),
    ) -> RedFlagEvidenceRequirement:
        return RedFlagEvidenceRequirement(
            concept_code=concept_code,
            accepted_assertion_statuses=accepted_statuses,
        )

    def _make_rule(
        self,
        *,
        rule_id: str,
        requirements: tuple[RedFlagEvidenceRequirement, ...],
        urgency: RedFlagUrgency = RedFlagUrgency.EMERGENCY,
    ) -> RedFlagRule:
        return RedFlagRule(
            rule_id=rule_id,
            version=1,
            required_evidence=requirements,
            urgency=urgency,
            warning_key=f"red_flags.pipeline_test.{rule_id}",
        )

    def _make_registry(
        self,
        *rules: RedFlagRule,
    ) -> RedFlagRuleRegistry:
        return RedFlagRuleRegistry(
            rules=rules,
            concept_registry=CONCEPT_LEXICON,
        )

    def test_pipeline_matches_rule_from_raw_patient_text(
        self,
    ) -> None:
        text = "I have chest pain and shortness of breath."

        rule = self._make_rule(
            rule_id="pipeline_chest_breathing_rule",
            requirements=(
                self._make_requirement("chest_pain"),
                self._make_requirement("shortness_of_breath"),
            ),
        )

        result = check_red_flags(
            text,
            rule_registry=self._make_registry(rule),
        )

        self.assertTrue(result.matched)
        self.assertEqual(len(result.matches), 1)
        self.assertEqual(
            result.matches[0].rule_id,
            "pipeline_chest_breathing_rule",
        )
        self.assertEqual(
            tuple(
                evidence.concept_code
                for evidence in result.matches[0].evidence
            ),
            (
                "chest_pain",
                "shortness_of_breath",
            ),
        )
        self.assertEqual(
            result.language,
            DetectedLanguage.ENGLISH,
        )
        self.assertEqual(
            result.highest_urgency,
            RedFlagUrgency.EMERGENCY,
        )
        self.assertTrue(result.must_override_model)
        self.assertTrue(result.should_short_circuit_llm)

    def test_pipeline_does_not_match_negated_required_evidence(
        self,
    ) -> None:
        rule = self._make_rule(
            rule_id="pipeline_negated_rule",
            requirements=(
                self._make_requirement("chest_pain"),
                self._make_requirement("shortness_of_breath"),
            ),
        )

        result = check_red_flags(
            (
                "I have chest pain but I do not have "
                "shortness of breath."
            ),
            rule_registry=self._make_registry(rule),
        )

        self.assertFalse(result.matched)
        self.assertEqual(result.matches, ())
        self.assertIsNone(result.highest_urgency)
        self.assertFalse(result.must_override_model)

    def test_pipeline_preserves_original_text_and_offsets(
        self,
    ) -> None:
        text = "Today I have Chest pain."

        rule = self._make_rule(
            rule_id="pipeline_offsets_rule",
            requirements=(
                self._make_requirement("chest_pain"),
            ),
        )

        result = check_red_flags(
            text,
            rule_registry=self._make_registry(rule),
        )

        evidence = result.matches[0].evidence[0]
        expected_start = text.index("Chest pain")
        expected_end = expected_start + len("Chest pain")

        self.assertEqual(evidence.matched_text, "Chest pain")
        self.assertEqual(evidence.start_char, expected_start)
        self.assertEqual(evidence.end_char, expected_end)
        self.assertEqual(
            text[evidence.start_char:evidence.end_char],
            evidence.matched_text,
        )

    def test_pipeline_supports_multiple_matches_in_registry_order(
        self,
    ) -> None:
        chest_rule = self._make_rule(
            rule_id="pipeline_first_chest_rule",
            requirements=(
                self._make_requirement("chest_pain"),
            ),
            urgency=RedFlagUrgency.URGENT,
        )

        breathing_rule = self._make_rule(
            rule_id="pipeline_second_breathing_rule",
            requirements=(
                self._make_requirement("shortness_of_breath"),
            ),
            urgency=RedFlagUrgency.EMERGENCY,
        )

        result = check_red_flags(
            "I have chest pain and shortness of breath.",
            rule_registry=self._make_registry(
                chest_rule,
                breathing_rule,
            ),
        )

        self.assertEqual(
            tuple(match.rule_id for match in result.matches),
            (
                "pipeline_first_chest_rule",
                "pipeline_second_breathing_rule",
            ),
        )
        self.assertEqual(
            result.highest_urgency,
            RedFlagUrgency.EMERGENCY,
        )

    def test_pipeline_returns_structured_empty_result(
        self,
    ) -> None:
        result = check_red_flags(
            "The weather is pleasant today.",
            rule_registry=self._make_registry(),
        )

        self.assertFalse(result.matched)
        self.assertEqual(result.matches, ())
        self.assertEqual(
            result.language,
            DetectedLanguage.UNKNOWN,
        )
        self.assertIsNone(result.highest_urgency)
        self.assertFalse(result.must_override_model)
        self.assertFalse(result.should_short_circuit_llm)

    def test_pipeline_rejects_non_string_patient_text(
        self,
    ) -> None:
        with self.assertRaisesRegex(
            TypeError,
            "patient_text must be a string",
        ):
            check_red_flags(
                123,
                rule_registry=self._make_registry(),
            )

    def test_pipeline_rejects_invalid_rule_registry(
        self,
    ) -> None:
        with self.assertRaisesRegex(
            TypeError,
            (
                "rule_registry must be a "
                "RedFlagRuleRegistry instance"
            ),
        ):
            check_red_flags(
                "I have chest pain.",
                rule_registry="invalid registry",
            )

class ProductionRedFlagRulebookTests(SimpleTestCase):
    def test_registry_contains_approved_rules_in_stable_order(
        self,
    ) -> None:
        self.assertEqual(
            APPROVED_RED_FLAG_RULES,
            (
                LOSS_OF_CONSCIOUSNESS_EMERGENCY,
                CHEST_PAIN_WITH_SHORTNESS_OF_BREATH_EMERGENCY,
            ),
        )

        self.assertEqual(
            RED_FLAG_RULE_REGISTRY.rule_ids,
            (
                "loss_of_consciousness_emergency",
                (
                    "chest_pain_with_"
                    "shortness_of_breath_emergency"
                ),
            ),
        )

        self.assertIs(
            RED_FLAG_RULE_REGISTRY.concept_registry,
            CONCEPT_LEXICON,
        )

    def test_loss_of_consciousness_rule_definition(
        self,
    ) -> None:
        rule = LOSS_OF_CONSCIOUSNESS_EMERGENCY

        self.assertEqual(
            rule.rule_id,
            "loss_of_consciousness_emergency",
        )
        self.assertEqual(rule.version, 1)
        self.assertEqual(
            rule.urgency,
            RedFlagUrgency.EMERGENCY,
        )
        self.assertEqual(
            rule.warning_key,
            "red_flags.loss_of_consciousness_emergency",
        )
        self.assertEqual(len(rule.required_evidence), 1)

        requirement = rule.required_evidence[0]

        self.assertEqual(
            requirement.concept_code,
            "loss_of_consciousness",
        )
        self.assertEqual(
            requirement.accepted_assertion_statuses,
            (AssertionStatus.PRESENT,),
        )

    def test_chest_pain_with_breathing_rule_definition(
        self,
    ) -> None:
        rule = (
            CHEST_PAIN_WITH_SHORTNESS_OF_BREATH_EMERGENCY
        )

        self.assertEqual(
            rule.rule_id,
            (
                "chest_pain_with_"
                "shortness_of_breath_emergency"
            ),
        )
        self.assertEqual(rule.version, 1)
        self.assertEqual(
            rule.urgency,
            RedFlagUrgency.EMERGENCY,
        )
        self.assertEqual(
            rule.warning_key,
            (
                "red_flags."
                "chest_pain_with_shortness_of_breath_emergency"
            ),
        )
        self.assertEqual(
            tuple(
                requirement.concept_code
                for requirement in rule.required_evidence
            ),
            (
                "chest_pain",
                "shortness_of_breath",
            ),
        )

        for requirement in rule.required_evidence:
            self.assertEqual(
                requirement.accepted_assertion_statuses,
                (AssertionStatus.PRESENT,),
            )

    def test_english_loss_of_consciousness_matches(
        self,
    ) -> None:
        text = "I have loss of consciousness."

        result = check_red_flags(
            text,
            rule_registry=RED_FLAG_RULE_REGISTRY,
        )

        self.assertTrue(result.matched)
        self.assertEqual(
            tuple(match.rule_id for match in result.matches),
            ("loss_of_consciousness_emergency",),
        )
        self.assertEqual(
            result.highest_urgency,
            RedFlagUrgency.EMERGENCY,
        )
        self.assertTrue(result.must_override_model)
        self.assertTrue(result.should_short_circuit_llm)

        evidence = result.matches[0].evidence[0]

        self.assertEqual(
            evidence.concept_code,
            "loss_of_consciousness",
        )
        self.assertEqual(
            evidence.matched_text,
            "loss of consciousness",
        )
        self.assertEqual(
            evidence.assertion,
            AssertionStatus.PRESENT,
        )
        self.assertEqual(
            text[evidence.start_char:evidence.end_char],
            evidence.matched_text,
        )

    def test_arabic_loss_of_consciousness_matches(
        self,
    ) -> None:
        text = (
            "\u0639\u0646\u062f\u064a "
            f"{ARABIC_LOSS_OF_CONSCIOUSNESS}"
        )

        result = check_red_flags(
            text,
            rule_registry=RED_FLAG_RULE_REGISTRY,
        )

        self.assertTrue(result.matched)
        self.assertEqual(
            tuple(match.rule_id for match in result.matches),
            ("loss_of_consciousness_emergency",),
        )
        self.assertEqual(
            result.language,
            DetectedLanguage.ARABIC,
        )

        evidence = result.matches[0].evidence[0]

        self.assertEqual(
            evidence.matched_text,
            ARABIC_LOSS_OF_CONSCIOUSNESS,
        )
        self.assertEqual(
            evidence.assertion,
            AssertionStatus.PRESENT,
        )

    def test_negated_loss_of_consciousness_does_not_match(
        self,
    ) -> None:
        result = check_red_flags(
            "I do not have loss of consciousness.",
            rule_registry=RED_FLAG_RULE_REGISTRY,
        )

        self.assertFalse(result.matched)
        self.assertEqual(result.matches, ())
        self.assertIsNone(result.highest_urgency)
        self.assertFalse(result.must_override_model)

    def test_chest_pain_with_shortness_of_breath_matches(
        self,
    ) -> None:
        result = check_red_flags(
            "I have chest pain and shortness of breath.",
            rule_registry=RED_FLAG_RULE_REGISTRY,
        )

        self.assertTrue(result.matched)
        self.assertEqual(
            tuple(match.rule_id for match in result.matches),
            (
                (
                    "chest_pain_with_"
                    "shortness_of_breath_emergency"
                ),
            ),
        )
        self.assertEqual(
            tuple(
                evidence.concept_code
                for evidence in result.matches[0].evidence
            ),
            (
                "chest_pain",
                "shortness_of_breath",
            ),
        )

    def test_combination_rule_requires_both_concepts(
        self,
    ) -> None:
        result = check_red_flags(
            "I have chest pain.",
            rule_registry=RED_FLAG_RULE_REGISTRY,
        )

        self.assertFalse(result.matched)
        self.assertEqual(result.matches, ())

    def test_negated_combination_evidence_prevents_match(
        self,
    ) -> None:
        result = check_red_flags(
            (
                "I have chest pain but I do not have "
                "shortness of breath."
            ),
            rule_registry=RED_FLAG_RULE_REGISTRY,
        )

        self.assertFalse(result.matched)
        self.assertEqual(result.matches, ())

    def test_multiple_production_rules_match_in_registry_order(
        self,
    ) -> None:
        result = check_red_flags(
            (
                "I have loss of consciousness, chest pain, "
                "and shortness of breath."
            ),
            rule_registry=RED_FLAG_RULE_REGISTRY,
        )

        self.assertEqual(
            tuple(match.rule_id for match in result.matches),
            (
                "loss_of_consciousness_emergency",
                (
                    "chest_pain_with_"
                    "shortness_of_breath_emergency"
                ),
            ),
        )
        self.assertEqual(
            result.highest_urgency,
            RedFlagUrgency.EMERGENCY,
        )
        self.assertTrue(result.must_override_model)
        self.assertTrue(result.should_short_circuit_llm)

class ResponsePolicyTests(SimpleTestCase):
    def _make_requirement(
        self,
        concept_code: str,
    ) -> RedFlagEvidenceRequirement:
        return RedFlagEvidenceRequirement(
            concept_code=concept_code,
            accepted_assertion_statuses=(
                AssertionStatus.PRESENT,
            ),
        )

    def _make_rule(
        self,
        *,
        rule_id: str,
        concept_code: str,
        urgency: RedFlagUrgency,
    ) -> RedFlagRule:
        return RedFlagRule(
            rule_id=rule_id,
            version=1,
            required_evidence=(
                self._make_requirement(concept_code),
            ),
            urgency=urgency,
            warning_key=(
                f"red_flags.response_policy_test.{rule_id}"
            ),
        )

    def _make_registry(
        self,
        *rules: RedFlagRule,
    ) -> RedFlagRuleRegistry:
        return RedFlagRuleRegistry(
            rules=rules,
            concept_registry=CONCEPT_LEXICON,
        )

    def test_no_match_returns_continue_decision(
        self,
    ) -> None:
        red_flag_result = check_red_flags(
            "The weather is pleasant today.",
            rule_registry=self._make_registry(),
        )

        decision = apply_response_policy(
            red_flag_result
        )

        self.assertEqual(
            decision.decision,
            SafetyDecisionType.CONTINUE,
        )
        self.assertEqual(decision.reasons, ())
        self.assertIsNone(decision.highest_urgency)
        self.assertFalse(decision.must_override_model)
        self.assertFalse(
            decision.should_short_circuit_llm
        )
        self.assertEqual(decision.warning_keys, ())
        self.assertIsNone(
            decision.primary_warning_key
        )
        self.assertEqual(
            decision.source_engine_version,
            red_flag_result.engine_version,
        )
        self.assertEqual(
            decision.policy_version,
            RESPONSE_POLICY_VERSION,
        )

    def test_urgent_match_returns_urgent_decision(
        self,
    ) -> None:
        urgent_rule = self._make_rule(
            rule_id="urgent_chest_pain_rule",
            concept_code="chest_pain",
            urgency=RedFlagUrgency.URGENT,
        )

        red_flag_result = check_red_flags(
            "I have chest pain.",
            rule_registry=self._make_registry(
                urgent_rule
            ),
        )

        decision = apply_response_policy(
            red_flag_result
        )

        self.assertEqual(
            decision.decision,
            SafetyDecisionType.URGENT,
        )
        self.assertEqual(
            decision.highest_urgency,
            RedFlagUrgency.URGENT,
        )
        self.assertTrue(
            decision.must_override_model
        )
        self.assertFalse(
            decision.should_short_circuit_llm
        )
        self.assertEqual(len(decision.reasons), 1)
        self.assertEqual(
            decision.reasons[0].rule_id,
            "urgent_chest_pain_rule",
        )
        self.assertEqual(
            decision.primary_warning_key,
            (
                "red_flags.response_policy_test."
                "urgent_chest_pain_rule"
            ),
        )

    def test_emergency_match_short_circuits_llm(
        self,
    ) -> None:
        emergency_rule = self._make_rule(
            rule_id="emergency_breathing_rule",
            concept_code="shortness_of_breath",
            urgency=RedFlagUrgency.EMERGENCY,
        )

        red_flag_result = check_red_flags(
            "I have shortness of breath.",
            rule_registry=self._make_registry(
                emergency_rule
            ),
        )

        decision = apply_response_policy(
            red_flag_result
        )

        self.assertEqual(
            decision.decision,
            SafetyDecisionType.EMERGENCY,
        )
        self.assertEqual(
            decision.highest_urgency,
            RedFlagUrgency.EMERGENCY,
        )
        self.assertTrue(
            decision.must_override_model
        )
        self.assertTrue(
            decision.should_short_circuit_llm
        )
        self.assertEqual(
            decision.reasons[0].urgency,
            RedFlagUrgency.EMERGENCY,
        )

    def test_multiple_matches_preserve_all_reasons(
        self,
    ) -> None:
        urgent_rule = self._make_rule(
            rule_id="z_urgent_chest_rule",
            concept_code="chest_pain",
            urgency=RedFlagUrgency.URGENT,
        )
        emergency_rule = self._make_rule(
            rule_id="a_emergency_breathing_rule",
            concept_code="shortness_of_breath",
            urgency=RedFlagUrgency.EMERGENCY,
        )

        red_flag_result = check_red_flags(
            "I have chest pain and shortness of breath.",
            rule_registry=self._make_registry(
                urgent_rule,
                emergency_rule,
            ),
        )

        decision = apply_response_policy(
            red_flag_result
        )

        self.assertEqual(
            decision.decision,
            SafetyDecisionType.EMERGENCY,
        )
        self.assertEqual(
            tuple(
                reason.rule_id
                for reason in decision.reasons
            ),
            (
                "a_emergency_breathing_rule",
                "z_urgent_chest_rule",
            ),
        )
        self.assertEqual(
            tuple(
                reason.urgency
                for reason in decision.reasons
            ),
            (
                RedFlagUrgency.EMERGENCY,
                RedFlagUrgency.URGENT,
            ),
        )
        self.assertEqual(
            decision.primary_warning_key,
            (
                "red_flags.response_policy_test."
                "a_emergency_breathing_rule"
            ),
        )

    def test_match_order_does_not_change_decision_output(
        self,
    ) -> None:
        z_rule = self._make_rule(
            rule_id="z_urgent_rule",
            concept_code="chest_pain",
            urgency=RedFlagUrgency.URGENT,
        )
        a_rule = self._make_rule(
            rule_id="a_urgent_rule",
            concept_code="shortness_of_breath",
            urgency=RedFlagUrgency.URGENT,
        )

        text = (
            "I have chest pain and "
            "shortness of breath."
        )

        first_result = check_red_flags(
            text,
            rule_registry=self._make_registry(
                z_rule,
                a_rule,
            ),
        )
        second_result = check_red_flags(
            text,
            rule_registry=self._make_registry(
                a_rule,
                z_rule,
            ),
        )

        first_decision = apply_response_policy(
            first_result
        )
        second_decision = apply_response_policy(
            second_result
        )

        self.assertEqual(
            first_decision,
            second_decision,
        )
        self.assertEqual(
            tuple(
                reason.rule_id
                for reason in first_decision.reasons
            ),
            (
                "a_urgent_rule",
                "z_urgent_rule",
            ),
        )

    def test_invalid_input_is_rejected(
        self,
    ) -> None:
        with self.assertRaisesRegex(
            TypeError,
            (
                "red_flag_result must be a "
                "RedFlagCheckResult instance"
            ),
        ):
            apply_response_policy(
                "invalid result"
            )

    def test_structured_decision_is_immutable(
        self,
    ) -> None:
        red_flag_result = check_red_flags(
            "No relevant symptoms.",
            rule_registry=self._make_registry(),
        )
        decision = apply_response_policy(
            red_flag_result
        )

        with self.assertRaises(
            FrozenInstanceError
        ):
            decision.decision = (
                SafetyDecisionType.EMERGENCY
            )


class SafetyGateTests(SimpleTestCase):
    def _make_urgent_registry(
        self,
    ) -> RedFlagRuleRegistry:
        urgent_rule = RedFlagRule(
            rule_id="safety_gate_urgent_chest_pain",
            version=1,
            required_evidence=(
                RedFlagEvidenceRequirement(
                    concept_code="chest_pain",
                    accepted_assertion_statuses=(
                        AssertionStatus.PRESENT,
                    ),
                ),
            ),
            urgency=RedFlagUrgency.URGENT,
            warning_key=(
                "red_flags.safety_gate_test."
                "urgent_chest_pain"
            ),
        )

        return RedFlagRuleRegistry(
            rules=(urgent_rule,),
            concept_registry=CONCEPT_LEXICON,
        )

    def test_default_registry_returns_continue_decision(
        self,
    ) -> None:
        decision = evaluate_chat_safety(
            "The weather is pleasant today."
        )

        self.assertEqual(
            decision.decision,
            SafetyDecisionType.CONTINUE,
        )
        self.assertEqual(decision.reasons, ())
        self.assertIsNone(decision.highest_urgency)
        self.assertFalse(decision.must_override_model)
        self.assertFalse(
            decision.should_short_circuit_llm
        )
        self.assertIsNone(
            decision.primary_warning_key
        )

    def test_default_registry_returns_emergency_decision(
        self,
    ) -> None:
        decision = evaluate_chat_safety(
            "I have loss of consciousness."
        )

        self.assertEqual(
            decision.decision,
            SafetyDecisionType.EMERGENCY,
        )
        self.assertEqual(
            decision.highest_urgency,
            RedFlagUrgency.EMERGENCY,
        )
        self.assertTrue(decision.must_override_model)
        self.assertTrue(
            decision.should_short_circuit_llm
        )
        self.assertEqual(
            decision.primary_warning_key,
            "red_flags.loss_of_consciousness_emergency",
        )

    def test_custom_registry_can_be_injected(
        self,
    ) -> None:
        decision = evaluate_chat_safety(
            "I have chest pain.",
            rule_registry=self._make_urgent_registry(),
        )

        self.assertEqual(
            decision.decision,
            SafetyDecisionType.URGENT,
        )
        self.assertEqual(
            decision.highest_urgency,
            RedFlagUrgency.URGENT,
        )
        self.assertTrue(decision.must_override_model)
        self.assertFalse(
            decision.should_short_circuit_llm
        )
        self.assertEqual(
            decision.primary_warning_key,
            (
                "red_flags.safety_gate_test."
                "urgent_chest_pain"
            ),
        )

    def test_result_does_not_expose_raw_evidence(
        self,
    ) -> None:
        decision = evaluate_chat_safety(
            "I have loss of consciousness."
        )

        self.assertFalse(
            hasattr(decision, "matches")
        )
        self.assertFalse(
            hasattr(decision, "evidence")
        )
        self.assertFalse(
            hasattr(decision, "matched_text")
        )

        for reason in decision.reasons:
            self.assertFalse(
                hasattr(reason, "evidence")
            )
            self.assertFalse(
                hasattr(reason, "matched_text")
            )

    def test_invalid_patient_text_is_rejected(
        self,
    ) -> None:
        with self.assertRaisesRegex(
            TypeError,
            "patient_text must be a string",
        ):
            evaluate_chat_safety(123)

    def test_invalid_rule_registry_is_rejected(
        self,
    ) -> None:
        with self.assertRaisesRegex(
            TypeError,
            (
                "rule_registry must be a "
                "RedFlagRuleRegistry instance"
            ),
        ):
            evaluate_chat_safety(
                "I have chest pain.",
                rule_registry="invalid registry",
            )
