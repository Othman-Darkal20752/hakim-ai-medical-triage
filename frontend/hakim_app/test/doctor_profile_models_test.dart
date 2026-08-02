import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/features/doctor/data/doctor_profile.dart';
import 'package:hakim_app/features/doctor/data/doctor_profile_update.dart';
import 'package:hakim_app/features/doctor/data/specialty.dart';

void main() {
  group('Doctor profile models', () {
    test('Specialty parses bilingual API fields', () {
      final specialty = Specialty.fromJson({
        'id': 7,
        'code': 'cardiology',
        'name_ar': 'أمراض القلب',
        'name_en': 'Cardiology',
        'description_ar': 'وصف عربي',
        'description_en': 'English description',
      });

      expect(specialty.id, 7);
      expect(specialty.code, 'cardiology');
      expect(specialty.nameAr, 'أمراض القلب');
      expect(specialty.nameEn, 'Cardiology');
      expect(specialty.descriptionAr, 'وصف عربي');
      expect(specialty.descriptionEn, 'English description');
    });

    test('DoctorProfile parses nested specialty and account states', () {
      final profile = DoctorProfile.fromJson({
        'id': 12,
        'is_profile_complete': true,
        'specialty': {
          'id': 7,
          'code': 'cardiology',
          'name_ar': 'أمراض القلب',
          'name_en': 'Cardiology',
          'description_ar': '',
          'description_en': '',
        },
        'display_name': 'Doctor One',
        'medical_license_number': 'LICENSE-001',
        'phone_number': '+963999000000',
        'whatsapp_number': '+963999000001',
        'city': 'Damascus',
        'address': 'Clinic address',
        'bio': 'Professional biography',
        'years_of_experience': 8,
        'working_hours': 'Sunday to Thursday',
        'verification_status': 'pending',
        'verification_note': '',
        'verified_at': null,
        'subscription_status': 'inactive',
        'subscription_started_at': null,
        'subscription_expires_at': null,
        'created_at': '2026-08-02T10:00:00Z',
        'updated_at': '2026-08-02T11:00:00Z',
      });

      expect(profile.id, 12);
      expect(profile.isProfileComplete, isTrue);
      expect(profile.specialty?.code, 'cardiology');
      expect(profile.medicalLicenseNumber, 'LICENSE-001');
      expect(profile.yearsOfExperience, 8);
      expect(profile.verificationStatus, 'pending');
      expect(profile.subscriptionStatus, 'inactive');
      expect(profile.verifiedAt, isNull);
      expect(profile.createdAt, DateTime.utc(2026, 8, 2, 10));
      expect(profile.updatedAt, DateTime.utc(2026, 8, 2, 11));
    });

    test('DoctorProfileUpdate serializes the onboarding payload', () {
      const update = DoctorProfileUpdate(
        displayName: 'Doctor One',
        specialtyId: 7,
        medicalLicenseNumber: 'LICENSE-001',
        phoneNumber: '+963999000000',
        whatsappNumber: '+963999000001',
        city: 'Damascus',
        address: 'Clinic address',
        bio: 'Professional biography',
        yearsOfExperience: 8,
        workingHours: 'Sunday to Thursday',
      );

      expect(update.toJson(), {
        'display_name': 'Doctor One',
        'specialty_id': 7,
        'medical_license_number': 'LICENSE-001',
        'phone_number': '+963999000000',
        'whatsapp_number': '+963999000001',
        'city': 'Damascus',
        'address': 'Clinic address',
        'bio': 'Professional biography',
        'years_of_experience': 8,
        'working_hours': 'Sunday to Thursday',
      });
    });
  });
}
