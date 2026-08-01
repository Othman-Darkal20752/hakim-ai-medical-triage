from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APITestCase

from .models import UserProfile


class RegisterViewTests(APITestCase):
    register_url = '/api/auth/register/'

    def _registration_payload(self, *, username, role=None):
        payload = {
            'username': username,
            'email': f'{username}@example.com',
            'password': 'Test12345!',
            'password_confirm': 'Test12345!',
        }

        if role is not None:
            payload['role'] = role

        return payload

    def test_registration_defaults_to_patient_role(self):
        response = self.client.post(
            self.register_url,
            self._registration_payload(username='patient-default'),
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        user = User.objects.get(username='patient-default')

        self.assertEqual(user.profile.role, UserProfile.ROLE_PATIENT)
        self.assertEqual(response.data['user']['role'], UserProfile.ROLE_PATIENT)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)

    def test_registration_allows_explicit_patient_role(self):
        response = self.client.post(
            self.register_url,
            self._registration_payload(
                username='patient-explicit',
                role=UserProfile.ROLE_PATIENT,
            ),
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        user = User.objects.get(username='patient-explicit')

        self.assertEqual(user.profile.role, UserProfile.ROLE_PATIENT)

    def test_registration_allows_doctor_role(self):
        response = self.client.post(
            self.register_url,
            self._registration_payload(
                username='doctor-user',
                role=UserProfile.ROLE_DOCTOR,
            ),
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        user = User.objects.get(username='doctor-user')

        self.assertEqual(user.profile.role, UserProfile.ROLE_DOCTOR)
        self.assertEqual(response.data['user']['role'], UserProfile.ROLE_DOCTOR)

    def test_registration_rejects_admin_role(self):
        response = self.client.post(
            self.register_url,
            self._registration_payload(
                username='forbidden-admin',
                role=UserProfile.ROLE_ADMIN,
            ),
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('role', response.data)
        self.assertFalse(
            User.objects.filter(username='forbidden-admin').exists(),
        )

    def test_registration_rejects_unknown_role(self):
        response = self.client.post(
            self.register_url,
            self._registration_payload(
                username='invalid-role-user',
                role='superuser',
            ),
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('role', response.data)
        self.assertFalse(
            User.objects.filter(username='invalid-role-user').exists(),
        )
