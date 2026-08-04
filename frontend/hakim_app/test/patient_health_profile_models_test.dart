import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/features/patient/data/patient_health_profile.dart';
import 'package:hakim_app/features/patient/data/patient_health_profile_update.dart';

void main() {
  group('Patient health profile models', () {
    test('PatientHealthProfile parses medical profile API fields', () {
      final profile = PatientHealthProfile.fromJson({
        'id': 15,
        'chronic_conditions': ['Asthma', 'Diabetes'],
        'allergies': ['Penicillin'],
        'current_medications': ['Medication A'],
        'previous_surgeries': ['Appendectomy'],
        'smoking_status': 'former',
        'alcohol_use': 'never',
        'pregnancy_status': 'not_applicable',
        'last_reviewed_at': '2026-08-04T07:00:00Z',
        'created_at': '2026-08-03T10:00:00Z',
        'updated_at': '2026-08-04T07:00:00Z',
      });

      expect(profile.id, 15);
      expect(profile.chronicConditions, ['Asthma', 'Diabetes']);
      expect(profile.allergies, ['Penicillin']);
      expect(profile.currentMedications, ['Medication A']);
      expect(profile.previousSurgeries, ['Appendectomy']);
      expect(profile.smokingStatus, SmokingStatus.former);
      expect(profile.alcoholUse, AlcoholUse.never);
      expect(profile.pregnancyStatus, PregnancyStatus.notApplicable);
      expect(profile.lastReviewedAt, DateTime.utc(2026, 8, 4, 7));
      expect(profile.createdAt, DateTime.utc(2026, 8, 3, 10));
      expect(profile.updatedAt, DateTime.utc(2026, 8, 4, 7));
    });

    test('uses safe defaults for missing or unsupported values', () {
      final profile = PatientHealthProfile.fromJson({
        'id': 2,
        'smoking_status': 'unsupported',
        'alcohol_use': 'unsupported',
        'pregnancy_status': 'unsupported',
      });

      expect(profile.chronicConditions, isEmpty);
      expect(profile.allergies, isEmpty);
      expect(profile.currentMedications, isEmpty);
      expect(profile.previousSurgeries, isEmpty);
      expect(profile.smokingStatus, SmokingStatus.unknown);
      expect(profile.alcoholUse, AlcoholUse.unknown);
      expect(profile.pregnancyStatus, PregnancyStatus.unknown);
      expect(profile.lastReviewedAt, isNull);
      expect(profile.createdAt, isNull);
      expect(profile.updatedAt, isNull);
    });

    test('PatientHealthProfileUpdate serializes editable fields only', () {
      const update = PatientHealthProfileUpdate(
        chronicConditions: ['Asthma'],
        allergies: ['Penicillin'],
        currentMedications: ['Medication A'],
        previousSurgeries: ['Appendectomy'],
        smokingStatus: SmokingStatus.never,
        alcoholUse: AlcoholUse.former,
        pregnancyStatus: PregnancyStatus.notPregnant,
      );

      expect(update.toJson(), {
        'chronic_conditions': ['Asthma'],
        'allergies': ['Penicillin'],
        'current_medications': ['Medication A'],
        'previous_surgeries': ['Appendectomy'],
        'smoking_status': 'never',
        'alcohol_use': 'former',
        'pregnancy_status': 'not_pregnant',
      });
    });
  });
}
