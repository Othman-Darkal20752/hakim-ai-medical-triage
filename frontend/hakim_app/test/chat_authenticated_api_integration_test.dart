import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/core/network/authenticated_api_client.dart';
import 'package:hakim_app/features/auth/data/session_expired_exception.dart';
import 'package:hakim_app/features/chat/data/chat_api.dart';

void main() {
  test(
    'ChatApi sends a protected message through AuthenticatedApiClient',
    () async {
      var requestCount = 0;

      final httpClient = MockClient((request) async {
        requestCount++;

        expect(request.method, 'POST');
        expect(request.url.path.endsWith('/chat/messages/'), isTrue);
        expect(request.headers['Authorization'], 'Bearer access-token');
        expect(jsonDecode(request.body), {
          'message': 'I have a headache.',
          'session_id': 'session-42',
        });

        return http.Response(
          jsonEncode({
            'reply': 'Preliminary medical guidance.',
            'session_id': 'session-42',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authenticatedClient = AuthenticatedApiClient(
        apiClient: ApiClient(client: httpClient),
        readAccessToken: () async => 'access-token',
        refreshAccessToken: () async {
          throw StateError('Refresh should not be called.');
        },
        expireSession: () async {
          throw const SessionExpiredException();
        },
      );

      final result = await ChatApi(
        authenticatedClient,
      ).sendMessage(message: 'I have a headache.', sessionId: 'session-42');

      expect(result.reply, 'Preliminary medical guidance.');
      expect(result.sessionId, 'session-42');
      expect(requestCount, 1);
    },
  );
}
