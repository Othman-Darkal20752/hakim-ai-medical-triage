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