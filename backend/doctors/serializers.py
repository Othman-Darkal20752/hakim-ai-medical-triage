from rest_framework import serializers

from .models import DoctorProfile, Specialty


class SpecialtySerializer(serializers.ModelSerializer):
    class Meta:
        model = Specialty
        fields = (
            'id',
            'code',
            'name_ar',
            'name_en',
            'description_ar',
            'description_en',
        )
        read_only_fields = fields


class DoctorSelfProfileSerializer(serializers.ModelSerializer):
    specialty = SpecialtySerializer(read_only=True)
    specialty_id = serializers.PrimaryKeyRelatedField(
        source='specialty',
        queryset=Specialty.objects.filter(is_active=True),
        required=False,
        allow_null=True,
        write_only=True,
    )
    medical_license_number = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        max_length=100,
    )
    years_of_experience = serializers.IntegerField(
        required=False,
        allow_null=True,
        min_value=0,
        max_value=32767,
    )

    ADMIN_MANAGED_FIELDS = {
        'user',
        'verification_status',
        'verification_note',
        'verified_at',
        'verified_by',
        'subscription_status',
        'subscription_started_at',
        'subscription_expires_at',
    }

    VERIFICATION_REVIEW_FIELDS = {
        'display_name',
        'specialty',
        'medical_license_number',
        'phone_number',
        'city',
        'address',
    }

    class Meta:
        model = DoctorProfile
        fields = (
            'id',
            'specialty',
            'specialty_id',
            'display_name',
            'medical_license_number',
            'phone_number',
            'whatsapp_number',
            'city',
            'address',
            'bio',
            'years_of_experience',
            'working_hours',
            'verification_status',
            'verification_note',
            'verified_at',
            'subscription_status',
            'subscription_started_at',
            'subscription_expires_at',
            'created_at',
            'updated_at',
        )
        read_only_fields = (
            'id',
            'specialty',
            'verification_status',
            'verification_note',
            'verified_at',
            'subscription_status',
            'subscription_started_at',
            'subscription_expires_at',
            'created_at',
            'updated_at',
        )

    def to_internal_value(self, data):
        forbidden_fields = self.ADMIN_MANAGED_FIELDS.intersection(
            data.keys()
        )

        if forbidden_fields:
            raise serializers.ValidationError({
                field: 'This field is managed by administration.'
                for field in sorted(forbidden_fields)
            })

        return super().to_internal_value(data)

    def validate_medical_license_number(self, value):
        if value is None:
            return None

        normalized_value = value.strip()

        if not normalized_value:
            return None

        matching_profiles = DoctorProfile.objects.filter(
            medical_license_number=normalized_value,
        )

        if self.instance is not None:
            matching_profiles = matching_profiles.exclude(
                pk=self.instance.pk,
            )

        if matching_profiles.exists():
            raise serializers.ValidationError(
                'A doctor profile with this medical license number '
                'already exists.'
            )

        return normalized_value

    def update(self, instance, validated_data):
        requires_new_verification = any(
            field in validated_data
            and getattr(instance, field) != validated_data[field]
            for field in self.VERIFICATION_REVIEW_FIELDS
        )

        for field, value in validated_data.items():
            setattr(instance, field, value)

        if (
            requires_new_verification
            and instance.verification_status
            != DoctorProfile.VerificationStatus.PENDING
        ):
            instance.verification_status = (
                DoctorProfile.VerificationStatus.PENDING
            )
            instance.verification_note = ''
            instance.verified_at = None
            instance.verified_by = None

        instance.save()

        return instance
