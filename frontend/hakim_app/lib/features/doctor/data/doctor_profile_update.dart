class DoctorProfileUpdate {
  final String displayName;
  final int specialtyId;
  final String medicalLicenseNumber;
  final String phoneNumber;
  final String whatsappNumber;
  final String city;
  final String address;
  final String bio;
  final int? yearsOfExperience;
  final String workingHours;

  const DoctorProfileUpdate({
    required this.displayName,
    required this.specialtyId,
    required this.medicalLicenseNumber,
    required this.phoneNumber,
    this.whatsappNumber = '',
    required this.city,
    required this.address,
    this.bio = '',
    this.yearsOfExperience,
    this.workingHours = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'specialty_id': specialtyId,
      'medical_license_number': medicalLicenseNumber,
      'phone_number': phoneNumber,
      'whatsapp_number': whatsappNumber,
      'city': city,
      'address': address,
      'bio': bio,
      'years_of_experience': yearsOfExperience,
      'working_hours': workingHours,
    };
  }
}
