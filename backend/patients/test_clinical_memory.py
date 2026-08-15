from django.contrib.auth.models import User
from django.test import TestCase

from .models import PatientHealthProfile
from .services.clinical_memory import (
    ClinicalMemoryValidationError,
    apply_confirmed_clinical_memory_update,
)


class ConfirmedClinicalMemoryTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="clinical-memory-patient",
            password="StrongPassword123",
        )
        self.other_user = User.objects.create_user(
            username="other-clinical-memory-patient",
            password="StrongPassword123",
        )

        self.profile = PatientHealthProfile.objects.create(
            user=self.user,
        )

        self.other_profile = PatientHealthProfile.objects.create(
            user=self.other_user,
            allergies=["Peanuts"],
        )

    def test_adds_confirmed_list_value(self):
        profile = apply_confirmed_clinical_memory_update(
            user=self.user,
            field_name="allergies",
            operation="add",
            value="  Penicillin  ",
        )

        self.assertEqual(
            profile.allergies,
            ["Penicillin"],
        )
        self.assertIsNotNone(profile.last_reviewed_at)

    def test_duplicate_list_value_is_not_added_twice(self):
        self.profile.allergies = ["Penicillin"]
        self.profile.save()

        profile = apply_confirmed_clinical_memory_update(
            user=self.user,
            field_name="allergies",
            operation="add",
            value="penicillin",
        )

        self.assertEqual(
            profile.allergies,
            ["Penicillin"],
        )

    def test_removes_confirmed_list_value_case_insensitively(self):
        self.profile.current_medications = [
            "Metformin",
            "Medication B",
        ]
        self.profile.save()

        profile = apply_confirmed_clinical_memory_update(
            user=self.user,
            field_name="current_medications",
            operation="remove",
            value="metformin",
        )

        self.assertEqual(
            profile.current_medications,
            ["Medication B"],
        )

    def test_sets_valid_scalar_value(self):
        profile = apply_confirmed_clinical_memory_update(
            user=self.user,
            field_name="smoking_status",
            operation="set",
            value="Former",
        )

        self.assertEqual(
            profile.smoking_status,
            PatientHealthProfile.SmokingStatus.FORMER,
        )

    def test_rejects_unsupported_field(self):
        with self.assertRaises(
            ClinicalMemoryValidationError
        ):
            apply_confirmed_clinical_memory_update(
                user=self.user,
                field_name="diagnosis",
                operation="add",
                value="Asthma",
            )

    def test_rejects_wrong_operation_for_list_field(self):
        with self.assertRaises(
            ClinicalMemoryValidationError
        ):
            apply_confirmed_clinical_memory_update(
                user=self.user,
                field_name="allergies",
                operation="set",
                value="Penicillin",
            )

    def test_rejects_invalid_scalar_choice(self):
        with self.assertRaises(
            ClinicalMemoryValidationError
        ):
            apply_confirmed_clinical_memory_update(
                user=self.user,
                field_name="pregnancy_status",
                operation="set",
                value="invalid-status",
            )

    def test_rejects_blank_value(self):
        with self.assertRaises(
            ClinicalMemoryValidationError
        ):
            apply_confirmed_clinical_memory_update(
                user=self.user,
                field_name="chronic_conditions",
                operation="add",
                value="   ",
            )

    def test_rejects_more_than_fifty_list_items(self):
        self.profile.previous_surgeries = [
            f"Surgery {index}"
            for index in range(50)
        ]
        self.profile.save()

        with self.assertRaises(
            ClinicalMemoryValidationError
        ):
            apply_confirmed_clinical_memory_update(
                user=self.user,
                field_name="previous_surgeries",
                operation="add",
                value="Another surgery",
            )

    def test_update_is_scoped_to_supplied_user(self):
        apply_confirmed_clinical_memory_update(
            user=self.user,
            field_name="allergies",
            operation="add",
            value="Penicillin",
        )

        self.profile.refresh_from_db()
        self.other_profile.refresh_from_db()

        self.assertEqual(
            self.profile.allergies,
            ["Penicillin"],
        )
        self.assertEqual(
            self.other_profile.allergies,
            ["Peanuts"],
        )

    def test_missing_profile_is_created_for_user(self):
        user_without_profile = User.objects.create_user(
            username="clinical-memory-no-profile",
            password="StrongPassword123",
        )

        profile = apply_confirmed_clinical_memory_update(
            user=user_without_profile,
            field_name="chronic_conditions",
            operation="add",
            value="Asthma",
        )

        self.assertEqual(
            profile.user,
            user_without_profile,
        )
        self.assertEqual(
            profile.chronic_conditions,
            ["Asthma"],
        )