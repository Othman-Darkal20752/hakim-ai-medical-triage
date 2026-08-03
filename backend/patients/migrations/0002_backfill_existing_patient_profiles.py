from django.db import migrations


def create_existing_patient_health_profiles(apps, schema_editor):
    UserProfile = apps.get_model('accounts', 'UserProfile')
    PatientHealthProfile = apps.get_model(
        'patients',
        'PatientHealthProfile',
    )

    database_alias = schema_editor.connection.alias

    patient_user_ids = list(
        UserProfile.objects.using(database_alias)
        .filter(role='patient')
        .values_list('user_id', flat=True)
    )

    existing_user_ids = set(
        PatientHealthProfile.objects.using(database_alias)
        .filter(user_id__in=patient_user_ids)
        .values_list('user_id', flat=True)
    )

    profiles_to_create = [
        PatientHealthProfile(user_id=user_id)
        for user_id in patient_user_ids
        if user_id not in existing_user_ids
    ]

    PatientHealthProfile.objects.using(database_alias).bulk_create(
        profiles_to_create,
    )


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0002_externalidentity'),
        ('patients', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(
            create_existing_patient_health_profiles,
            migrations.RunPython.noop,
        ),
    ]