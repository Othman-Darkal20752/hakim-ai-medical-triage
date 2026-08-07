from django.db import migrations


INITIAL_SPECIALTIES = (
    {
        "code": "general_medicine",
        "name_ar": "\u0637\u0628 \u0639\u0627\u0645",
        "name_en": "General Medicine",
        "display_order": 1,
    },
    {
        "code": "internal_medicine",
        "name_ar": "\u0637\u0628 \u0628\u0627\u0637\u0646\u064a",
        "name_en": "Internal Medicine",
        "display_order": 2,
    },
    {
        "code": "cardiology",
        "name_ar": "\u0642\u0644\u0628\u064a\u0629",
        "name_en": "Cardiology",
        "display_order": 3,
    },
    {
        "code": "pediatrics",
        "name_ar": "\u0623\u0637\u0641\u0627\u0644",
        "name_en": "Pediatrics",
        "display_order": 4,
    },
    {
        "code": "dermatology",
        "name_ar": "\u062c\u0644\u062f\u064a\u0629",
        "name_en": "Dermatology",
        "display_order": 5,
    },
    {
        "code": "dentistry",
        "name_ar": "\u0623\u0633\u0646\u0627\u0646",
        "name_en": "Dentistry",
        "display_order": 6,
    },
    {
        "code": "gynecology",
        "name_ar": "\u0646\u0633\u0627\u0626\u064a\u0629 \u0648\u062a\u0648\u0644\u064a\u062f",
        "name_en": "Gynecology and Obstetrics",
        "display_order": 7,
    },
    {
        "code": "ent",
        "name_ar": "\u0623\u0646\u0641 \u0623\u0630\u0646 \u062d\u0646\u062c\u0631\u0629",
        "name_en": "Ear, Nose and Throat",
        "display_order": 8,
    },
)


def seed_initial_specialties(apps, schema_editor):
    Specialty = apps.get_model("doctors", "Specialty")
    database_alias = schema_editor.connection.alias

    for specialty_data in INITIAL_SPECIALTIES:
        code = specialty_data["code"]
        defaults = {
            key: value
            for key, value in specialty_data.items()
            if key != "code"
        }

        Specialty.objects.using(
            database_alias
        ).get_or_create(
            code=code,
            defaults=defaults,
        )


class Migration(migrations.Migration):

    dependencies = [
        ("doctors", "0002_doctorprofile"),
    ]

    operations = [
        migrations.RunPython(
            seed_initial_specialties,
            migrations.RunPython.noop,
        ),
    ]
