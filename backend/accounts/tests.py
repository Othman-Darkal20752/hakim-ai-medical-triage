from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import override_settings
from rest_framework import status
from rest_framework.test import APITestCase

from doctors.models import DoctorProfile
from patients.models import PatientHealthProfile

from .models import ExternalIdentity, UserProfile
from .serializers import RegisterSerializer


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

        self.assertEqual(
            user.profile.role,
            UserProfile.ROLE_PATIENT,
        )
        self.assertEqual(
            response.data['user']['role'],
            UserProfile.ROLE_PATIENT,
        )
        self.assertFalse(
            DoctorProfile.objects.filter(user=user).exists(),
        )
        self.assertTrue(
            PatientHealthProfile.objects.filter(user=user).exists(),
        )
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

        self.assertEqual(
            user.profile.role,
            UserProfile.ROLE_PATIENT,
        )
        self.assertFalse(
            DoctorProfile.objects.filter(user=user).exists(),
        )
        self.assertTrue(
            PatientHealthProfile.objects.filter(user=user).exists(),
        )

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

        self.assertEqual(
            user.profile.role,
            UserProfile.ROLE_DOCTOR,
        )
        self.assertEqual(
            response.data['user']['role'],
            UserProfile.ROLE_DOCTOR,
        )

        doctor_profile = DoctorProfile.objects.get(user=user)

        self.assertEqual(
            doctor_profile.verification_status,
            DoctorProfile.VerificationStatus.PENDING,
        )
        self.assertEqual(
            doctor_profile.subscription_status,
            DoctorProfile.SubscriptionStatus.INACTIVE,
        )
        self.assertIsNone(doctor_profile.specialty)
        self.assertFalse(
            PatientHealthProfile.objects.filter(user=user).exists(),
        )

    def test_registration_rejects_admin_role(self):
        response = self.client.post(
            self.register_url,
            self._registration_payload(
                username='forbidden-admin',
                role=UserProfile.ROLE_ADMIN,
            ),
            format='json',
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
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

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertIn('role', response.data)
        self.assertFalse(
            User.objects.filter(username='invalid-role-user').exists(),
        )


class RegisterSerializerTransactionTests(APITestCase):
    def test_patient_registration_rolls_back_when_profile_creation_fails(self):
        username = 'patient-rollback'

        serializer = RegisterSerializer(
            data={
                'username': username,
                'email': f'{username}@example.com',
                'password': 'Test12345!',
                'password_confirm': 'Test12345!',
                'role': UserProfile.ROLE_PATIENT,
            },
        )

        self.assertTrue(
            serializer.is_valid(),
            serializer.errors,
        )

        with patch(
            'patients.models.PatientHealthProfile.objects.create',
            side_effect=RuntimeError('forced patient profile failure'),
        ):
            with self.assertRaisesRegex(
                RuntimeError,
                'forced patient profile failure',
            ):
                serializer.save()

        self.assertFalse(
            User.objects.filter(username=username).exists(),
        )
        self.assertFalse(
            UserProfile.objects.filter(
                user__username=username,
            ).exists(),
        )
        self.assertFalse(
            PatientHealthProfile.objects.filter(
                user__username=username,
            ).exists(),
        )

    def test_doctor_registration_rolls_back_when_profile_creation_fails(self):
        username = 'doctor-rollback'

        serializer = RegisterSerializer(
            data={
                'username': username,
                'email': f'{username}@example.com',
                'password': 'Test12345!',
                'password_confirm': 'Test12345!',
                'role': UserProfile.ROLE_DOCTOR,
            },
        )

        self.assertTrue(
            serializer.is_valid(),
            serializer.errors,
        )

        with patch(
            'doctors.models.DoctorProfile.objects.create',
            side_effect=RuntimeError('forced doctor profile failure'),
        ):
            with self.assertRaisesRegex(
                RuntimeError,
                'forced doctor profile failure',
            ):
                serializer.save()

        self.assertFalse(
            User.objects.filter(username=username).exists(),
        )
        self.assertFalse(
            UserProfile.objects.filter(
                user__username=username,
            ).exists(),
        )
        self.assertFalse(
            DoctorProfile.objects.filter(
                user__username=username,
            ).exists(),
        )

@override_settings(GOOGLE_CLIENT_ID='test-google-client-id')
class GoogleLoginPatientHealthProfileTests(APITestCase):
    google_url = '/api/auth/google/'

    def _token_info(self, *, subject, email):
        return {
            'iss': 'https://accounts.google.com',
            'sub': subject,
            'email': email,
            'email_verified': True,
            'given_name': 'Google',
            'family_name': 'User',
        }

    @patch('accounts.views.google_id_token.verify_oauth2_token')
    def test_new_google_patient_gets_health_profile(
        self,
        verify_oauth2_token,
    ):
        subject = 'google-new-patient-subject'
        email = 'google-new-patient@example.com'

        verify_oauth2_token.return_value = self._token_info(
            subject=subject,
            email=email,
        )

        response = self.client.post(
            self.google_url,
            {'id_token': 'valid-google-token'},
            format='json',
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
        )

        user = User.objects.get(email=email)

        self.assertEqual(
            user.profile.role,
            UserProfile.ROLE_PATIENT,
        )
        self.assertTrue(
            PatientHealthProfile.objects.filter(user=user).exists(),
        )
        self.assertTrue(
            ExternalIdentity.objects.filter(
                user=user,
                provider=ExternalIdentity.PROVIDER_GOOGLE,
                subject=subject,
            ).exists(),
        )

    @patch('accounts.views.google_id_token.verify_oauth2_token')
    def test_existing_google_doctor_does_not_get_health_profile(
        self,
        verify_oauth2_token,
    ):
        subject = 'google-existing-doctor-subject'
        email = 'google-doctor@example.com'

        user = User.objects.create_user(
            username='google-doctor',
            email=email,
            password='Test12345!',
        )
        UserProfile.objects.create(
            user=user,
            role=UserProfile.ROLE_DOCTOR,
        )
        ExternalIdentity.objects.create(
            user=user,
            provider=ExternalIdentity.PROVIDER_GOOGLE,
            subject=subject,
            email=email,
        )

        verify_oauth2_token.return_value = self._token_info(
            subject=subject,
            email=email,
        )

        response = self.client.post(
            self.google_url,
            {'id_token': 'valid-google-token'},
            format='json',
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )
        self.assertEqual(
            response.data['user']['role'],
            UserProfile.ROLE_DOCTOR,
        )
        self.assertFalse(
            PatientHealthProfile.objects.filter(user=user).exists(),
        )

    @patch('accounts.views.google_id_token.verify_oauth2_token')
    def test_new_google_registration_rolls_back_when_health_profile_fails(
        self,
        verify_oauth2_token,
    ):
        subject = 'google-patient-rollback-subject'
        email = 'google-patient-rollback@example.com'

        verify_oauth2_token.return_value = self._token_info(
            subject=subject,
            email=email,
        )

        with patch(
            'accounts.views.PatientHealthProfile.objects.get_or_create',
            side_effect=RuntimeError('forced patient profile failure'),
        ):
            with self.assertRaisesRegex(
                RuntimeError,
                'forced patient profile failure',
            ):
                self.client.post(
                    self.google_url,
                    {'id_token': 'valid-google-token'},
                    format='json',
                )

        self.assertFalse(
            User.objects.filter(email=email).exists(),
        )
        self.assertFalse(
            ExternalIdentity.objects.filter(subject=subject).exists(),
        )
        self.assertFalse(
            UserProfile.objects.filter(user__email=email).exists(),
        )
