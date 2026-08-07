import json

from django.test import TestCase

from doctors.models import Specialty

from .models import (
    ChatMessage,
    ChatSession,
    ConversationClinicalState,
)
from .services.ai.schemas import TriageResponse
from .services.chat_orchestrator import (
    ChatExecutionPath,
    ChatOrchestrationResult,
)
from .services.clinical_state import persist_clinical_state
from .services.triage.red_flags.response_policy import (
    SafetyDecisionReason,
    SafetyDecisionType,
    StructuredSafetyDecision,
)
from .services.triage.red_flags.schemas import RedFlagUrgency


class ClinicalStatePersistenceTests(TestCase):
    def setUp(self):
        self.session = ChatSession.objects.create(
            title="Clinical state persistence test",
        )
        self.message = ChatMessage.objects.create(
            session=self.session,
            sender=ChatMessage.Sender.USER,
            content="I have been feeling unwell.",
        )
        self.specialty = Specialty.objects.create(
            code="clinical_state_test_specialty",
            name_ar="اختصاص اختبار الحالة السريرية",
            name_en="Clinical State Test Specialty",
            is_active=True,
        )

    def make_continue_decision(
        self,
    ) -> StructuredSafetyDecision:
        return StructuredSafetyDecision(
            decision=SafetyDecisionType.CONTINUE,
            reasons=(),
            highest_urgency=None,
            must_override_model=False,
            should_short_circuit_llm=False,
            source_engine_version=(
                "clinical-state-test-engine-v1"
            ),
        )

    def make_urgent_decision(
        self,
    ) -> StructuredSafetyDecision:
        reason = SafetyDecisionReason(
            rule_id="clinical_state_test_urgent",
            rule_version=1,
            urgency=RedFlagUrgency.URGENT,
            warning_key="red_flags.clinical_state_test.urgent",
        )

        return StructuredSafetyDecision(
            decision=SafetyDecisionType.URGENT,
            reasons=(reason,),
            highest_urgency=RedFlagUrgency.URGENT,
            must_override_model=True,
            should_short_circuit_llm=False,
            source_engine_version=(
                "clinical-state-test-engine-v1"
            ),
        )

    def make_emergency_decision(
        self,
    ) -> StructuredSafetyDecision:
        reason = SafetyDecisionReason(
            rule_id="clinical_state_test_emergency",
            rule_version=1,
            urgency=RedFlagUrgency.EMERGENCY,
            warning_key=(
                "red_flags.clinical_state_test.emergency"
            ),
        )

        return StructuredSafetyDecision(
            decision=SafetyDecisionType.EMERGENCY,
            reasons=(reason,),
            highest_urgency=RedFlagUrgency.EMERGENCY,
            must_override_model=True,
            should_short_circuit_llm=True,
            source_engine_version=(
                "clinical-state-test-engine-v1"
            ),
        )

    def make_triage_response(
        self,
        *,
        urgency: str = "routine",
        suggested_specialty_code: str | None = None,
    ) -> TriageResponse:
        return TriageResponse(
            symptom_summary=(
                "The patient reported a test symptom.",
            ),
            follow_up_questions=(
                "How long have you had this symptom?",
            ),
            urgency=urgency,
            suggested_specialty_code=suggested_specialty_code,
            needs_more_information=False,
            emergency_warning=None,
            safety_disclaimer=(
                "This is preliminary medical guidance and "
                "not a final diagnosis."
            ),
        )

    def make_ai_result(
        self,
        *,
        triage_response: TriageResponse,
        safety_decision: StructuredSafetyDecision | None = None,
    ) -> ChatOrchestrationResult:
        if safety_decision is None:
            safety_decision = self.make_continue_decision()

        return ChatOrchestrationResult(
            execution_path=ChatExecutionPath.AI_PROVIDER,
            safety_decision=safety_decision,
            triage_response=triage_response,
        )

    def test_persists_ai_provider_clinical_state(self):
        triage_response = self.make_triage_response(
            urgency="soon",
            suggested_specialty_code=self.specialty.code,
        )
        result = self.make_ai_result(
            triage_response=triage_response,
        )

        state = persist_clinical_state(
            session=self.session,
            last_processed_message=self.message,
            orchestration_result=result,
        )

        self.assertEqual(
            ConversationClinicalState.objects.count(),
            1,
        )
        self.assertEqual(state.session, self.session)
        self.assertEqual(
            state.last_processed_message,
            self.message,
        )
        self.assertEqual(state.schema_version, 1)
        self.assertEqual(state.urgency, "soon")
        self.assertEqual(state.safety_decision, "continue")
        self.assertEqual(
            state.execution_path,
            "ai_provider",
        )
        self.assertEqual(
            state.suggested_specialty,
            self.specialty,
        )
        self.assertEqual(
            state.suggested_specialty_code,
            self.specialty.code,
        )

    def test_updates_existing_snapshot_instead_of_creating_second_row(
        self,
    ):
        first_result = self.make_ai_result(
            triage_response=self.make_triage_response(
                urgency="routine",
                suggested_specialty_code=self.specialty.code,
            ),
        )

        first_state = persist_clinical_state(
            session=self.session,
            last_processed_message=self.message,
            orchestration_result=first_result,
        )

        second_message = ChatMessage.objects.create(
            session=self.session,
            sender=ChatMessage.Sender.USER,
            content="The symptoms are getting worse.",
        )

        urgent_result = self.make_ai_result(
            triage_response=self.make_triage_response(
                urgency="urgent",
                suggested_specialty_code=None,
            ),
            safety_decision=self.make_urgent_decision(),
        )

        second_state = persist_clinical_state(
            session=self.session,
            last_processed_message=second_message,
            orchestration_result=urgent_result,
        )

        self.assertEqual(first_state.pk, second_state.pk)
        self.assertEqual(
            ConversationClinicalState.objects.count(),
            1,
        )

        second_state.refresh_from_db()

        self.assertEqual(
            second_state.last_processed_message,
            second_message,
        )
        self.assertEqual(second_state.urgency, "urgent")
        self.assertEqual(
            second_state.safety_decision,
            "urgent",
        )
        self.assertIsNone(second_state.suggested_specialty)
        self.assertEqual(
            second_state.suggested_specialty_code,
            "",
        )

    def test_persists_final_urgent_triage_state(self):
        result = self.make_ai_result(
            triage_response=self.make_triage_response(
                urgency="urgent",
            ),
            safety_decision=self.make_urgent_decision(),
        )

        state = persist_clinical_state(
            session=self.session,
            last_processed_message=self.message,
            orchestration_result=result,
        )

        self.assertEqual(state.urgency, "urgent")
        self.assertEqual(
            state.safety_decision,
            "urgent",
        )

        safety = state.structured_state["safety"]

        self.assertEqual(
            safety["highest_urgency"],
            "urgent",
        )
        self.assertTrue(safety["must_override_model"])
        self.assertFalse(
            safety["should_short_circuit_llm"]
        )

    def test_persists_backend_emergency_without_triage_response(
        self,
    ):
        result = ChatOrchestrationResult(
            execution_path=(
                ChatExecutionPath.BACKEND_SAFETY_RESPONSE
            ),
            safety_decision=self.make_emergency_decision(),
            triage_response=None,
        )

        state = persist_clinical_state(
            session=self.session,
            last_processed_message=self.message,
            orchestration_result=result,
        )

        self.assertEqual(state.urgency, "emergency")
        self.assertEqual(
            state.safety_decision,
            "emergency",
        )
        self.assertEqual(
            state.execution_path,
            "backend_safety_response",
        )
        self.assertIsNone(state.suggested_specialty)
        self.assertEqual(
            state.suggested_specialty_code,
            "",
        )
        self.assertIsNone(
            state.structured_state["triage_response"]
        )

        safety = state.structured_state["safety"]

        self.assertEqual(
            safety["highest_urgency"],
            "emergency",
        )
        self.assertTrue(safety["must_override_model"])
        self.assertTrue(
            safety["should_short_circuit_llm"]
        )

    def test_structured_state_does_not_duplicate_canonical_columns(
        self,
    ):
        result = self.make_ai_result(
            triage_response=self.make_triage_response(
                urgency="soon",
                suggested_specialty_code=self.specialty.code,
            ),
        )

        state = persist_clinical_state(
            session=self.session,
            last_processed_message=self.message,
            orchestration_result=result,
        )

        triage = state.structured_state["triage_response"]
        safety = state.structured_state["safety"]

        self.assertNotIn("urgency", triage)
        self.assertNotIn(
            "suggested_specialty_code",
            triage,
        )
        self.assertNotIn("decision", safety)

    def test_structured_state_contains_no_raw_evidence_fields(self):
        result = self.make_ai_result(
            triage_response=self.make_triage_response(
                urgency="urgent",
            ),
            safety_decision=self.make_urgent_decision(),
        )

        state = persist_clinical_state(
            session=self.session,
            last_processed_message=self.message,
            orchestration_result=result,
        )

        serialized_state = json.dumps(
            state.structured_state,
            sort_keys=True,
        )

        forbidden_fields = (
            "matched_text",
            "start_char",
            "end_char",
            "segment_index",
            "raw_json",
        )

        for field in forbidden_fields:
            self.assertNotIn(field, serialized_state)

        reason = state.structured_state["safety"]["reasons"][0]

        self.assertEqual(
            reason,
            {
                "rule_id": "clinical_state_test_urgent",
                "rule_version": 1,
                "urgency": "urgent",
                "warning_key": (
                    "red_flags.clinical_state_test.urgent"
                ),
            },
        )

    def test_preserves_specialty_code_when_specialty_no_longer_exists(
        self,
    ):
        missing_code = "removed_specialty_snapshot"

        result = self.make_ai_result(
            triage_response=self.make_triage_response(
                urgency="routine",
                suggested_specialty_code=missing_code,
            ),
        )

        state = persist_clinical_state(
            session=self.session,
            last_processed_message=self.message,
            orchestration_result=result,
        )

        self.assertIsNone(state.suggested_specialty)
        self.assertEqual(
            state.suggested_specialty_code,
            missing_code,
        )

    def test_rejects_message_from_different_session(self):
        other_session = ChatSession.objects.create(
            title="Other clinical state session",
        )
        other_message = ChatMessage.objects.create(
            session=other_session,
            sender=ChatMessage.Sender.USER,
            content="Message from another session.",
        )

        result = self.make_ai_result(
            triage_response=self.make_triage_response(),
        )

        with self.assertRaisesMessage(
            ValueError,
            (
                "last_processed_message must belong to "
                "the supplied session."
            ),
        ):
            persist_clinical_state(
                session=self.session,
                last_processed_message=other_message,
                orchestration_result=result,
            )

        self.assertFalse(
            ConversationClinicalState.objects.exists()
        )

    def test_rejects_non_user_message(self):
        assistant_message = ChatMessage.objects.create(
            session=self.session,
            sender=ChatMessage.Sender.ASSISTANT,
            content="Assistant response.",
        )

        result = self.make_ai_result(
            triage_response=self.make_triage_response(),
        )

        with self.assertRaisesMessage(
            ValueError,
            "last_processed_message must be a user message.",
        ):
            persist_clinical_state(
                session=self.session,
                last_processed_message=assistant_message,
                orchestration_result=result,
            )

        self.assertFalse(
            ConversationClinicalState.objects.exists()
        )