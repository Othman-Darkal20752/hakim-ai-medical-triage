from django.contrib.auth.models import AnonymousUser, User
from django.test import TestCase
from rest_framework.test import APIRequestFactory

from .models import UserProfile
from .permissions import IsDoctor, IsPatient


class IsDoctorPermissionTests(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.permission = IsDoctor()

    def _build_request(self, user):
        request = self.factory.get('/api/doctors/me/')
        request.user = user
        return request

    def test_allows_authenticated_doctor(self):
        user = User.objects.create_user(
            username='doctor-user',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=user,
            role=UserProfile.ROLE_DOCTOR,
        )

        request = self._build_request(user)

        self.assertTrue(
            self.permission.has_permission(request, None)
        )

    def test_rejects_authenticated_patient(self):
        user = User.objects.create_user(
            username='patient-user',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=user,
            role=UserProfile.ROLE_PATIENT,
        )

        request = self._build_request(user)

        self.assertFalse(
            self.permission.has_permission(request, None)
        )

    def test_rejects_user_without_profile(self):
        user = User.objects.create_user(
            username='profileless-user',
            password='StrongPassword123',
        )

        request = self._build_request(user)

        self.assertFalse(
            self.permission.has_permission(request, None)
        )

    def test_rejects_anonymous_user(self):
        request = self._build_request(AnonymousUser())

        self.assertFalse(
            self.permission.has_permission(request, None)
        )


class IsPatientPermissionTests(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.permission = IsPatient()

    def _build_request(self, user):
        request = self.factory.get(
            '/api/patients/health-profile/'
        )
        request.user = user
        return request

    def test_allows_authenticated_patient(self):
        user = User.objects.create_user(
            username='patient-user',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=user,
            role=UserProfile.ROLE_PATIENT,
        )

        request = self._build_request(user)

        self.assertTrue(
            self.permission.has_permission(request, None)
        )

    def test_rejects_authenticated_doctor(self):
        user = User.objects.create_user(
            username='doctor-user',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=user,
            role=UserProfile.ROLE_DOCTOR,
        )

        request = self._build_request(user)

        self.assertFalse(
            self.permission.has_permission(request, None)
        )

    def test_rejects_user_without_profile(self):
        user = User.objects.create_user(
            username='profileless-user',
            password='StrongPassword123',
        )

        request = self._build_request(user)

        self.assertFalse(
            self.permission.has_permission(request, None)
        )

    def test_rejects_anonymous_user(self):
        request = self._build_request(AnonymousUser())

        self.assertFalse(
            self.permission.has_permission(request, None)
        )
