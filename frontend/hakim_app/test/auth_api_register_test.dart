import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/features/auth/data/auth_api.dart';

void main() {
  group('AuthApi.register', () {
    test(
      'sends the public registration payload to the register endpoint',
      () async {
        var requestCount = 0;

        final client = MockClient((request) async {
          requestCount++;

          expect(request.method, 'POST');
          expect(request.url.path.endsWith('/auth/register/'), isTrue);
          expect(request.headers['Content-Type'], 'application/json');

          expect(jsonDecode(request.body), {
            'username': 'doctor-user',
            'email': 'doctor@example.com',
            'password': 'Test12345!',
            'password_confirm': 'Test12345!',
            'role': 'doctor',
          });

          return http.Response(
            jsonEncode({
              'user': {
                'id': 42,
                'username': 'doctor-user',
                'email': 'doctor@example.com',
                'role': 'doctor',
              },
              'access': 'access-token',
              'refresh': 'refresh-token',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        });

        final authApi = AuthApi(ApiClient(client: client));

        final result = await authApi.register(
          username: 'doctor-user',
          email: 'doctor@example.com',
          password: 'Test12345!',
          passwordConfirm: 'Test12345!',
          role: 'doctor',
        );

        expect(requestCount, 1);
        expect(result['access'], 'access-token');
        expect(result['refresh'], 'refresh-token');
        expect(result['user'], {
          'id': 42,
          'username': 'doctor-user',
          'email': 'doctor@example.com',
          'role': 'doctor',
        });
      },
    );

    test('omits email when it is not provided', () async {
      final client = MockClient((request) async {
        expect(jsonDecode(request.body), {
          'username': 'patient-user',
          'password': 'Test12345!',
          'password_confirm': 'Test12345!',
          'role': 'patient',
        });

        return http.Response(
          jsonEncode({
            'user': {
              'id': 43,
              'username': 'patient-user',
              'email': '',
              'role': 'patient',
            },
            'access': 'access-token',
            'refresh': 'refresh-token',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final authApi = AuthApi(ApiClient(client: client));

      await authApi.register(
        username: 'patient-user',
        password: 'Test12345!',
        passwordConfirm: 'Test12345!',
        role: 'patient',
      );
    });
  });
}
