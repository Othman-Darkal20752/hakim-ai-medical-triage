from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import UserProfile

from .models import PatientHealthProfile


class PatientHealthProfileApiTests(APITestCase):
    def setUp(self):
        self.patient_user = User.objects.create_user(
            username='patient-user',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=self.patient_user,
            role=UserProfile.ROLE_PATIENT,
        )
        self.patient_profile = PatientHealthProfile.objects.create(
            user=self.patient_user,
            chronic_conditions=['Asthma'],
        )

        self.other_patient_user = User.objects.create_user(
            username='other-patient',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=self.other_patient_user,
            role=UserProfile.ROLE_PATIENT,
        )
        self.other_patient_profile = (
            PatientHealthProfile.objects.create(
                user=self.other_patient_user,
                allergies=['Peanuts'],
            )
        )

        self.doctor_user = User.objects.create_user(
            username='doctor-user',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=self.doctor_user,
            role=UserProfile.ROLE_DOCTOR,
        )

        self.health_profile_url = reverse(
            'patient-health-profile',
        )

    def authenticate(self, user):
        access_token = RefreshToken.for_user(user).access_token

        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {access_token}'
        )

    def test_unauthenticated_request_is_rejected(self):
        response = self.client.get(self.health_profile_url)

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

    def test_doctor_cannot_access_patient_health_profile(self):
        self.authenticate(self.doctor_user)

        response = self.client.get(self.health_profile_url)

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_patient_can_retrieve_only_own_health_profile(self):
        self.authenticate(self.patient_user)

        response = self.client.get(self.health_profile_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data['id'],
            self.patient_profile.pk,
        )
        self.assertEqual(
            response.data['chronic_conditions'],
            ['Asthma'],
        )
        self.assertNotEqual(
            response.data['id'],
            self.other_patient_profile.pk,
        )
        self.assertNotIn('user', response.data)

    def test_patient_can_update_only_own_health_profile(self):
        self.authenticate(self.patient_user)

        response = self.client.patch(
            self.health_profile_url,
            {
                'allergies': ['Penicillin'],
                'current_medications': ['Salbutamol'],
                'smoking_status': 'never',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.patient_profile.refresh_from_db()
        self.other_patient_profile.refresh_from_db()

        self.assertEqual(
            self.patient_profile.allergies,
            ['Penicillin'],
        )
        self.assertEqual(
            self.patient_profile.current_medications,
            ['Salbutamol'],
        )
        self.assertEqual(
            self.patient_profile.smoking_status,
            'never',
        )
        self.assertIsNotNone(
            self.patient_profile.last_reviewed_at,
        )

        self.assertEqual(
            self.other_patient_profile.allergies,
            ['Peanuts'],
        )

    def test_invalid_medical_list_is_rejected(self):
        self.authenticate(self.patient_user)

        response = self.client.patch(
            self.health_profile_url,
            {
                'allergies': 'Penicillin',
            },
            format='json',
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertIn('allergies', response.data)

    def test_patient_cannot_update_server_managed_fields(self):
        self.authenticate(self.patient_user)

        response = self.client.patch(
            self.health_profile_url,
            {
                'user': self.other_patient_user.pk,
                'last_reviewed_at': '2026-08-04T00:00:00Z',
            },
            format='json',
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertIn('user', response.data)
        self.assertIn('last_reviewed_at', response.data)

    def test_missing_patient_health_profile_is_created_safely(self):
        patient_without_profile = User.objects.create_user(
            username='patient-without-profile',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=patient_without_profile,
            role=UserProfile.ROLE_PATIENT,
        )

        self.authenticate(patient_without_profile)

        response = self.client.get(self.health_profile_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(
            PatientHealthProfile.objects.filter(
                user=patient_without_profile,
            ).exists(),
        )
        self.assertEqual(response.data['chronic_conditions'], [])
        self.assertEqual(response.data['allergies'], [])
