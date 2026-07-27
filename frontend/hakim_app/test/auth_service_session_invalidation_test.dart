import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/features/auth/data/auth_api.dart';
import 'package:hakim_app/features/auth/data/auth_service.dart';
import 'package:hakim_app/features/auth/data/google_auth_service.dart';
import 'package:hakim_app/features/auth/data/token_storage.dart';
import 'package:hakim_app/features/chat/data/encrypted_chat_cache.dart';

class _UnusedAuthApi extends AuthApi {
  _UnusedAuthApi() : super(ApiClient());
}

class _FakeTokenStorage extends TokenStorage {
  final List<String> operations;
  int? userId;
  bool cleared = false;
  bool throwOnClear = false;

  _FakeTokenStorage({
    required this.operations,
    this.userId,
  });

  @override
  Future<int?> getUserId() async {
    operations.add('read-user-id');
    return userId;
  }

  @override
  Future<void> clear() async {
    operations.add('clear-auth');
    cleared = true;

    if (throwOnClear) {
      throw StateError('Token clear failed.');
    }
  }
}

class _FakeEncryptedChatCache extends EncryptedChatCache {
  final List<String> operations;
  bool deleted = false;
  bool throwOnDelete = false;
  int? deletedUserId;

  _FakeEncryptedChatCache({required this.operations});

  @override
  Future<void> deleteUserCache({required int userId}) async {
    operations.add('delete-cache');
    deleted = true;
    deletedUserId = userId;

    if (throwOnDelete) {
      throw StateError('Cache deletion failed.');
    }
  }
}

class _FakeGoogleAuthService extends GoogleAuthService {
  final List<String> operations;
  bool signedOut = false;
  bool throwOnSignOut = false;

  _FakeGoogleAuthService({required this.operations});

  @override
  Future<void> signOut() async {
    operations.add('google-sign-out');
    signedOut = true;

    if (throwOnSignOut) {
      throw StateError('Google sign-out failed.');
    }
  }
}

void main() {
  AuthService buildService({
    required _FakeTokenStorage tokenStorage,
    required _FakeEncryptedChatCache cache,
    required _FakeGoogleAuthService googleAuthService,
  }) {
    return AuthService(
      authApi: _UnusedAuthApi(),
      tokenStorage: tokenStorage,
      encryptedChatCache: cache,
      googleAuthService: googleAuthService,
    );
  }

  test('invalidating session deletes cache before clearing auth data', () async {
    final operations = <String>[];
    final tokenStorage = _FakeTokenStorage(
      operations: operations,
      userId: 42,
    );
    final cache = _FakeEncryptedChatCache(operations: operations);
    final googleAuthService = _FakeGoogleAuthService(
      operations: operations,
    );

    final service = buildService(
      tokenStorage: tokenStorage,
      cache: cache,
      googleAuthService: googleAuthService,
    );

    await service.invalidateLocalSession();

    expect(cache.deleted, isTrue);
    expect(cache.deletedUserId, 42);
    expect(tokenStorage.cleared, isTrue);
    expect(
      operations,
      ['read-user-id', 'delete-cache', 'clear-auth'],
    );
  });

  test('cache deletion failure does not prevent auth clearing', () async {
    final operations = <String>[];
    final tokenStorage = _FakeTokenStorage(
      operations: operations,
      userId: 42,
    );
    final cache = _FakeEncryptedChatCache(operations: operations)
      ..throwOnDelete = true;
    final googleAuthService = _FakeGoogleAuthService(
      operations: operations,
    );

    final service = buildService(
      tokenStorage: tokenStorage,
      cache: cache,
      googleAuthService: googleAuthService,
    );

    await service.invalidateLocalSession();

    expect(cache.deleted, isTrue);
    expect(tokenStorage.cleared, isTrue);
    expect(
      operations,
      ['read-user-id', 'delete-cache', 'clear-auth'],
    );
  });

  test('session without user id still clears authentication data', () async {
    final operations = <String>[];
    final tokenStorage = _FakeTokenStorage(
      operations: operations,
      userId: null,
    );
    final cache = _FakeEncryptedChatCache(operations: operations);
    final googleAuthService = _FakeGoogleAuthService(
      operations: operations,
    );

    final service = buildService(
      tokenStorage: tokenStorage,
      cache: cache,
      googleAuthService: googleAuthService,
    );

    await service.invalidateLocalSession();

    expect(cache.deleted, isFalse);
    expect(tokenStorage.cleared, isTrue);
    expect(operations, ['read-user-id', 'clear-auth']);
  });

  test('Google sign-out failure does not block local logout', () async {
    final operations = <String>[];
    final tokenStorage = _FakeTokenStorage(
      operations: operations,
      userId: 42,
    );
    final cache = _FakeEncryptedChatCache(operations: operations);
    final googleAuthService = _FakeGoogleAuthService(
      operations: operations,
    )..throwOnSignOut = true;

    final service = buildService(
      tokenStorage: tokenStorage,
      cache: cache,
      googleAuthService: googleAuthService,
    );

    await service.logout();

    expect(tokenStorage.cleared, isTrue);
    expect(cache.deleted, isTrue);
    expect(googleAuthService.signedOut, isTrue);
    expect(
      operations,
      [
        'read-user-id',
        'delete-cache',
        'clear-auth',
        'google-sign-out',
      ],
    );
  });
}
