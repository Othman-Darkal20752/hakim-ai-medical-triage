from django.utils import timezone
from rest_framework import serializers

from .models import PatientHealthProfile


class MedicalStringListField(serializers.ListField):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault(
            'child',
            serializers.CharField(
                allow_blank=False,
                trim_whitespace=True,
                max_length=200,
            ),
        )
        kwargs.setdefault('required', False)
        kwargs.setdefault('max_length', 50)

        super().__init__(*args, **kwargs)


class PatientHealthProfileSerializer(serializers.ModelSerializer):
    chronic_conditions = MedicalStringListField()
    allergies = MedicalStringListField()
    current_medications = MedicalStringListField()
    previous_surgeries = MedicalStringListField()

    SERVER_MANAGED_FIELDS = {
        'id',
        'user',
        'last_reviewed_at',
        'created_at',
        'updated_at',
    }

    class Meta:
        model = PatientHealthProfile
        fields = (
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
        )
        read_only_fields = (
            'id',
            'last_reviewed_at',
            'created_at',
            'updated_at',
        )

    def to_internal_value(self, data):
        forbidden_fields = self.SERVER_MANAGED_FIELDS.intersection(
            data.keys()
        )

        if forbidden_fields:
            raise serializers.ValidationError({
                field: 'This field is managed by the server.'
                for field in sorted(forbidden_fields)
            })

        return super().to_internal_value(data)

    def update(self, instance, validated_data):
        for field, value in validated_data.items():
            setattr(instance, field, value)

        instance.last_reviewed_at = timezone.now()
        instance.save()

        return instance
