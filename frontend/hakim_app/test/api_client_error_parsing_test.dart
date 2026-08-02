import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hakim_app/core/network/api_client.dart';

void main() {
  group('ApiClient error parsing', () {
    test('preserves DRF field validation errors', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'username': ['Username already exists.'],
            'password_confirm': ['Passwords do not match.'],
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: client);

      await expectLater(
        apiClient.post(
          '/auth/register/',
          body: const {
            'username': 'existing-user',
            'password': 'Test12345!',
            'password_confirm': 'Different123!',
            'role': 'patient',
          },
        ),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having(
                (error) => error.message,
                'message',
                'Username already exists.',
              )
              .having(
                (error) => error.errorsFor('username'),
                'username errors',
                ['Username already exists.'],
              )
              .having(
                (error) => error.errorsFor('password_confirm'),
                'password confirmation errors',
                ['Passwords do not match.'],
              ),
        ),
      );
    });

    test('prefers detail message while retaining field errors', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'Registration is temporarily unavailable.',
            'username': ['Invalid username.'],
          }),
          503,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: client);

      await expectLater(
        apiClient.post('/auth/register/', body: const {}),
        throwsA(
          isA<ApiException>()
              .having(
                (error) => error.message,
                'message',
                'Registration is temporarily unavailable.',
              )
              .having(
                (error) => error.errorsFor('username'),
                'username errors',
                ['Invalid username.'],
              ),
        ),
      );
    });

    test('PATCH preserves DRF field validation errors', () async {
      const requestBody = {
        'medical_license_number': 'LICENSE-001',
        'city': 'Damascus',
      };

      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path.endsWith('/doctors/me/'), isTrue);
        expect(request.headers['Authorization'], 'Bearer access-token');
        expect(jsonDecode(request.body), requestBody);

        return http.Response(
          jsonEncode({
            'medical_license_number': [
              'A doctor profile with this medical license number already exists.',
            ],
            'city': ['This field is invalid.'],
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: client);

      await expectLater(
        apiClient.patch(
          '/doctors/me/',
          body: requestBody,
          token: 'access-token',
        ),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having(
                (error) => error.errorsFor('medical_license_number'),
                'medical license errors',
                [
                  'A doctor profile with this medical license number already exists.',
                ],
              )
              .having((error) => error.errorsFor('city'), 'city errors', [
                'This field is invalid.',
              ]),
        ),
      );
    });
  });
}
