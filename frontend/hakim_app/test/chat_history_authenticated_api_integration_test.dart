import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/core/network/authenticated_api_client.dart';
import 'package:hakim_app/features/auth/data/session_expired_exception.dart';
import 'package:hakim_app/features/chat/data/chat_history_api.dart';
import 'package:hakim_app/features/chat/data/chat_history_repository.dart';
import 'package:hakim_app/features/chat/data/chat_history_snapshot.dart';
import 'package:hakim_app/features/chat/data/encrypted_chat_cache.dart';

class _FakeEncryptedChatCache extends EncryptedChatCache {
  CachedChatSnapshot? snapshot;

  int readCallCount = 0;
  int saveCallCount = 0;

  @override
  Future<CachedChatSnapshot?> readSnapshot({required int userId}) async {
    readCallCount++;
    return snapshot;
  }

  @override
  Future<void> saveSnapshot({
    required int userId,
    required ChatHistorySnapshot history,
  }) async {
    saveCallCount++;

    snapshot = CachedChatSnapshot(
      history: history,
      cachedAt: DateTime.utc(2026, 7, 28),
    );
  }
}

AuthenticatedApiClient _buildAuthenticatedClient({
  required http.Client client,
  Future<String?> Function()? readAccessToken,
}) {
  return AuthenticatedApiClient(
    apiClient: ApiClient(client: client),
    readAccessToken: readAccessToken ?? () async => 'access-token',
    refreshAccessToken: () async {
      throw StateError('Refresh should not be called.');
    },
    expireSession: () async {
      throw const SessionExpiredException();
    },
  );
}

void main() {
  test(
    'loads history and deletes a session through authenticated client',
    () async {
      var requestCount = 0;

      final client = MockClient((request) async {
        requestCount++;

        expect(request.headers['Authorization'], 'Bearer access-token');

        if (request.method == 'GET') {
          expect(request.url.path.endsWith('/chat/history/'), isTrue);

          return http.Response(
            jsonEncode({'sessions': [], 'session_details': {}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        expect(request.method, 'DELETE');
        expect(request.url.path.endsWith('/chat/sessions/session-42/'), isTrue);

        return http.Response('', 204);
      });

      final api = ChatHistoryApi(_buildAuthenticatedClient(client: client));

      final history = await api.getHistory();

      expect(history.sessions, isEmpty);
      expect(history.sessionDetails, isEmpty);

      await api.deleteSession(sessionId: 'session-42');

      expect(requestCount, 2);
    },
  );

  test('uses encrypted cache after a transport failure', () async {
    final client = MockClient((request) async {
      throw const SocketException('No network connection.');
    });

    final cachedHistory = const ChatHistorySnapshot.empty();

    final cachedAt = DateTime.utc(2026, 7, 28, 10);

    final cache = _FakeEncryptedChatCache()
      ..snapshot = CachedChatSnapshot(
        history: cachedHistory,
        cachedAt: cachedAt,
      );

    final repository = ChatHistoryRepository(
      ChatHistoryApi(_buildAuthenticatedClient(client: client)),
      encryptedCache: cache,
    );

    final result = await repository.loadHistory(userId: 42);

    expect(result.isOffline, isTrue);
    expect(result.history, same(cachedHistory));
    expect(result.cachedAt, cachedAt);

    expect(cache.readCallCount, 1);
    expect(cache.saveCallCount, 0);
  });

  test('propagates session expiration without reading cache', () async {
    var requestCount = 0;

    final client = MockClient((request) async {
      requestCount++;

      return http.Response(
        jsonEncode({'sessions': [], 'session_details': {}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final cache = _FakeEncryptedChatCache()
      ..snapshot = CachedChatSnapshot(
        history: const ChatHistorySnapshot.empty(),
        cachedAt: DateTime.utc(2026, 7, 28),
      );

    final repository = ChatHistoryRepository(
      ChatHistoryApi(
        _buildAuthenticatedClient(
          client: client,
          readAccessToken: () async => null,
        ),
      ),
      encryptedCache: cache,
    );

    await expectLater(
      repository.loadHistory(userId: 42),
      throwsA(isA<SessionExpiredException>()),
    );

    expect(requestCount, 0);
    expect(cache.readCallCount, 0);
    expect(cache.saveCallCount, 0);
  });
}
