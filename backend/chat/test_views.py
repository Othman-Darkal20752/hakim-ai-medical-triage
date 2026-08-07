from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import ChatMessage, ChatSession


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

    def test_authenticated_user_creates_owned_chat_session(self):
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

    def test_authenticated_user_can_continue_own_session(self):
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

    def test_authenticated_user_can_send_arabic_language(self):
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
