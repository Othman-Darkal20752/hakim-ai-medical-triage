enum SmokingStatus {
  unknown('unknown'),
  never('never'),
  former('former'),
  current('current');

  final String apiValue;

  const SmokingStatus(this.apiValue);

  static SmokingStatus fromApiValue(Object? value) {
    final normalizedValue = value?.toString();

    return SmokingStatus.values.firstWhere(
      (status) => status.apiValue == normalizedValue,
      orElse: () => SmokingStatus.unknown,
    );
  }
}

enum AlcoholUse {
  unknown('unknown'),
  never('never'),
  former('former'),
  current('current');

  final String apiValue;

  const AlcoholUse(this.apiValue);

  static AlcoholUse fromApiValue(Object? value) {
    final normalizedValue = value?.toString();

    return AlcoholUse.values.firstWhere(
      (status) => status.apiValue == normalizedValue,
      orElse: () => AlcoholUse.unknown,
    );
  }
}

enum PregnancyStatus {
  notApplicable('not_applicable'),
  unknown('unknown'),
  notPregnant('not_pregnant'),
  pregnant('pregnant');

  final String apiValue;

  const PregnancyStatus(this.apiValue);

  static PregnancyStatus fromApiValue(Object? value) {
    final normalizedValue = value?.toString();

    return PregnancyStatus.values.firstWhere(
      (status) => status.apiValue == normalizedValue,
      orElse: () => PregnancyStatus.unknown,
    );
  }
}

class PatientHealthProfile {
  final int id;
  final List<String> chronicConditions;
  final List<String> allergies;
  final List<String> currentMedications;
  final List<String> previousSurgeries;
  final SmokingStatus smokingStatus;
  final AlcoholUse alcoholUse;
  final PregnancyStatus pregnancyStatus;
  final DateTime? lastReviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PatientHealthProfile({
    required this.id,
    required this.chronicConditions,
    required this.allergies,
    required this.currentMedications,
    required this.previousSurgeries,
    required this.smokingStatus,
    required this.alcoholUse,
    required this.pregnancyStatus,
    required this.lastReviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PatientHealthProfile.fromJson(Map<String, dynamic> json) {
    return PatientHealthProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      chronicConditions: _parseStringList(json['chronic_conditions']),
      allergies: _parseStringList(json['allergies']),
      currentMedications: _parseStringList(json['current_medications']),
      previousSurgeries: _parseStringList(json['previous_surgeries']),
      smokingStatus: SmokingStatus.fromApiValue(json['smoking_status']),
      alcoholUse: AlcoholUse.fromApiValue(json['alcohol_use']),
      pregnancyStatus: PregnancyStatus.fromApiValue(json['pregnancy_status']),
      lastReviewedAt: _parseNullableDateTime(json['last_reviewed_at']),
      createdAt: _parseNullableDateTime(json['created_at']),
      updatedAt: _parseNullableDateTime(json['updated_at']),
    );
  }

  static List<String> _parseStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return List<String>.unmodifiable(value.whereType<String>());
  }

  static DateTime? _parseNullableDateTime(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '');
  }
}
