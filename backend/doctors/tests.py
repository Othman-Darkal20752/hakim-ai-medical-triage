from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.db.models.deletion import ProtectedError
from django.test import RequestFactory, TestCase
from django.utils import timezone

from accounts.models import UserProfile

from .admin import DoctorProfileAdminForm
from .models import DoctorProfile, Specialty


User = get_user_model()


class SpecialtyModelTests(TestCase):
    def setUp(self):
        Specialty.objects.all().delete()

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


class DoctorProfileModelTests(TestCase):
    def create_user_with_role(self, username, role):
        user = User.objects.create_user(
            username=username,
            password='StrongTestPassword123!',
        )
        UserProfile.objects.create(
            user=user,
            role=role,
        )
        return user

    def create_doctor_user(self, username):
        return self.create_user_with_role(
            username,
            UserProfile.ROLE_DOCTOR,
        )

    def test_create_doctor_profile_with_expected_defaults(self):
        user = self.create_doctor_user('doctor_defaults')

        profile = DoctorProfile.objects.create(user=user)

        self.assertEqual(
            profile.verification_status,
            DoctorProfile.VerificationStatus.PENDING,
        )
        self.assertEqual(
            profile.subscription_status,
            DoctorProfile.SubscriptionStatus.INACTIVE,
        )
        self.assertIsNone(profile.specialty)
        self.assertIsNone(profile.medical_license_number)
        self.assertIsNone(profile.verified_by)
        self.assertIsNone(profile.verified_at)
        self.assertEqual(str(profile), user.username)
        self.assertIsNotNone(profile.created_at)
        self.assertIsNotNone(profile.updated_at)

    def test_string_representation_prefers_display_name(self):
        user = self.create_doctor_user('doctor_display_name')

        profile = DoctorProfile.objects.create(
            user=user,
            display_name='Dr. Test Doctor',
        )

        self.assertEqual(str(profile), 'Dr. Test Doctor')

    def test_user_can_have_only_one_doctor_profile(self):
        user = self.create_doctor_user('doctor_one_profile')
        DoctorProfile.objects.create(user=user)

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                DoctorProfile.objects.create(user=user)

    def test_multiple_profiles_can_have_null_license_numbers(self):
        first_user = self.create_doctor_user('doctor_null_license_1')
        second_user = self.create_doctor_user('doctor_null_license_2')

        DoctorProfile.objects.create(user=first_user)
        DoctorProfile.objects.create(user=second_user)

        self.assertEqual(
            DoctorProfile.objects.filter(
                medical_license_number__isnull=True,
            ).count(),
            2,
        )

    def test_medical_license_number_is_unique_when_present(self):
        first_user = self.create_doctor_user('doctor_license_1')
        second_user = self.create_doctor_user('doctor_license_2')

        DoctorProfile.objects.create(
            user=first_user,
            medical_license_number='LICENSE-100',
        )

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                DoctorProfile.objects.create(
                    user=second_user,
                    medical_license_number='LICENSE-100',
                )

    def test_valid_subscription_date_range_is_allowed(self):
        user = self.create_doctor_user('doctor_valid_subscription')
        started_at = timezone.now()
        expires_at = started_at + timedelta(days=30)

        profile = DoctorProfile.objects.create(
            user=user,
            subscription_started_at=started_at,
            subscription_expires_at=expires_at,
        )

        self.assertEqual(profile.subscription_started_at, started_at)
        self.assertEqual(profile.subscription_expires_at, expires_at)

    def test_invalid_subscription_date_range_is_rejected(self):
        user = self.create_doctor_user('doctor_invalid_subscription')
        started_at = timezone.now()
        expires_at = started_at - timedelta(days=1)

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                DoctorProfile.objects.create(
                    user=user,
                    subscription_started_at=started_at,
                    subscription_expires_at=expires_at,
                )

    def test_specialty_cannot_be_deleted_while_used_by_doctor(self):
        specialty = Specialty.objects.create(
            code='neurology',
            name_ar='عصبية',
            name_en='Neurology',
        )
        user = self.create_doctor_user('doctor_protected_specialty')

        DoctorProfile.objects.create(
            user=user,
            specialty=specialty,
        )

        with self.assertRaises(ProtectedError):
            specialty.delete()

    def test_deleting_user_deletes_doctor_profile(self):
        user = self.create_doctor_user('doctor_cascade_delete')
        profile = DoctorProfile.objects.create(user=user)
        profile_id = profile.id

        user.delete()

        self.assertFalse(
            DoctorProfile.objects.filter(id=profile_id).exists()
        )

    def test_deleting_verifier_preserves_profile_and_clears_reference(self):
        doctor_user = self.create_doctor_user('doctor_verified')
        verifier = self.create_user_with_role(
            'admin_verifier',
            UserProfile.ROLE_ADMIN,
        )

        profile = DoctorProfile.objects.create(
            user=doctor_user,
            verified_by=verifier,
        )

        verifier.delete()
        profile.refresh_from_db()

        self.assertIsNone(profile.verified_by)

class DoctorProfileAdminTests(TestCase):
    def setUp(self):
        self.request_factory = RequestFactory()
        self.specialty = Specialty.objects.create(
            code='admin_test_specialty',
            name_ar='Admin Test Specialty',
            name_en='Admin Test Specialty',
        )

    def create_user_with_role(self, username, role):
        user = User.objects.create_user(
            username=username,
            password='StrongTestPassword123!',
        )
        UserProfile.objects.create(
            user=user,
            role=role,
        )
        return user

    def build_form_data(self, user, **overrides):
        data = {
            'user': user.pk,
            'specialty': '',
            'display_name': '',
            'medical_license_number': '',
            'phone_number': '',
            'whatsapp_number': '',
            'city': '',
            'address': '',
            'bio': '',
            'years_of_experience': '',
            'working_hours': '',
            'verification_status': (
                DoctorProfile.VerificationStatus.PENDING
            ),
            'verification_note': '',
            'subscription_status': (
                DoctorProfile.SubscriptionStatus.INACTIVE
            ),
            'subscription_started_at': '',
            'subscription_expires_at': '',
        }
        data.update(overrides)
        return data

    def test_non_doctor_user_is_rejected(self):
        patient = self.create_user_with_role(
            'admin_form_patient',
            UserProfile.ROLE_PATIENT,
        )

        form = DoctorProfileAdminForm(
            data=self.build_form_data(patient),
        )

        self.assertFalse(form.is_valid())
        self.assertIn('user', form.errors)

    def test_verified_doctor_requires_professional_fields(self):
        doctor = self.create_user_with_role(
            'admin_form_incomplete_doctor',
            UserProfile.ROLE_DOCTOR,
        )

        form = DoctorProfileAdminForm(
            data=self.build_form_data(
                doctor,
                verification_status=(
                    DoctorProfile.VerificationStatus.VERIFIED
                ),
            ),
        )

        self.assertFalse(form.is_valid())

        required_fields = {
            'display_name',
            'specialty',
            'medical_license_number',
            'phone_number',
            'city',
            'address',
        }

        self.assertTrue(required_fields.issubset(form.errors.keys()))

    def test_complete_verified_doctor_form_is_valid(self):
        doctor = self.create_user_with_role(
            'admin_form_complete_doctor',
            UserProfile.ROLE_DOCTOR,
        )

        form = DoctorProfileAdminForm(
            data=self.build_form_data(
                doctor,
                display_name='Dr. Complete Doctor',
                specialty=self.specialty.pk,
                medical_license_number='LICENSE-ADMIN-1',
                phone_number='+10000000001',
                city='Test City',
                address='Test Clinic Address',
                verification_status=(
                    DoctorProfile.VerificationStatus.VERIFIED
                ),
            ),
        )

        self.assertTrue(form.is_valid(), form.errors.as_json())

    def test_active_subscription_requires_dates(self):
        doctor = self.create_user_with_role(
            'admin_form_subscription_dates',
            UserProfile.ROLE_DOCTOR,
        )

        form = DoctorProfileAdminForm(
            data=self.build_form_data(
                doctor,
                subscription_status=(
                    DoctorProfile.SubscriptionStatus.ACTIVE
                ),
            ),
        )

        self.assertFalse(form.is_valid())
        self.assertIn('subscription_started_at', form.errors)
        self.assertIn('subscription_expires_at', form.errors)

    def test_active_subscription_rejects_expired_end_date(self):
        doctor = self.create_user_with_role(
            'admin_form_expired_subscription',
            UserProfile.ROLE_DOCTOR,
        )
        started_at = timezone.now() - timedelta(days=30)
        expires_at = timezone.now() - timedelta(days=1)

        form = DoctorProfileAdminForm(
            data=self.build_form_data(
                doctor,
                subscription_status=(
                    DoctorProfile.SubscriptionStatus.ACTIVE
                ),
                subscription_started_at=started_at,
                subscription_expires_at=expires_at,
            ),
        )

        self.assertFalse(form.is_valid())
        self.assertIn('subscription_expires_at', form.errors)

    def test_active_subscription_with_future_expiry_is_valid(self):
        doctor = self.create_user_with_role(
            'admin_form_active_subscription',
            UserProfile.ROLE_DOCTOR,
        )
        started_at = timezone.now()
        expires_at = started_at + timedelta(days=30)

        form = DoctorProfileAdminForm(
            data=self.build_form_data(
                doctor,
                subscription_status=(
                    DoctorProfile.SubscriptionStatus.ACTIVE
                ),
                subscription_started_at=started_at,
                subscription_expires_at=expires_at,
            ),
        )

        self.assertTrue(form.is_valid(), form.errors.as_json())

    def test_existing_profile_user_is_readonly(self):
        from django.contrib.admin.sites import site

        doctor = self.create_user_with_role(
            'admin_readonly_doctor',
            UserProfile.ROLE_DOCTOR,
        )
        profile = DoctorProfile.objects.create(user=doctor)
        doctor_admin = site._registry[DoctorProfile]
        request = self.request_factory.get('/admin/doctors/')

        add_readonly_fields = doctor_admin.get_readonly_fields(
            request,
            obj=None,
        )
        change_readonly_fields = doctor_admin.get_readonly_fields(
            request,
            obj=profile,
        )

        self.assertNotIn('user', add_readonly_fields)
        self.assertIn('user', change_readonly_fields)

    def test_verification_transition_sets_and_clears_audit_fields(self):
        from django.contrib.admin.sites import site

        doctor = self.create_user_with_role(
            'admin_verified_doctor',
            UserProfile.ROLE_DOCTOR,
        )
        verifier = self.create_user_with_role(
            'admin_verifier_user',
            UserProfile.ROLE_ADMIN,
        )
        verifier.is_staff = True
        verifier.save(update_fields=['is_staff'])

        profile = DoctorProfile.objects.create(
            user=doctor,
            specialty=self.specialty,
            display_name='Dr. Verified Doctor',
            medical_license_number='LICENSE-ADMIN-2',
            phone_number='+10000000002',
            city='Test City',
            address='Verified Clinic Address',
        )

        doctor_admin = site._registry[DoctorProfile]
        request = self.request_factory.post('/admin/doctors/')
        request.user = verifier

        profile.verification_status = (
            DoctorProfile.VerificationStatus.VERIFIED
        )

        doctor_admin.save_model(
            request,
            profile,
            form=None,
            change=True,
        )

        profile.refresh_from_db()

        self.assertEqual(profile.verified_by, verifier)
        self.assertIsNotNone(profile.verified_at)

        profile.verification_status = (
            DoctorProfile.VerificationStatus.REJECTED
        )

        doctor_admin.save_model(
            request,
            profile,
            form=None,
            change=True,
        )

        profile.refresh_from_db()

        self.assertIsNone(profile.verified_by)
        self.assertIsNone(profile.verified_at)
