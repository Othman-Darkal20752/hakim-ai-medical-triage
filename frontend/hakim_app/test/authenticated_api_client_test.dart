import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hakim_app/core/network/authenticated_api_client.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/features/auth/data/auth_api.dart';
import 'package:hakim_app/features/auth/data/session_refresh_coordinator.dart';
import 'package:hakim_app/features/auth/data/session_expired_exception.dart';
import 'package:hakim_app/features/auth/data/session_token_manager.dart';
import 'package:hakim_app/features/auth/data/token_storage.dart';

class _FakeTokenStorage extends TokenStorage {
  String? accessToken;
  String? refreshToken;
  String? savedAccessToken;
  int saveAccessTokenCallCount = 0;

  @override
  Future<String?> getAccessToken() async {
    return accessToken;
  }

  @override
  Future<String?> getRefreshToken() async {
    return refreshToken;
  }

  @override
  Future<void> saveAccessToken({required String accessToken}) async {
    saveAccessTokenCallCount++;
    savedAccessToken = accessToken;
    this.accessToken = accessToken;
  }
}

SessionRefreshCoordinator _buildRefreshCoordinator({
  required _FakeTokenStorage tokenStorage,
  required http.Client client,
  required Future<void> Function() invalidateLocalSession,
}) {
  return SessionRefreshCoordinator(
    tokenManager: SessionTokenManager(
      tokenStorage: tokenStorage,
      invalidateLocalSession: invalidateLocalSession,
    ),
    authApi: AuthApi(ApiClient(client: client)),
  );
}

AuthenticatedApiClient _buildAuthenticatedApiClient({
  required _FakeTokenStorage tokenStorage,
  required http.Client client,
  required Future<void> Function() invalidateLocalSession,
}) {
  final tokenManager = SessionTokenManager(
    tokenStorage: tokenStorage,
    invalidateLocalSession: invalidateLocalSession,
  );

  final refreshCoordinator = SessionRefreshCoordinator(
    tokenManager: tokenManager,
    authApi: AuthApi(ApiClient(client: client)),
  );

  return AuthenticatedApiClient(
    apiClient: ApiClient(client: client),
    readAccessToken: tokenManager.readAccessToken,
    refreshAccessToken: refreshCoordinator.refreshAccessToken,
    expireSession: tokenManager.expireSession,
  );
}

void main() {
  group('SessionTokenManager', () {
    test('reads non-empty access and refresh tokens', () async {
      final storage = _FakeTokenStorage()
        ..accessToken = 'access-token'
        ..refreshToken = 'refresh-token';

      final manager = SessionTokenManager(
        tokenStorage: storage,
        invalidateLocalSession: () async {},
      );

      expect(await manager.readAccessToken(), 'access-token');
      expect(await manager.readRefreshToken(), 'refresh-token');
    });

    test('normalizes missing and whitespace-only tokens to null', () async {
      final storage = _FakeTokenStorage()
        ..accessToken = '   '
        ..refreshToken = null;

      final manager = SessionTokenManager(
        tokenStorage: storage,
        invalidateLocalSession: () async {},
      );

      expect(await manager.readAccessToken(), isNull);
      expect(await manager.readRefreshToken(), isNull);
    });

    test('saves a refreshed access token through TokenStorage', () async {
      final storage = _FakeTokenStorage();

      final manager = SessionTokenManager(
        tokenStorage: storage,
        invalidateLocalSession: () async {},
      );

      await manager.saveAccessToken('new-access-token');

      expect(storage.saveAccessTokenCallCount, 1);
      expect(storage.savedAccessToken, 'new-access-token');
    });

    test('rejects an empty refreshed access token', () {
      final manager = SessionTokenManager(
        tokenStorage: _FakeTokenStorage(),
        invalidateLocalSession: () async {},
      );

      expect(() => manager.saveAccessToken('   '), throwsArgumentError);
    });

    test('expires the session after invoking local invalidation', () async {
      var invalidationCallCount = 0;

      final manager = SessionTokenManager(
        tokenStorage: _FakeTokenStorage(),
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      await expectLater(
        manager.expireSession(),
        throwsA(isA<SessionExpiredException>()),
      );

      expect(invalidationCallCount, 1);
    });
  });

  group('SessionRefreshCoordinator', () {
    test('refreshes, saves, and returns a new access token', () async {
      final tokenStorage = _FakeTokenStorage()..refreshToken = 'refresh-token';

      var requestCount = 0;
      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        requestCount++;

        expect(request.method, 'POST');
        expect(request.url.path.endsWith('/auth/refresh/'), isTrue);
        expect(jsonDecode(request.body), {'refresh': 'refresh-token'});

        return http.Response(
          jsonEncode({'access': 'new-access-token'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final coordinator = _buildRefreshCoordinator(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      final accessToken = await coordinator.refreshAccessToken();

      expect(accessToken, 'new-access-token');
      expect(tokenStorage.savedAccessToken, 'new-access-token');
      expect(tokenStorage.saveAccessTokenCallCount, 1);
      expect(requestCount, 1);
      expect(invalidationCallCount, 0);
    });

    test('shares one refresh request between concurrent callers', () async {
      final tokenStorage = _FakeTokenStorage()..refreshToken = 'refresh-token';

      final responseCompleter = Completer<http.Response>();

      var requestCount = 0;
      var invalidationCallCount = 0;

      final client = MockClient((request) {
        requestCount++;
        return responseCompleter.future;
      });

      final coordinator = _buildRefreshCoordinator(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      final first = coordinator.refreshAccessToken();
      final second = coordinator.refreshAccessToken();
      final third = coordinator.refreshAccessToken();

      await Future<void>.delayed(Duration.zero);

      expect(requestCount, 1);

      responseCompleter.complete(
        http.Response(
          jsonEncode({'access': 'shared-access-token'}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final results = await Future.wait([first, second, third]);

      expect(results, everyElement('shared-access-token'));
      expect(tokenStorage.saveAccessTokenCallCount, 1);
      expect(invalidationCallCount, 0);
    });

    test('expires the session when refresh token is missing', () async {
      final tokenStorage = _FakeTokenStorage()..refreshToken = null;

      var requestCount = 0;
      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        requestCount++;

        return http.Response(jsonEncode({'access': 'unexpected-token'}), 200);
      });

      final coordinator = _buildRefreshCoordinator(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      await expectLater(
        coordinator.refreshAccessToken(),
        throwsA(isA<SessionExpiredException>()),
      );

      expect(requestCount, 0);
      expect(invalidationCallCount, 1);
      expect(tokenStorage.saveAccessTokenCallCount, 0);
    });

    test('expires the session when refresh is rejected with 401', () async {
      final tokenStorage = _FakeTokenStorage()
        ..refreshToken = 'rejected-refresh-token';

      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Token is invalid or expired.'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final coordinator = _buildRefreshCoordinator(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      await expectLater(
        coordinator.refreshAccessToken(),
        throwsA(isA<SessionExpiredException>()),
      );

      expect(invalidationCallCount, 1);
      expect(tokenStorage.saveAccessTokenCallCount, 0);
    });

    test(
      'expires the session when refresh response has no access token',
      () async {
        final tokenStorage = _FakeTokenStorage()
          ..refreshToken = 'refresh-token';

        var invalidationCallCount = 0;

        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({'access': '   '}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final coordinator = _buildRefreshCoordinator(
          tokenStorage: tokenStorage,
          client: client,
          invalidateLocalSession: () async {
            invalidationCallCount++;
          },
        );

        await expectLater(
          coordinator.refreshAccessToken(),
          throwsA(isA<SessionExpiredException>()),
        );

        expect(invalidationCallCount, 1);
        expect(tokenStorage.saveAccessTokenCallCount, 0);
      },
    );

    test('network failure does not invalidate the local session', () async {
      final tokenStorage = _FakeTokenStorage()..refreshToken = 'refresh-token';

      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        throw const SocketException('No network connection.');
      });

      final coordinator = _buildRefreshCoordinator(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      await expectLater(
        coordinator.refreshAccessToken(),
        throwsA(isA<SocketException>()),
      );

      expect(invalidationCallCount, 0);
      expect(tokenStorage.saveAccessTokenCallCount, 0);
    });

    test('server failure does not invalidate the local session', () async {
      final tokenStorage = _FakeTokenStorage()..refreshToken = 'refresh-token';

      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Temporary server failure.'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final coordinator = _buildRefreshCoordinator(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      await expectLater(
        coordinator.refreshAccessToken(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            500,
          ),
        ),
      );

      expect(invalidationCallCount, 0);
      expect(tokenStorage.saveAccessTokenCallCount, 0);
    });

    test('allows a new refresh attempt after a transient failure', () async {
      final tokenStorage = _FakeTokenStorage()..refreshToken = 'refresh-token';

      var requestCount = 0;
      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        requestCount++;

        if (requestCount == 1) {
          throw const SocketException('Temporary network failure.');
        }

        return http.Response(
          jsonEncode({'access': 'recovered-access-token'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final coordinator = _buildRefreshCoordinator(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      await expectLater(
        coordinator.refreshAccessToken(),
        throwsA(isA<SocketException>()),
      );

      final accessToken = await coordinator.refreshAccessToken();

      expect(accessToken, 'recovered-access-token');
      expect(requestCount, 2);
      expect(tokenStorage.saveAccessTokenCallCount, 1);
      expect(invalidationCallCount, 0);
    });
  });

  group('AuthenticatedApiClient', () {
    test('sends a protected request with the stored access token', () async {
      final tokenStorage = _FakeTokenStorage()
        ..accessToken = 'access-token'
        ..refreshToken = 'refresh-token';

      var requestCount = 0;
      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        requestCount++;

        expect(request.method, 'GET');
        expect(request.url.path.endsWith('/protected/'), isTrue);
        expect(request.headers['Authorization'], 'Bearer access-token');

        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authenticatedClient = _buildAuthenticatedApiClient(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      final result = await authenticatedClient.get('/protected/');

      expect(result, {'ok': true});
      expect(requestCount, 1);
      expect(tokenStorage.saveAccessTokenCallCount, 0);
      expect(invalidationCallCount, 0);
    });

    test('refreshes after 401 and retries once with the new token', () async {
      final tokenStorage = _FakeTokenStorage()
        ..accessToken = 'old-access-token'
        ..refreshToken = 'refresh-token';

      var protectedRequestCount = 0;
      var refreshRequestCount = 0;
      var invalidationCallCount = 0;

      final authorizationHeaders = <String?>[];

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh/')) {
          refreshRequestCount++;

          expect(jsonDecode(request.body), {'refresh': 'refresh-token'});

          return http.Response(
            jsonEncode({'access': 'new-access-token'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        protectedRequestCount++;
        authorizationHeaders.add(request.headers['Authorization']);

        if (protectedRequestCount == 1) {
          return http.Response(
            jsonEncode({'detail': 'Access token expired.'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authenticatedClient = _buildAuthenticatedApiClient(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      final result = await authenticatedClient.get('/protected/');

      expect(result, {'ok': true});
      expect(protectedRequestCount, 2);
      expect(refreshRequestCount, 1);
      expect(authorizationHeaders, [
        'Bearer old-access-token',
        'Bearer new-access-token',
      ]);
      expect(tokenStorage.savedAccessToken, 'new-access-token');
      expect(tokenStorage.saveAccessTokenCallCount, 1);
      expect(invalidationCallCount, 0);
    });

    test('concurrent 401 responses share one refresh request', () async {
      final tokenStorage = _FakeTokenStorage()
        ..accessToken = 'old-access-token'
        ..refreshToken = 'refresh-token';

      final oldRequestsReady = Completer<void>();
      final refreshStarted = Completer<void>();
      final refreshResponse = Completer<http.Response>();

      var oldTokenRequestCount = 0;
      var newTokenRequestCount = 0;
      var refreshRequestCount = 0;
      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh/')) {
          refreshRequestCount++;

          if (!refreshStarted.isCompleted) {
            refreshStarted.complete();
          }

          return refreshResponse.future;
        }

        final authorization = request.headers['Authorization'];

        if (authorization == 'Bearer old-access-token') {
          oldTokenRequestCount++;

          if (oldTokenRequestCount == 3 && !oldRequestsReady.isCompleted) {
            oldRequestsReady.complete();
          }

          return http.Response(
            jsonEncode({'detail': 'Access token expired.'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }

        expect(authorization, 'Bearer shared-access-token');

        newTokenRequestCount++;

        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authenticatedClient = _buildAuthenticatedApiClient(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      final first = authenticatedClient.get('/protected/1/');
      final second = authenticatedClient.get('/protected/2/');
      final third = authenticatedClient.get('/protected/3/');

      await oldRequestsReady.future;
      await refreshStarted.future;

      expect(refreshRequestCount, 1);

      refreshResponse.complete(
        http.Response(
          jsonEncode({'access': 'shared-access-token'}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final results = await Future.wait([first, second, third]);

      expect(results, everyElement({'ok': true}));
      expect(oldTokenRequestCount, 3);
      expect(newTokenRequestCount, 3);
      expect(refreshRequestCount, 1);
      expect(tokenStorage.saveAccessTokenCallCount, 1);
      expect(invalidationCallCount, 0);
    });

    test(
      'a late 401 for an old token uses the already refreshed token',
      () async {
        final tokenStorage = _FakeTokenStorage()
          ..accessToken = 'old-access-token'
          ..refreshToken = 'refresh-token';

        final refreshStarted = Completer<void>();
        final allowRefreshResponse = Completer<void>();
        final secondOldRequestStarted = Completer<void>();
        final releaseSecondUnauthorized = Completer<void>();

        var oldTokenRequestCount = 0;
        var newTokenRequestCount = 0;
        var refreshRequestCount = 0;
        var invalidationCallCount = 0;

        final client = MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh/')) {
            refreshRequestCount++;

            if (!refreshStarted.isCompleted) {
              refreshStarted.complete();
            }

            await allowRefreshResponse.future;

            return http.Response(
              jsonEncode({'access': 'new-access-token'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          final authorization = request.headers['Authorization'];

          if (authorization == 'Bearer old-access-token') {
            oldTokenRequestCount++;

            if (oldTokenRequestCount == 1) {
              return http.Response(
                jsonEncode({'detail': 'Access token expired.'}),
                401,
                headers: {'content-type': 'application/json'},
              );
            }

            if (!secondOldRequestStarted.isCompleted) {
              secondOldRequestStarted.complete();
            }

            await releaseSecondUnauthorized.future;

            return http.Response(
              jsonEncode({'detail': 'Late expired-token response.'}),
              401,
              headers: {'content-type': 'application/json'},
            );
          }

          expect(authorization, 'Bearer new-access-token');

          newTokenRequestCount++;

          return http.Response(
            jsonEncode({'ok': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final authenticatedClient = _buildAuthenticatedApiClient(
          tokenStorage: tokenStorage,
          client: client,
          invalidateLocalSession: () async {
            invalidationCallCount++;
          },
        );

        final first = authenticatedClient.get('/protected/first/');

        await refreshStarted.future;

        final second = authenticatedClient.get('/protected/second/');

        await secondOldRequestStarted.future;

        allowRefreshResponse.complete();

        expect(await first, {'ok': true});

        releaseSecondUnauthorized.complete();

        expect(await second, {'ok': true});

        expect(oldTokenRequestCount, 2);
        expect(newTokenRequestCount, 2);
        expect(refreshRequestCount, 1);
        expect(tokenStorage.saveAccessTokenCallCount, 1);
        expect(invalidationCallCount, 0);
      },
    );

    test('403 does not trigger token refresh', () async {
      final tokenStorage = _FakeTokenStorage()
        ..accessToken = 'access-token'
        ..refreshToken = 'refresh-token';

      var protectedRequestCount = 0;
      var refreshRequestCount = 0;
      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh/')) {
          refreshRequestCount++;

          return http.Response(jsonEncode({'access': 'unexpected-token'}), 200);
        }

        protectedRequestCount++;

        return http.Response(
          jsonEncode({'detail': 'Forbidden.'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final authenticatedClient = _buildAuthenticatedApiClient(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      await expectLater(
        authenticatedClient.get('/protected/'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            403,
          ),
        ),
      );

      expect(protectedRequestCount, 1);
      expect(refreshRequestCount, 0);
      expect(invalidationCallCount, 0);
    });

    test('server failure does not trigger token refresh', () async {
      final tokenStorage = _FakeTokenStorage()
        ..accessToken = 'access-token'
        ..refreshToken = 'refresh-token';

      var protectedRequestCount = 0;
      var refreshRequestCount = 0;
      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh/')) {
          refreshRequestCount++;

          return http.Response(jsonEncode({'access': 'unexpected-token'}), 200);
        }

        protectedRequestCount++;

        return http.Response(
          jsonEncode({'detail': 'Temporary server failure.'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final authenticatedClient = _buildAuthenticatedApiClient(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      await expectLater(
        authenticatedClient.get('/protected/'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            500,
          ),
        ),
      );

      expect(protectedRequestCount, 1);
      expect(refreshRequestCount, 0);
      expect(invalidationCallCount, 0);
    });

    test('missing access token expires without sending a request', () async {
      final tokenStorage = _FakeTokenStorage()
        ..accessToken = null
        ..refreshToken = 'refresh-token';

      var requestCount = 0;
      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        requestCount++;

        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final authenticatedClient = _buildAuthenticatedApiClient(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      await expectLater(
        authenticatedClient.get('/protected/'),
        throwsA(isA<SessionExpiredException>()),
      );

      expect(requestCount, 0);
      expect(invalidationCallCount, 1);
    });

    test('a retry 401 expires the session without another refresh', () async {
      final tokenStorage = _FakeTokenStorage()
        ..accessToken = 'old-access-token'
        ..refreshToken = 'refresh-token';

      var protectedRequestCount = 0;
      var refreshRequestCount = 0;
      var invalidationCallCount = 0;

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh/')) {
          refreshRequestCount++;

          return http.Response(
            jsonEncode({'access': 'new-access-token'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        protectedRequestCount++;

        return http.Response(
          jsonEncode({'detail': 'Unauthorized.'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final authenticatedClient = _buildAuthenticatedApiClient(
        tokenStorage: tokenStorage,
        client: client,
        invalidateLocalSession: () async {
          invalidationCallCount++;
        },
      );

      await expectLater(
        authenticatedClient.get('/protected/'),
        throwsA(isA<SessionExpiredException>()),
      );

      expect(protectedRequestCount, 2);
      expect(refreshRequestCount, 1);
      expect(tokenStorage.saveAccessTokenCallCount, 1);
      expect(invalidationCallCount, 1);
    });
  });
}
