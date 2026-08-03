from django.conf import settings
from django.db import models


class PatientHealthProfile(models.Model):
    class SmokingStatus(models.TextChoices):
        UNKNOWN = 'unknown', 'Unknown'
        NEVER = 'never', 'Never'
        FORMER = 'former', 'Former'
        CURRENT = 'current', 'Current'

    class AlcoholUse(models.TextChoices):
        UNKNOWN = 'unknown', 'Unknown'
        NEVER = 'never', 'Never'
        FORMER = 'former', 'Former'
        CURRENT = 'current', 'Current'

    class PregnancyStatus(models.TextChoices):
        NOT_APPLICABLE = 'not_applicable', 'Not applicable'
        UNKNOWN = 'unknown', 'Unknown'
        NOT_PREGNANT = 'not_pregnant', 'Not pregnant'
        PREGNANT = 'pregnant', 'Pregnant'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='patient_health_profile',
    )

    chronic_conditions = models.JSONField(
        default=list,
        blank=True,
    )
    allergies = models.JSONField(
        default=list,
        blank=True,
    )
    current_medications = models.JSONField(
        default=list,
        blank=True,
    )
    previous_surgeries = models.JSONField(
        default=list,
        blank=True,
    )

    smoking_status = models.CharField(
        max_length=20,
        choices=SmokingStatus.choices,
        default=SmokingStatus.UNKNOWN,
    )
    alcohol_use = models.CharField(
        max_length=20,
        choices=AlcoholUse.choices,
        default=AlcoholUse.UNKNOWN,
    )
    pregnancy_status = models.CharField(
        max_length=20,
        choices=PregnancyStatus.choices,
        default=PregnancyStatus.NOT_APPLICABLE,
    )

    last_reviewed_at = models.DateTimeField(
        null=True,
        blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Patient health profile'
        verbose_name_plural = 'Patient health profiles'

    def __str__(self):
        return f'Health profile - {self.user.username}'