import 'patient_health_profile.dart';

class PatientHealthProfileUpdate {
  final List<String> chronicConditions;
  final List<String> allergies;
  final List<String> currentMedications;
  final List<String> previousSurgeries;
  final SmokingStatus smokingStatus;
  final AlcoholUse alcoholUse;
  final PregnancyStatus pregnancyStatus;

  const PatientHealthProfileUpdate({
    required this.chronicConditions,
    required this.allergies,
    required this.currentMedications,
    required this.previousSurgeries,
    required this.smokingStatus,
    required this.alcoholUse,
    required this.pregnancyStatus,
  });

  factory PatientHealthProfileUpdate.fromProfile(PatientHealthProfile profile) {
    return PatientHealthProfileUpdate(
      chronicConditions: profile.chronicConditions,
      allergies: profile.allergies,
      currentMedications: profile.currentMedications,
      previousSurgeries: profile.previousSurgeries,
      smokingStatus: profile.smokingStatus,
      alcoholUse: profile.alcoholUse,
      pregnancyStatus: profile.pregnancyStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chronic_conditions': chronicConditions,
      'allergies': allergies,
      'current_medications': currentMedications,
      'previous_surgeries': previousSurgeries,
      'smoking_status': smokingStatus.apiValue,
      'alcohol_use': alcoholUse.apiValue,
      'pregnancy_status': pregnancyStatus.apiValue,
    };
  }
}
