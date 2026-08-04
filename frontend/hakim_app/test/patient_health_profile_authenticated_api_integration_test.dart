import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/core/network/authenticated_api_client.dart';
import 'package:hakim_app/features/auth/data/session_expired_exception.dart';
import 'package:hakim_app/features/patient/data/patient_health_profile.dart';
import 'package:hakim_app/features/patient/data/patient_health_profile_api.dart';
import 'package:hakim_app/features/patient/data/patient_health_profile_update.dart';

void main() {
  group('PatientHealthProfileApi authenticated integration', () {
    test('loads the authenticated patient health profile', () async {
      final httpClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path.endsWith('/patients/health-profile/'), isTrue);
        expect(request.headers['Authorization'], 'Bearer access-token');

        return http.Response(
          jsonEncode(_profileResponse()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = PatientHealthProfileApi(_authenticatedClient(httpClient));

      final profile = await api.getProfile();

      expect(profile.id, 15);
      expect(profile.chronicConditions, ['Asthma']);
      expect(profile.smokingStatus, SmokingStatus.former);
      expect(profile.pregnancyStatus, PregnancyStatus.notApplicable);
    });

    test(
      'updates editable patient health profile fields using PATCH',
      () async {
        const update = PatientHealthProfileUpdate(
          chronicConditions: ['Asthma'],
          allergies: ['Penicillin'],
          currentMedications: ['Medication A'],
          previousSurgeries: ['Appendectomy'],
          smokingStatus: SmokingStatus.never,
          alcoholUse: AlcoholUse.never,
          pregnancyStatus: PregnancyStatus.notPregnant,
        );

        final httpClient = MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(
            request.url.path.endsWith('/patients/health-profile/'),
            isTrue,
          );
          expect(request.headers['Authorization'], 'Bearer access-token');
          expect(jsonDecode(request.body), update.toJson());

          return http.Response(
            jsonEncode(
              _profileResponse(
                smokingStatus: 'never',
                pregnancyStatus: 'not_pregnant',
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final api = PatientHealthProfileApi(_authenticatedClient(httpClient));

        final profile = await api.updateProfile(update);

        expect(profile.smokingStatus, SmokingStatus.never);
        expect(profile.pregnancyStatus, PregnancyStatus.notPregnant);
      },
    );

    test('marks the health profile as reviewed using an empty PATCH', () async {
      final httpClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path.endsWith('/patients/health-profile/'), isTrue);
        expect(request.headers['Authorization'], 'Bearer access-token');
        expect(jsonDecode(request.body), isEmpty);

        return http.Response(
          jsonEncode(_profileResponse()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = PatientHealthProfileApi(_authenticatedClient(httpClient));

      final profile = await api.markReviewed();

      expect(profile.id, 15);
      expect(profile.lastReviewedAt, isNotNull);
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

Map<String, dynamic> _profileResponse({
  String smokingStatus = 'former',
  String pregnancyStatus = 'not_applicable',
}) {
  return {
    'id': 15,
    'chronic_conditions': ['Asthma'],
    'allergies': ['Penicillin'],
    'current_medications': ['Medication A'],
    'previous_surgeries': ['Appendectomy'],
    'smoking_status': smokingStatus,
    'alcohol_use': 'never',
    'pregnancy_status': pregnancyStatus,
    'last_reviewed_at': '2026-08-04T07:00:00Z',
    'created_at': '2026-08-03T10:00:00Z',
    'updated_at': '2026-08-04T07:00:00Z',
  };
}
