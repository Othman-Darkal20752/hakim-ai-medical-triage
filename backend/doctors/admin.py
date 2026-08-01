from django.contrib import admin

from .models import Specialty


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