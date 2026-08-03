from django.contrib.auth.models import User
from django.test import TestCase

from .models import PatientHealthProfile
from .serializers import PatientHealthProfileSerializer


class PatientHealthProfileSerializerTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='patient-user',
            password='StrongPassword123',
        )
        self.profile = PatientHealthProfile.objects.create(
            user=self.user,
        )

    def test_serializes_public_health_profile_fields(self):
        data = PatientHealthProfileSerializer(self.profile).data

        self.assertEqual(
            set(data.keys()),
            {
                'id',
                'chronic_conditions',
                'allergies',
                'current_medications',
                'previous_surgeries',
                'smoking_status',
                'alcohol_use',
                'pregnancy_status',
                'last_reviewed_at',
                'created_at',
                'updated_at',
            },
        )
        self.assertNotIn('user', data)
        self.assertEqual(data['chronic_conditions'], [])
        self.assertEqual(data['smoking_status'], 'unknown')

    def test_updates_and_normalizes_medical_lists(self):
        serializer = PatientHealthProfileSerializer(
            self.profile,
            data={
                'chronic_conditions': [
                    '  Asthma  ',
                    'Type 2 diabetes',
                ],
                'allergies': [
                    '  Penicillin ',
                ],
                'current_medications': [
                    ' Metformin ',
                ],
                'smoking_status': 'former',
            },
            partial=True,
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)

        updated_profile = serializer.save()

        self.assertEqual(
            updated_profile.chronic_conditions,
            ['Asthma', 'Type 2 diabetes'],
        )
        self.assertEqual(
            updated_profile.allergies,
            ['Penicillin'],
        )
        self.assertEqual(
            updated_profile.current_medications,
            ['Metformin'],
        )
        self.assertEqual(updated_profile.smoking_status, 'former')
        self.assertIsNotNone(updated_profile.last_reviewed_at)

    def test_empty_patch_marks_profile_as_reviewed(self):
        self.assertIsNone(self.profile.last_reviewed_at)

        serializer = PatientHealthProfileSerializer(
            self.profile,
            data={},
            partial=True,
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)

        updated_profile = serializer.save()

        self.assertIsNotNone(updated_profile.last_reviewed_at)

    def test_rejects_non_list_medical_field(self):
        serializer = PatientHealthProfileSerializer(
            self.profile,
            data={
                'allergies': 'Penicillin',
            },
            partial=True,
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn('allergies', serializer.errors)

    def test_rejects_blank_medical_list_item(self):
        serializer = PatientHealthProfileSerializer(
            self.profile,
            data={
                'current_medications': [
                    'Metformin',
                    '   ',
                ],
            },
            partial=True,
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn('current_medications', serializer.errors)

    def test_rejects_more_than_fifty_items(self):
        serializer = PatientHealthProfileSerializer(
            self.profile,
            data={
                'previous_surgeries': [
                    f'Surgery {index}'
                    for index in range(51)
                ],
            },
            partial=True,
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn('previous_surgeries', serializer.errors)

    def test_rejects_server_managed_fields(self):
        serializer = PatientHealthProfileSerializer(
            self.profile,
            data={
                'user': self.user.pk,
                'last_reviewed_at': '2026-08-04T00:00:00Z',
            },
            partial=True,
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn('user', serializer.errors)
        self.assertIn('last_reviewed_at', serializer.errors)

    def test_rejects_invalid_status_choice(self):
        serializer = PatientHealthProfileSerializer(
            self.profile,
            data={
                'pregnancy_status': 'invalid-status',
            },
            partial=True,
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn('pregnancy_status', serializer.errors)
