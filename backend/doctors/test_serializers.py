from django.contrib.auth.models import User
from django.test import TestCase
from django.utils import timezone

from .models import DoctorProfile, Specialty
from .serializers import (
    DoctorSelfProfileSerializer,
    SpecialtySerializer,
)


class SpecialtySerializerTests(TestCase):
    def setUp(self):
        Specialty.objects.all().delete()

    def test_serializes_public_specialty_fields(self):
        specialty = Specialty.objects.create(
            code='cardiology',
            name_ar='قلبية',
            name_en='Cardiology',
            description_ar='اختصاص القلب',
            description_en='Heart specialty',
        )

        data = SpecialtySerializer(specialty).data

        self.assertEqual(
            set(data.keys()),
            {
                'id',
                'code',
                'name_ar',
                'name_en',
                'description_ar',
                'description_en',
            },
        )
        self.assertEqual(data['code'], 'cardiology')


class DoctorSelfProfileSerializerTests(TestCase):
    def setUp(self):
        Specialty.objects.all().delete()
        self.doctor_user = User.objects.create_user(
            username='doctor-user',
            password='StrongPassword123',
        )
        self.profile = DoctorProfile.objects.create(
            user=self.doctor_user,
            display_name='Doctor One',
        )
        self.active_specialty = Specialty.objects.create(
            code='internal_medicine',
            name_ar='داخلية',
            name_en='Internal Medicine',
            is_active=True,
        )
        self.inactive_specialty = Specialty.objects.create(
            code='inactive_specialty',
            name_ar='اختصاص غير فعال',
            name_en='Inactive Specialty',
            is_active=False,
        )

    def test_serialized_profile_contains_statuses_and_hides_admin_relations(self):
        data = DoctorSelfProfileSerializer(self.profile).data

        self.assertEqual(data['verification_status'], 'pending')
        self.assertEqual(data['subscription_status'], 'inactive')
        self.assertNotIn('user', data)
        self.assertNotIn('verified_by', data)
        self.assertNotIn('specialty_id', data)

    def test_incomplete_profile_is_reported_as_incomplete(self):
        data = DoctorSelfProfileSerializer(self.profile).data

        self.assertFalse(data['is_profile_complete'])

    def test_complete_profile_is_reported_as_complete(self):
        self.profile.specialty = self.active_specialty
        self.profile.medical_license_number = 'LICENSE-001'
        self.profile.phone_number = '+963999000000'
        self.profile.city = 'Damascus'
        self.profile.address = 'Clinic address'
        self.profile.save()

        data = DoctorSelfProfileSerializer(self.profile).data

        self.assertTrue(data['is_profile_complete'])

    def test_updates_allowed_professional_fields(self):
        serializer = DoctorSelfProfileSerializer(
            self.profile,
            data={
                'display_name': 'Updated Doctor',
                'specialty_id': self.active_specialty.pk,
                'phone_number': '+963999000000',
                'city': 'Damascus',
                'years_of_experience': 7,
            },
            partial=True,
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)

        updated_profile = serializer.save()

        self.assertEqual(updated_profile.display_name, 'Updated Doctor')
        self.assertEqual(
            updated_profile.specialty,
            self.active_specialty,
        )
        self.assertEqual(updated_profile.years_of_experience, 7)

    def test_rejects_inactive_specialty(self):
        serializer = DoctorSelfProfileSerializer(
            self.profile,
            data={
                'specialty_id': self.inactive_specialty.pk,
            },
            partial=True,
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn('specialty_id', serializer.errors)

    def test_rejects_admin_managed_fields(self):
        serializer = DoctorSelfProfileSerializer(
            self.profile,
            data={
                'verification_status': 'verified',
                'subscription_status': 'active',
            },
            partial=True,
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn('verification_status', serializer.errors)
        self.assertIn('subscription_status', serializer.errors)

    def test_normalizes_blank_license_number_to_null(self):
        self.profile.medical_license_number = 'LICENSE-001'
        self.profile.save(update_fields=['medical_license_number'])

        serializer = DoctorSelfProfileSerializer(
            self.profile,
            data={
                'medical_license_number': '   ',
            },
            partial=True,
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)

        updated_profile = serializer.save()

        self.assertIsNone(updated_profile.medical_license_number)

    def test_rejects_duplicate_license_number(self):
        other_user = User.objects.create_user(
            username='other-doctor',
            password='StrongPassword123',
        )
        DoctorProfile.objects.create(
            user=other_user,
            medical_license_number='LICENSE-001',
        )

        serializer = DoctorSelfProfileSerializer(
            self.profile,
            data={
                'medical_license_number': 'LICENSE-001',
            },
            partial=True,
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn('medical_license_number', serializer.errors)

    def test_core_field_change_returns_verified_doctor_to_pending(self):
        verifier = User.objects.create_user(
            username='admin-user',
            password='StrongPassword123',
        )
        self.profile.verification_status = (
            DoctorProfile.VerificationStatus.VERIFIED
        )
        self.profile.verification_note = 'Approved'
        self.profile.verified_at = timezone.now()
        self.profile.verified_by = verifier
        self.profile.save()

        serializer = DoctorSelfProfileSerializer(
            self.profile,
            data={
                'medical_license_number': 'NEW-LICENSE-001',
            },
            partial=True,
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)

        updated_profile = serializer.save()

        self.assertEqual(
            updated_profile.verification_status,
            DoctorProfile.VerificationStatus.PENDING,
        )
        self.assertEqual(updated_profile.verification_note, '')
        self.assertIsNone(updated_profile.verified_at)
        self.assertIsNone(updated_profile.verified_by)

    def test_non_core_field_change_preserves_verification(self):
        verifier = User.objects.create_user(
            username='admin-user',
            password='StrongPassword123',
        )
        verified_at = timezone.now()

        self.profile.verification_status = (
            DoctorProfile.VerificationStatus.VERIFIED
        )
        self.profile.verification_note = 'Approved'
        self.profile.verified_at = verified_at
        self.profile.verified_by = verifier
        self.profile.save()

        serializer = DoctorSelfProfileSerializer(
            self.profile,
            data={
                'bio': 'Updated professional biography.',
                'working_hours': 'Sunday to Thursday',
            },
            partial=True,
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)

        updated_profile = serializer.save()

        self.assertEqual(
            updated_profile.verification_status,
            DoctorProfile.VerificationStatus.VERIFIED,
        )
        self.assertEqual(updated_profile.verified_by, verifier)
        self.assertEqual(updated_profile.verified_at, verified_at)
