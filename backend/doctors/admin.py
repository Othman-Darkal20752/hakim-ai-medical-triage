from django import forms
from django.contrib import admin
from django.utils import timezone

from accounts.models import UserProfile

from .models import DoctorProfile, Specialty


class DoctorProfileAdminForm(forms.ModelForm):
    class Meta:
        model = DoctorProfile
        fields = '__all__'

    def clean(self):
        cleaned_data = super().clean()

        user = cleaned_data.get('user')
        if user is None and self.instance.pk:
            user = self.instance.user

        if user is not None:
            role = (
                UserProfile.objects
                .filter(user=user)
                .values_list('role', flat=True)
                .first()
            )

            if role != UserProfile.ROLE_DOCTOR:
                message = (
                    'DoctorProfile can only be linked to a user whose '
                    'UserProfile role is doctor.'
                )

                if 'user' in self.fields:
                    self.add_error('user', message)
                else:
                    raise forms.ValidationError(message)

        verification_status = cleaned_data.get('verification_status')

        if (
            verification_status
            == DoctorProfile.VerificationStatus.VERIFIED
        ):
            required_fields = (
                'display_name',
                'specialty',
                'medical_license_number',
                'phone_number',
                'city',
                'address',
            )

            for field_name in required_fields:
                if not cleaned_data.get(field_name):
                    self.add_error(
                        field_name,
                        'This field is required before verifying a doctor.',
                    )

        subscription_status = cleaned_data.get('subscription_status')
        started_at = cleaned_data.get('subscription_started_at')
        expires_at = cleaned_data.get('subscription_expires_at')

        if started_at and expires_at and expires_at <= started_at:
            self.add_error(
                'subscription_expires_at',
                'Subscription expiry must be after its start date.',
            )

        if (
            subscription_status
            == DoctorProfile.SubscriptionStatus.ACTIVE
        ):
            if started_at is None:
                self.add_error(
                    'subscription_started_at',
                    'An active subscription requires a start date.',
                )

            if expires_at is None:
                self.add_error(
                    'subscription_expires_at',
                    'An active subscription requires an expiry date.',
                )
            elif expires_at <= timezone.now():
                self.add_error(
                    'subscription_expires_at',
                    'An active subscription cannot already be expired.',
                )

        return cleaned_data


@admin.register(Specialty)
class SpecialtyAdmin(admin.ModelAdmin):
    list_display = (
        'code',
        'name_ar',
        'name_en',
        'is_active',
        'display_order',
        'updated_at',
    )
    list_filter = ('is_active',)
    search_fields = ('code', 'name_ar', 'name_en')
    ordering = ('display_order', 'name_en', 'id')
    readonly_fields = ('created_at', 'updated_at')

    fieldsets = (
        (
            None,
            {
                'fields': (
                    'code',
                    'name_ar',
                    'name_en',
                    'description_ar',
                    'description_en',
                ),
            },
        ),
        (
            'Display settings',
            {
                'fields': (
                    'is_active',
                    'display_order',
                ),
            },
        ),
        (
            'Timestamps',
            {
                'fields': (
                    'created_at',
                    'updated_at',
                ),
            },
        ),
    )


@admin.register(DoctorProfile)
class DoctorProfileAdmin(admin.ModelAdmin):
    form = DoctorProfileAdminForm

    list_display = (
        'display_name',
        'user_username',
        'specialty',
        'verification_status',
        'subscription_status',
        'city',
        'updated_at',
    )
    list_filter = (
        'verification_status',
        'subscription_status',
        'specialty',
    )
    search_fields = (
        'display_name',
        'medical_license_number',
        'user__username',
        'user__email',
        'city',
    )
    ordering = ('display_name', 'id')
    list_select_related = (
        'user',
        'specialty',
        'verified_by',
    )
    autocomplete_fields = (
        'user',
        'specialty',
    )
    readonly_fields = (
        'verified_by',
        'verified_at',
        'created_at',
        'updated_at',
    )
    date_hierarchy = 'created_at'

    fieldsets = (
        (
            'Account',
            {
                'fields': (
                    'user',
                    'display_name',
                ),
            },
        ),
        (
            'Professional information',
            {
                'fields': (
                    'specialty',
                    'medical_license_number',
                    'years_of_experience',
                    'bio',
                ),
            },
        ),
        (
            'Contact and workplace',
            {
                'fields': (
                    'phone_number',
                    'whatsapp_number',
                    'city',
                    'address',
                    'working_hours',
                ),
            },
        ),
        (
            'Verification',
            {
                'fields': (
                    'verification_status',
                    'verification_note',
                    'verified_by',
                    'verified_at',
                ),
            },
        ),
        (
            'Subscription',
            {
                'fields': (
                    'subscription_status',
                    'subscription_started_at',
                    'subscription_expires_at',
                ),
            },
        ),
        (
            'Timestamps',
            {
                'fields': (
                    'created_at',
                    'updated_at',
                ),
            },
        ),
    )

    @admin.display(
        description='User',
        ordering='user__username',
    )
    def user_username(self, obj):
        return obj.user.username

    def get_readonly_fields(self, request, obj=None):
        readonly_fields = list(
            super().get_readonly_fields(request, obj)
        )

        if obj is not None:
            readonly_fields.insert(0, 'user')

        return tuple(readonly_fields)

    def save_model(self, request, obj, form, change):
        previous_status = None

        if change and obj.pk:
            previous_status = (
                DoctorProfile.objects
                .filter(pk=obj.pk)
                .values_list('verification_status', flat=True)
                .first()
            )

        if (
            obj.verification_status
            == DoctorProfile.VerificationStatus.VERIFIED
        ):
            if (
                previous_status
                != DoctorProfile.VerificationStatus.VERIFIED
                or obj.verified_at is None
            ):
                obj.verified_by = request.user
                obj.verified_at = timezone.now()
        else:
            obj.verified_by = None
            obj.verified_at = None

        super().save_model(request, obj, form, change)