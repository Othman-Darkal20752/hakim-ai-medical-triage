from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.test import TestCase

from .models import Specialty


class SpecialtyModelTests(TestCase):
    def test_create_specialty_with_expected_defaults(self):
        specialty = Specialty.objects.create(
            code='cardiology',
            name_ar='قلبية',
            name_en='Cardiology',
        )

        self.assertTrue(specialty.is_active)
        self.assertEqual(specialty.display_order, 0)
        self.assertEqual(
            str(specialty),
            'Cardiology (cardiology)',
        )
        self.assertIsNotNone(specialty.created_at)
        self.assertIsNotNone(specialty.updated_at)

    def test_specialty_code_accepts_machine_readable_format(self):
        specialty = Specialty(
            code='general_medicine2',
            name_ar='طب عام',
            name_en='General Medicine',
        )

        specialty.full_clean()

    def test_specialty_code_rejects_invalid_formats(self):
        invalid_codes = (
            'Cardiology',
            'general-medicine',
            'general__medicine',
            '_cardiology',
            'cardiology_',
            'general medicine',
        )

        for code in invalid_codes:
            with self.subTest(code=code):
                specialty = Specialty(
                    code=code,
                    name_ar='اختصاص تجريبي',
                    name_en='Test Specialty',
                )

                with self.assertRaises(ValidationError):
                    specialty.full_clean()

    def test_specialty_code_is_unique_in_database(self):
        Specialty.objects.create(
            code='pediatrics',
            name_ar='أطفال',
            name_en='Pediatrics',
        )

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                Specialty.objects.create(
                    code='pediatrics',
                    name_ar='طب أطفال',
                    name_en='Child Medicine',
                )

    def test_default_ordering_uses_display_order_then_english_name(self):
        Specialty.objects.create(
            code='dermatology',
            name_ar='جلدية',
            name_en='Dermatology',
            display_order=2,
        )
        Specialty.objects.create(
            code='pediatrics',
            name_ar='أطفال',
            name_en='Pediatrics',
            display_order=1,
        )
        Specialty.objects.create(
            code='cardiology',
            name_ar='قلبية',
            name_en='Cardiology',
            display_order=1,
        )

        codes = list(
            Specialty.objects.values_list('code', flat=True)
        )

        self.assertEqual(
            codes,
            [
                'cardiology',
                'pediatrics',
                'dermatology',
            ],
        )