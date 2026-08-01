from django.conf import settings
from django.core.validators import RegexValidator
from django.db import models


specialty_code_validator = RegexValidator(
    regex=r'^[a-z0-9]+(?:_[a-z0-9]+)*$',
    message=(
        'Specialty code may contain only lowercase letters, numbers, '
        'and single underscores between words.'
    ),
)


class Specialty(models.Model):
    code = models.SlugField(
        max_length=50,
        unique=True,
        validators=[specialty_code_validator],
    )
    name_ar = models.CharField(max_length=100)
    name_en = models.CharField(max_length=100)
    description_ar = models.TextField(blank=True)
    description_en = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    display_order = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ('display_order', 'name_en', 'id')
        verbose_name = 'Specialty'
        verbose_name_plural = 'Specialties'

    def __str__(self):
        return f'{self.name_en} ({self.code})'


class DoctorProfile(models.Model):
    class VerificationStatus(models.TextChoices):
        PENDING = 'pending', 'Pending'
        VERIFIED = 'verified', 'Verified'
        REJECTED = 'rejected', 'Rejected'

    class SubscriptionStatus(models.TextChoices):
        INACTIVE = 'inactive', 'Inactive'
        ACTIVE = 'active', 'Active'
        EXPIRED = 'expired', 'Expired'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='doctor_profile',
    )
    specialty = models.ForeignKey(
        Specialty,
        on_delete=models.PROTECT,
        related_name='doctors',
        null=True,
        blank=True,
    )

    display_name = models.CharField(max_length=150, blank=True)
    medical_license_number = models.CharField(
        max_length=100,
        unique=True,
        null=True,
        blank=True,
    )

    phone_number = models.CharField(max_length=32, blank=True)
    whatsapp_number = models.CharField(max_length=32, blank=True)
    city = models.CharField(
        max_length=100,
        blank=True,
        db_index=True,
    )
    address = models.TextField(blank=True)

    bio = models.TextField(blank=True)
    years_of_experience = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
    )
    working_hours = models.TextField(blank=True)

    verification_status = models.CharField(
        max_length=20,
        choices=VerificationStatus.choices,
        default=VerificationStatus.PENDING,
        db_index=True,
    )
    verification_note = models.TextField(blank=True)
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name='verified_doctor_profiles',
        null=True,
        blank=True,
    )

    subscription_status = models.CharField(
        max_length=20,
        choices=SubscriptionStatus.choices,
        default=SubscriptionStatus.INACTIVE,
        db_index=True,
    )
    subscription_started_at = models.DateTimeField(
        null=True,
        blank=True,
    )
    subscription_expires_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ('display_name', 'id')
        indexes = [
            models.Index(
                fields=(
                    'specialty',
                    'verification_status',
                    'subscription_status',
                ),
                name='doctor_lookup_idx',
            ),
        ]
        constraints = [
            models.CheckConstraint(
                condition=(
                    models.Q(subscription_started_at__isnull=True)
                    | models.Q(subscription_expires_at__isnull=True)
                    | models.Q(
                        subscription_expires_at__gt=models.F(
                            'subscription_started_at'
                        )
                    )
                ),
                name='doctor_subscription_dates_valid',
            ),
        ]

    def __str__(self):
        return self.display_name or self.user.username