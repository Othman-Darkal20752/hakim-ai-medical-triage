from django.test import SimpleTestCase

from .services.ai.schemas import TriageResponse
from .services.chat_orchestrator import (
    ChatExecutionPath,
    ChatOrchestrationResult,
)
from .services.reply_builder import build_patient_reply
from .services.triage.red_flags.response_policy import (
    SafetyDecisionReason,
    SafetyDecisionType,
    StructuredSafetyDecision,
)
from .services.triage.red_flags.schemas import RedFlagUrgency


class PatientReplyBuilderTests(SimpleTestCase):
    def _make_continue_decision(self) -> StructuredSafetyDecision:
        return StructuredSafetyDecision(
            decision=SafetyDecisionType.CONTINUE,
            reasons=(),
            highest_urgency=None,
            must_override_model=False,
            should_short_circuit_llm=False,
            source_engine_version="reply-builder-test-engine-v1",
        )

    def _make_emergency_decision(self) -> StructuredSafetyDecision:
        reason = SafetyDecisionReason(
            rule_id="reply_builder_test_emergency",
            rule_version=1,
            urgency=RedFlagUrgency.EMERGENCY,
            warning_key="red_flags.reply_builder_test.emergency",
        )

        return StructuredSafetyDecision(
            decision=SafetyDecisionType.EMERGENCY,
            reasons=(reason,),
            highest_urgency=RedFlagUrgency.EMERGENCY,
            must_override_model=True,
            should_short_circuit_llm=True,
            source_engine_version="reply-builder-test-engine-v1",
        )

    def test_backend_emergency_reply_is_controlled_by_backend_in_english(
        self,
    ) -> None:
        result = ChatOrchestrationResult(
            execution_path=(
                ChatExecutionPath.BACKEND_SAFETY_RESPONSE
            ),
            safety_decision=self._make_emergency_decision(),
            triage_response=None,
        )

        reply = build_patient_reply(
            orchestration_result=result,
            response_language="en",
        )

        self.assertIn(
            "may indicate a medical emergency",
            reply,
        )
        self.assertIn(
            "Seek immediate emergency medical care",
            reply,
        )
        self.assertIn(
            "preliminary medical guidance",
            reply,
        )
        self.assertNotIn(
            "red_flags.reply_builder_test.emergency",
            reply,
        )

    def test_backend_emergency_reply_is_controlled_by_backend_in_arabic(
        self,
    ) -> None:
        result = ChatOrchestrationResult(
            execution_path=(
                ChatExecutionPath.BACKEND_SAFETY_RESPONSE
            ),
            safety_decision=self._make_emergency_decision(),
            triage_response=None,
        )

        reply = build_patient_reply(
            orchestration_result=result,
            response_language="ar",
        )

        self.assertIn(
            "حالة طبية طارئة",
            reply,
        )
        self.assertIn(
            "الرعاية الطبية الإسعافية",
            reply,
        )
        self.assertIn(
            "إرشاد طبي أولي",
            reply,
        )
        self.assertNotIn(
            "red_flags.reply_builder_test.emergency",
            reply,
        )

    def test_ai_reply_uses_validated_patient_facing_fields(
        self,
    ) -> None:
        triage_response = TriageResponse(
            symptom_summary=(
                "Mild headache since this morning.",
            ),
            follow_up_questions=(
                "How severe is the headache?",
            ),
            urgency="routine",
            suggested_specialty_code="general_medicine",
            needs_more_information=False,
            emergency_warning=None,
            safety_disclaimer=(
                "This is preliminary medical guidance and "
                "not a final diagnosis."
            ),
        )

        result = ChatOrchestrationResult(
            execution_path=ChatExecutionPath.AI_PROVIDER,
            safety_decision=self._make_continue_decision(),
            triage_response=triage_response,
        )

        reply = build_patient_reply(
            orchestration_result=result,
            response_language="en",
            specialty_name="General Medicine",
        )

        self.assertIn(
            "Mild headache since this morning.",
            reply,
        )
        self.assertIn(
            "How severe is the headache?",
            reply,
        )
        self.assertIn(
            "General Medicine",
            reply,
        )
        self.assertIn(
            triage_response.safety_disclaimer,
            reply,
        )
        self.assertNotIn(
            "general_medicine",
            reply,
        )

    def test_ai_emergency_reply_uses_validated_emergency_warning(
        self,
    ) -> None:
        triage_response = TriageResponse(
            symptom_summary=(
                "The reported symptoms may require emergency care.",
            ),
            follow_up_questions=(),
            urgency="emergency",
            suggested_specialty_code=None,
            needs_more_information=False,
            emergency_warning=(
                "Seek immediate emergency medical care."
            ),
            safety_disclaimer=(
                "This is preliminary medical guidance and "
                "not a final diagnosis."
            ),
        )

        result = ChatOrchestrationResult(
            execution_path=ChatExecutionPath.AI_PROVIDER,
            safety_decision=self._make_continue_decision(),
            triage_response=triage_response,
        )

        reply = build_patient_reply(
            orchestration_result=result,
            response_language="en",
        )

        self.assertIn(
            triage_response.emergency_warning,
            reply,
        )
        self.assertIn(
            triage_response.safety_disclaimer,
            reply,
        )

    def test_unsupported_response_language_is_rejected(self) -> None:
        triage_response = TriageResponse(
            symptom_summary=("Test symptom.",),
            follow_up_questions=(),
            urgency="routine",
            suggested_specialty_code=None,
            needs_more_information=False,
            emergency_warning=None,
            safety_disclaimer=(
                "This is preliminary medical guidance and "
                "not a final diagnosis."
            ),
        )

        result = ChatOrchestrationResult(
            execution_path=ChatExecutionPath.AI_PROVIDER,
            safety_decision=self._make_continue_decision(),
            triage_response=triage_response,
        )

        with self.assertRaises(ValueError):
            build_patient_reply(
                orchestration_result=result,
                response_language="fr",
            )