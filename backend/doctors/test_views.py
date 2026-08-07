from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import UserProfile

from .models import DoctorProfile, Specialty


class DoctorProfileApiTests(APITestCase):
    def setUp(self):
        Specialty.objects.all().delete()

        self.patient_user = User.objects.create_user(
            username='patient-user',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=self.patient_user,
            role=UserProfile.ROLE_PATIENT,
        )

        self.doctor_user = User.objects.create_user(
            username='doctor-user',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=self.doctor_user,
            role=UserProfile.ROLE_DOCTOR,
        )
        self.doctor_profile = DoctorProfile.objects.create(
            user=self.doctor_user,
            display_name='Doctor One',
            verification_status=(
                DoctorProfile.VerificationStatus.PENDING
            ),
            subscription_status=(
                DoctorProfile.SubscriptionStatus.INACTIVE
            ),
        )

        self.other_doctor_user = User.objects.create_user(
            username='other-doctor',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=self.other_doctor_user,
            role=UserProfile.ROLE_DOCTOR,
        )
        self.other_doctor_profile = DoctorProfile.objects.create(
            user=self.other_doctor_user,
            display_name='Doctor Two',
        )

        self.active_specialty = Specialty.objects.create(
            code='cardiology',
            name_ar='قلبية',
            name_en='Cardiology',
            is_active=True,
            display_order=1,
        )
        self.inactive_specialty = Specialty.objects.create(
            code='inactive_specialty',
            name_ar='اختصاص غير فعال',
            name_en='Inactive Specialty',
            is_active=False,
            display_order=0,
        )

        self.doctor_me_url = reverse('doctor-me')
        self.specialties_url = reverse('doctor-specialty-list')

    def authenticate(self, user):
        access_token = RefreshToken.for_user(user).access_token

        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {access_token}'
        )

    def test_unauthenticated_request_is_rejected(self):
        response = self.client.get(self.doctor_me_url)

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

    def test_patient_cannot_access_doctor_profile(self):
        self.authenticate(self.patient_user)

        response = self.client.get(self.doctor_me_url)

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_doctor_can_retrieve_only_own_profile(self):
        self.authenticate(self.doctor_user)

        response = self.client.get(self.doctor_me_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data['id'],
            self.doctor_profile.pk,
        )
        self.assertEqual(
            response.data['display_name'],
            'Doctor One',
        )
        self.assertEqual(
            response.data['verification_status'],
            DoctorProfile.VerificationStatus.PENDING,
        )
        self.assertEqual(
            response.data['subscription_status'],
            DoctorProfile.SubscriptionStatus.INACTIVE,
        )
        self.assertNotIn('user', response.data)
        self.assertNotIn('verified_by', response.data)
        self.assertFalse(response.data['is_profile_complete'])

    def test_doctor_can_update_own_professional_data_only(self):
        self.authenticate(self.doctor_user)

        response = self.client.patch(
            self.doctor_me_url,
            {
                'display_name': 'Updated Doctor',
                'specialty_id': self.active_specialty.pk,
                'phone_number': '+963999000000',
                'city': 'Damascus',
                'years_of_experience': 8,
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.doctor_profile.refresh_from_db()
        self.other_doctor_profile.refresh_from_db()

        self.assertEqual(
            self.doctor_profile.display_name,
            'Updated Doctor',
        )
        self.assertEqual(
            self.doctor_profile.specialty,
            self.active_specialty,
        )
        self.assertEqual(
            self.doctor_profile.years_of_experience,
            8,
        )
        self.assertEqual(
            self.other_doctor_profile.display_name,
            'Doctor Two',
        )

    def test_profile_reports_complete_after_required_data_is_saved(self):
        self.authenticate(self.doctor_user)

        response = self.client.patch(
            self.doctor_me_url,
            {
                'display_name': 'Doctor One',
                'specialty_id': self.active_specialty.pk,
                'medical_license_number': 'LICENSE-001',
                'phone_number': '+963999000000',
                'city': 'Damascus',
                'address': 'Clinic address',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['is_profile_complete'])

    def test_doctor_cannot_update_admin_managed_fields(self):
        self.authenticate(self.doctor_user)

        response = self.client.patch(
            self.doctor_me_url,
            {
                'verification_status': 'verified',
                'verification_note': 'Self approved',
                'subscription_status': 'active',
            },
            format='json',
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )

        self.doctor_profile.refresh_from_db()

        self.assertEqual(
            self.doctor_profile.verification_status,
            DoctorProfile.VerificationStatus.PENDING,
        )
        self.assertEqual(
            self.doctor_profile.subscription_status,
            DoctorProfile.SubscriptionStatus.INACTIVE,
        )
        self.assertEqual(
            self.doctor_profile.verification_note,
            '',
        )

    def test_doctor_role_without_profile_receives_not_found(self):
        doctor_without_profile = User.objects.create_user(
            username='doctor-without-profile',
            password='StrongPassword123',
        )
        UserProfile.objects.create(
            user=doctor_without_profile,
            role=UserProfile.ROLE_DOCTOR,
        )
        self.authenticate(doctor_without_profile)

        response = self.client.get(self.doctor_me_url)

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )

    def test_specialty_list_returns_active_specialties_only(self):
        self.authenticate(self.doctor_user)

        response = self.client.get(self.specialties_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(set(response.data.keys()), {'specialties'})

        specialties = response.data['specialties']

        self.assertEqual(len(specialties), 1)
        self.assertEqual(
            specialties[0]['id'],
            self.active_specialty.pk,
        )
        self.assertEqual(
            specialties[0]['code'],
            'cardiology',
        )

    def test_patient_cannot_access_specialty_list(self):
        self.authenticate(self.patient_user)

        response = self.client.get(self.specialties_url)

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )
