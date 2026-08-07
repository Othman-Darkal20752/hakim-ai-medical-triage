from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.test import TestCase

from doctors.models import Specialty

from .models import (
    ChatMessage,
    ChatSession,
    ConversationClinicalState,
)


class ConversationClinicalStateModelTests(TestCase):
    def setUp(self):
        self.session = ChatSession.objects.create(
            title="Clinical test session",
        )
        self.message = ChatMessage.objects.create(
            session=self.session,
            sender=ChatMessage.Sender.USER,
            content="I have chest discomfort.",
        )
        self.specialty = Specialty.objects.create(
            code="test_specialty",
            name_ar="Test Specialty AR",
            name_en="Test Specialty",
            is_active=True,
        )

    def make_state(self, **overrides):
        values = {
            "session": self.session,
            "last_processed_message": self.message,
            "structured_state": {
                "triage_response": {
                    "urgency": "soon",
                },
                "safety": {
                    "decision": "continue",
                },
            },
            "urgency": (
                ConversationClinicalState.Urgency.SOON
            ),
            "safety_decision": (
                ConversationClinicalState.SafetyDecision.CONTINUE
            ),
            "execution_path": (
                ConversationClinicalState.ExecutionPath.AI_PROVIDER
            ),
        }
        values.update(overrides)

        return ConversationClinicalState(**values)

    def test_create_valid_ai_provider_state(self):
        state = self.make_state(
            suggested_specialty=self.specialty,
            suggested_specialty_code=self.specialty.code,
        )

        state.full_clean()
        state.save()

        self.assertEqual(state.schema_version, 1)
        self.assertEqual(state.session, self.session)
        self.assertEqual(
            state.last_processed_message,
            self.message,
        )
        self.assertEqual(
            state.suggested_specialty,
            self.specialty,
        )
        self.assertEqual(
            state.suggested_specialty_code,
            "test_specialty",
        )
        self.assertEqual(
            str(state),
            f"Clinical state - {self.session.pk}",
        )

    def test_create_valid_backend_emergency_state(self):
        state = self.make_state(
            structured_state={
                "triage_response": None,
                "safety": {
                    "decision": "emergency",
                },
            },
            urgency=(
                ConversationClinicalState.Urgency.EMERGENCY
            ),
            safety_decision=(
                ConversationClinicalState
                .SafetyDecision.EMERGENCY
            ),
            execution_path=(
                ConversationClinicalState
                .ExecutionPath.BACKEND_SAFETY_RESPONSE
            ),
            suggested_specialty=None,
            suggested_specialty_code="",
        )

        state.full_clean()
        state.save()

        self.assertIsNone(
            state.structured_state["triage_response"]
        )
        self.assertEqual(
            state.execution_path,
            (
                ConversationClinicalState
                .ExecutionPath.BACKEND_SAFETY_RESPONSE
            ),
        )

    def test_session_can_have_only_one_clinical_state(self):
        first_state = self.make_state()
        first_state.full_clean()
        first_state.save()

        duplicate_state = self.make_state()

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                duplicate_state.save()

    def test_structured_state_must_be_json_object(self):
        state = self.make_state(
            structured_state=[
                "invalid",
                "state",
            ],
        )

        with self.assertRaises(ValidationError) as context:
            state.full_clean()

        self.assertIn(
            "structured_state",
            context.exception.message_dict,
        )

    def test_processed_message_must_belong_to_same_session(self):
        other_session = ChatSession.objects.create(
            title="Other session",
        )
        other_message = ChatMessage.objects.create(
            session=other_session,
            sender=ChatMessage.Sender.USER,
            content="Different conversation.",
        )

        state = self.make_state(
            last_processed_message=other_message,
        )

        with self.assertRaises(ValidationError) as context:
            state.full_clean()

        self.assertIn(
            "last_processed_message",
            context.exception.message_dict,
        )

    def test_schema_version_must_be_at_least_one(self):
        state = self.make_state(
            schema_version=0,
        )

        with self.assertRaises(ValidationError) as context:
            state.full_clean()

        self.assertIn(
            "schema_version",
            context.exception.message_dict,
        )

    def test_execution_path_rejects_invalid_combinations(self):
        invalid_combinations = (
            {
                "execution_path": (
                    ConversationClinicalState
                    .ExecutionPath.BACKEND_SAFETY_RESPONSE
                ),
                "safety_decision": (
                    ConversationClinicalState
                    .SafetyDecision.CONTINUE
                ),
                "urgency": (
                    ConversationClinicalState.Urgency.ROUTINE
                ),
            },
            {
                "execution_path": (
                    ConversationClinicalState
                    .ExecutionPath.AI_PROVIDER
                ),
                "safety_decision": (
                    ConversationClinicalState
                    .SafetyDecision.EMERGENCY
                ),
                "urgency": (
                    ConversationClinicalState.Urgency.EMERGENCY
                ),
            },
        )

        for values in invalid_combinations:
            with self.subTest(values=values):
                state = self.make_state(**values)

                with self.assertRaises(ValidationError):
                    state.full_clean()

    def test_urgent_decision_enforces_urgent_floor(self):
        state = self.make_state(
            safety_decision=(
                ConversationClinicalState.SafetyDecision.URGENT
            ),
            urgency=ConversationClinicalState.Urgency.SOON,
        )

        with self.assertRaises(ValidationError):
            state.full_clean()

    def test_deleting_processed_message_sets_reference_null(self):
        state = self.make_state()
        state.full_clean()
        state.save()

        self.message.delete()

        state.refresh_from_db()

        self.assertIsNone(
            state.last_processed_message,
        )

    def test_deleting_specialty_preserves_code_snapshot(self):
        state = self.make_state(
            suggested_specialty=self.specialty,
            suggested_specialty_code=self.specialty.code,
        )
        state.full_clean()
        state.save()

        self.specialty.delete()

        state.refresh_from_db()

        self.assertIsNone(
            state.suggested_specialty,
        )
        self.assertEqual(
            state.suggested_specialty_code,
            "test_specialty",
        )

    def test_deleting_session_cascades_clinical_state(self):
        state = self.make_state()
        state.full_clean()
        state.save()

        state_pk = state.pk

        self.session.delete()

        self.assertFalse(
            ConversationClinicalState.objects.filter(
                pk=state_pk,
            ).exists()
        )
