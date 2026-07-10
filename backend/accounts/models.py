from django.conf import settings
from django.db import models


class UserProfile(models.Model):
    ROLE_PATIENT = 'patient'
    ROLE_DOCTOR = 'doctor'
    ROLE_ADMIN = 'admin'

    ROLE_CHOICES = [
        (ROLE_PATIENT, 'Patient'),
        (ROLE_DOCTOR, 'Doctor'),
        (ROLE_ADMIN, 'Admin'),
    ]

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='profile',
    )
    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default=ROLE_PATIENT,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.user.username} - {self.role}'


class ExternalIdentity(models.Model):
    PROVIDER_GOOGLE = 'google'

    PROVIDER_CHOICES = [
        (PROVIDER_GOOGLE, 'Google'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='external_identities',
    )
    provider = models.CharField(
        max_length=30,
        choices=PROVIDER_CHOICES,
    )
    subject = models.CharField(max_length=255)
    email = models.EmailField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['provider', 'subject'],
                name='unique_external_identity',
            ),
        ]

    def __str__(self):
        return f'{self.provider}:{self.subject} -> {self.user.username}'
