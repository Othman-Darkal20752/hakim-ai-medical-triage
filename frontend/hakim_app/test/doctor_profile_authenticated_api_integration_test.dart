import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/core/network/authenticated_api_client.dart';
import 'package:hakim_app/features/auth/data/session_expired_exception.dart';
import 'package:hakim_app/features/doctor/data/doctor_profile_api.dart';
import 'package:hakim_app/features/doctor/data/doctor_profile_update.dart';

void main() {
  group('DoctorProfileApi authenticated integration', () {
    test('loads the authenticated doctor profile', () async {
      final httpClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path.endsWith('/doctors/me/'), isTrue);
        expect(request.headers['Authorization'], 'Bearer access-token');

        return http.Response(
          jsonEncode(_profileResponse(isProfileComplete: false)),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = DoctorProfileApi(_authenticatedClient(httpClient));
      final profile = await api.getProfile();

      expect(profile.id, 12);
      expect(profile.isProfileComplete, isFalse);
      expect(profile.verificationStatus, 'pending');
      expect(profile.subscriptionStatus, 'inactive');
    });

    test('loads specialties from the wrapped response object', () async {
      final httpClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path.endsWith('/doctors/specialties/'), isTrue);
        expect(request.headers['Authorization'], 'Bearer access-token');

        return http.Response(
          jsonEncode({
            'specialties': [
              {
                'id': 7,
                'code': 'cardiology',
                'name_ar': 'أمراض القلب',
                'name_en': 'Cardiology',
                'description_ar': '',
                'description_en': '',
              },
              {
                'id': 8,
                'code': 'dermatology',
                'name_ar': 'الأمراض الجلدية',
                'name_en': 'Dermatology',
                'description_ar': '',
                'description_en': '',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = DoctorProfileApi(_authenticatedClient(httpClient));
      final specialties = await api.getSpecialties();

      expect(specialties, hasLength(2));
      expect(specialties.first.code, 'cardiology');
      expect(specialties.last.nameEn, 'Dermatology');
    });

    test('updates the authenticated doctor profile using PATCH', () async {
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

      final httpClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path.endsWith('/doctors/me/'), isTrue);
        expect(request.headers['Authorization'], 'Bearer access-token');
        expect(jsonDecode(request.body), update.toJson());

        return http.Response(
          jsonEncode(_profileResponse(isProfileComplete: true)),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = DoctorProfileApi(_authenticatedClient(httpClient));
      final profile = await api.updateProfile(update);

      expect(profile.isProfileComplete, isTrue);
      expect(profile.displayName, 'Doctor One');
      expect(profile.specialty?.id, 7);
    });
  });
}

AuthenticatedApiClient _authenticatedClient(http.Client client) {
  return AuthenticatedApiClient(
    apiClient: ApiClient(client: client),
    readAccessToken: () async => 'access-token',
    refreshAccessToken: () async {
      throw StateError('Refresh should not be called.');
    },
    expireSession: () async {
      throw const SessionExpiredException();
    },
  );
}

Map<String, dynamic> _profileResponse({required bool isProfileComplete}) {
  return {
    'id': 12,
    'is_profile_complete': isProfileComplete,
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
  };
}
