import 'specialty.dart';

class DoctorProfile {
  final int id;
  final bool isProfileComplete;
  final Specialty? specialty;
  final String displayName;
  final String? medicalLicenseNumber;
  final String phoneNumber;
  final String whatsappNumber;
  final String city;
  final String address;
  final String bio;
  final int? yearsOfExperience;
  final String workingHours;
  final String verificationStatus;
  final String verificationNote;
  final DateTime? verifiedAt;
  final String subscriptionStatus;
  final DateTime? subscriptionStartedAt;
  final DateTime? subscriptionExpiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DoctorProfile({
    required this.id,
    required this.isProfileComplete,
    required this.specialty,
    required this.displayName,
    required this.medicalLicenseNumber,
    required this.phoneNumber,
    required this.whatsappNumber,
    required this.city,
    required this.address,
    required this.bio,
    required this.yearsOfExperience,
    required this.workingHours,
    required this.verificationStatus,
    required this.verificationNote,
    required this.verifiedAt,
    required this.subscriptionStatus,
    required this.subscriptionStartedAt,
    required this.subscriptionExpiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    final specialtyJson = json['specialty'];

    return DoctorProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      isProfileComplete: json['is_profile_complete'] == true,
      specialty: specialtyJson is Map
          ? Specialty.fromJson(Map<String, dynamic>.from(specialtyJson))
          : null,
      displayName: json['display_name']?.toString() ?? '',
      medicalLicenseNumber: json['medical_license_number']?.toString(),
      phoneNumber: json['phone_number']?.toString() ?? '',
      whatsappNumber: json['whatsapp_number']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      yearsOfExperience: _parseNullableInt(json['years_of_experience']),
      workingHours: json['working_hours']?.toString() ?? '',
      verificationStatus: json['verification_status']?.toString() ?? '',
      verificationNote: json['verification_note']?.toString() ?? '',
      verifiedAt: _parseNullableDateTime(json['verified_at']),
      subscriptionStatus: json['subscription_status']?.toString() ?? '',
      subscriptionStartedAt: _parseNullableDateTime(
        json['subscription_started_at'],
      ),
      subscriptionExpiresAt: _parseNullableDateTime(
        json['subscription_expires_at'],
      ),
      createdAt: _parseNullableDateTime(json['created_at']),
      updatedAt: _parseNullableDateTime(json['updated_at']),
    );
  }

  static int? _parseNullableInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _parseNullableDateTime(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '');
  }
}
