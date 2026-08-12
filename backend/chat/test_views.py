from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import override_settings
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

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
from .services.triage.red_flags.response_policy import (
    SafetyDecisionType,
    StructuredSafetyDecision,
)


class ChatMessageAuthenticationTests(APITestCase):
    def setUp(self):
        self.url = reverse("chat-messages")

        self.user = User.objects.create_user(
            username="patient-one",
            password="Test12345!",
        )
        self.other_user = User.objects.create_user(
            username="patient-two",
            password="Test12345!",
        )

    def _make_continue_orchestration_result(
        self,
        *,
        response_language: str,
    ) -> ChatOrchestrationResult:
        if response_language == "ar":
            symptom_summary = ("ملخص أعراض اختباري.",)
            follow_up_questions = ("سؤال متابعة اختباري؟",)
            safety_disclaimer = (
                "هذا إرشاد طبي أولي وليس تشخيصًا نهائيًا."
            )
        else:
            symptom_summary = ("Test symptom summary.",)
            follow_up_questions = ("Test follow-up question?",)
            safety_disclaimer = (
                "This is preliminary medical guidance and "
                "not a final diagnosis."
            )

        safety_decision = StructuredSafetyDecision(
            decision=SafetyDecisionType.CONTINUE,
            reasons=(),
            highest_urgency=None,
            must_override_model=False,
            should_short_circuit_llm=False,
            source_engine_version="test-views-engine-v1",
        )

        triage_response = TriageResponse(
            symptom_summary=symptom_summary,
            follow_up_questions=follow_up_questions,
            urgency="routine",
            suggested_specialty_code=None,
            needs_more_information=False,
            emergency_warning=None,
            safety_disclaimer=safety_disclaimer,
        )

        return ChatOrchestrationResult(
            execution_path=ChatExecutionPath.AI_PROVIDER,
            safety_decision=safety_decision,
            triage_response=triage_response,
        )

    def test_unauthenticated_user_cannot_create_chat_session(self):
        response = self.client.post(
            self.url,
            {
                "message": "I have a headache.",
                "language": "en",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )
        self.assertEqual(ChatSession.objects.count(), 0)
        self.assertEqual(ChatMessage.objects.count(), 0)

    @patch("chat.views.orchestrate_chat")
    def test_authenticated_user_creates_owned_chat_session(
        self,
        mock_orchestrate_chat,
    ):
        mock_orchestrate_chat.return_value = (
            self._make_continue_orchestration_result(
                response_language="en",
            )
        )

        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.url,
            {
                "message": "I have a mild headache.",
                "language": "en",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
        )

        session = ChatSession.objects.get()

        self.assertEqual(session.user, self.user)
        self.assertEqual(session.messages.count(), 2)

    @patch("chat.views.orchestrate_chat")
    def test_authenticated_user_can_continue_own_session(
        self,
        mock_orchestrate_chat,
    ):
        mock_orchestrate_chat.return_value = (
            self._make_continue_orchestration_result(
                response_language="en",
            )
        )

        session = ChatSession.objects.create(user=self.user)

        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.url,
            {
                "message": "The headache started yesterday.",
                "session_id": str(session.id),
                "language": "en",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
        )
        self.assertEqual(session.messages.count(), 2)

    def test_user_cannot_continue_another_users_session(self):
        session = ChatSession.objects.create(user=self.other_user)

        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.url,
            {
                "message": "Attempt to access another session.",
                "session_id": str(session.id),
                "language": "en",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )
        self.assertEqual(session.messages.count(), 0)

    def test_user_cannot_claim_legacy_anonymous_session(self):
        session = ChatSession.objects.create(user=None)

        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.url,
            {
                "message": "Attempt to claim anonymous session.",
                "session_id": str(session.id),
                "language": "en",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

        session.refresh_from_db()

        self.assertIsNone(session.user)
        self.assertEqual(session.messages.count(), 0)

    @patch("chat.views.orchestrate_chat")
    def test_authenticated_user_can_send_arabic_language(
        self,
        mock_orchestrate_chat,
    ):
        mock_orchestrate_chat.return_value = (
            self._make_continue_orchestration_result(
                response_language="ar",
            )
        )

        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.url,
            {
                "message": "أشعر بصداع منذ الصباح.",
                "language": "ar",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
        )
        self.assertEqual(ChatSession.objects.count(), 1)
        self.assertEqual(ChatMessage.objects.count(), 2)

    @override_settings(AI_ENABLED=False)
    def test_emergency_message_short_circuits_ai_and_persists_state(
        self,
    ):
        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.url,
            {
                "message": "I have loss of consciousness.",
                "language": "en",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
        )

        session = ChatSession.objects.get()
        messages = list(
            session.messages.order_by("created_at", "id")
        )

        self.assertEqual(len(messages), 2)
        self.assertEqual(
            messages[0].sender,
            ChatMessage.Sender.USER,
        )
        self.assertEqual(
            messages[1].sender,
            ChatMessage.Sender.ASSISTANT,
        )

        self.assertIn(
            "may indicate a medical emergency",
            messages[1].content,
        )
        self.assertEqual(
            response.json()["reply"],
            messages[1].content,
        )

        clinical_state = (
            ConversationClinicalState.objects.get(
                session=session,
            )
        )

        self.assertEqual(
            clinical_state.last_processed_message,
            messages[0],
        )
        self.assertEqual(
            clinical_state.urgency,
            ConversationClinicalState.Urgency.EMERGENCY,
        )
        self.assertEqual(
            clinical_state.safety_decision,
            (
                ConversationClinicalState
                .SafetyDecision.EMERGENCY
            ),
        )
        self.assertEqual(
            clinical_state.execution_path,
            (
                ConversationClinicalState
                .ExecutionPath.BACKEND_SAFETY_RESPONSE
            ),
        )
        self.assertIsNone(
            clinical_state.suggested_specialty,
        )
        self.assertEqual(
            clinical_state.suggested_specialty_code,
            "",
        )
        self.assertIsNone(
            clinical_state.structured_state[
                "triage_response"
            ],
        )

    @override_settings(AI_ENABLED=False)
    def test_non_emergency_ai_disabled_returns_service_unavailable(
        self,
    ):
        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.url,
            {
                "message": "I have a mild headache.",
                "language": "en",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_503_SERVICE_UNAVAILABLE,
        )
        self.assertEqual(
            response.json(),
            {
                "error": "AI service is temporarily unavailable",
            },
        )

        session = ChatSession.objects.get()
        messages = list(
            session.messages.order_by("created_at", "id")
        )

        self.assertEqual(len(messages), 1)
        self.assertEqual(
            messages[0].sender,
            ChatMessage.Sender.USER,
        )
        self.assertEqual(
            messages[0].content,
            "I have a mild headache.",
        )

        self.assertFalse(
            ConversationClinicalState.objects.filter(
                session=session,
            ).exists()
        )

    def test_missing_language_is_rejected(self):
        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.url,
            {
                "message": "I have a headache.",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertEqual(ChatSession.objects.count(), 0)
        self.assertEqual(ChatMessage.objects.count(), 0)

    def test_invalid_language_is_rejected(self):
        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.url,
            {
                "message": "I have a headache.",
                "language": "fr",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertEqual(ChatSession.objects.count(), 0)
        self.assertEqual(ChatMessage.objects.count(), 0)