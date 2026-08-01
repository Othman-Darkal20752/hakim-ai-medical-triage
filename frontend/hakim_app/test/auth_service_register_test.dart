import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/features/auth/data/auth_api.dart';
import 'package:hakim_app/features/auth/data/auth_service.dart';
import 'package:hakim_app/features/auth/data/google_auth_service.dart';
import 'package:hakim_app/features/auth/data/token_storage.dart';
import 'package:hakim_app/features/chat/data/encrypted_chat_cache.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({
    required this.registrationResponse,
    required this.meResponse,
    required this.operations,
  }) : super(ApiClient());

  final Map<String, dynamic> registrationResponse;
  final Map<String, dynamic> meResponse;
  final List<String> operations;

  String? receivedUsername;
  String? receivedEmail;
  String? receivedPassword;
  String? receivedPasswordConfirm;
  String? receivedRole;
  String? receivedMeToken;

  int registerCallCount = 0;
  int meCallCount = 0;

  @override
  Future<Map<String, dynamic>> register({
    required String username,
    String? email,
    required String password,
    required String passwordConfirm,
    required String role,
  }) async {
    operations.add('register-api');
    registerCallCount++;

    receivedUsername = username;
    receivedEmail = email;
    receivedPassword = password;
    receivedPasswordConfirm = passwordConfirm;
    receivedRole = role;

    return registrationResponse;
  }

  @override
  Future<Map<String, dynamic>> me({required String token}) async {
    operations.add('me-api');
    meCallCount++;
    receivedMeToken = token;

    return meResponse;
  }
}

class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage({required this.operations});

  final List<String> operations;

  int? savedUserId;
  String? savedUsername;
  String? savedRole;
  String? savedAccessToken;
  String? savedRefreshToken;

  int saveUserCallCount = 0;
  int saveTokensCallCount = 0;

  @override
  Future<void> saveUser({
    required int userId,
    required String username,
    required String role,
  }) async {
    operations.add('save-user');
    saveUserCallCount++;

    savedUserId = userId;
    savedUsername = username;
    savedRole = role;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    operations.add('save-tokens');
    saveTokensCallCount++;

    savedAccessToken = accessToken;
    savedRefreshToken = refreshToken;
  }
}

class _UnusedGoogleAuthService extends GoogleAuthService {}

class _UnusedEncryptedChatCache extends EncryptedChatCache {}

void main() {
  group('AuthService.register', () {
    test(
      'registers, loads the authenticated user, and saves the session',
      () async {
        final operations = <String>[];

        final authApi = _FakeAuthApi(
          operations: operations,
          registrationResponse: {
            'user': {
              'id': 999,
              'username': 'untrusted-response-user',
              'role': 'patient',
            },
            'access': 'access-token',
            'refresh': 'refresh-token',
          },
          meResponse: {
            'id': 42,
            'username': 'doctor-user',
            'email': 'doctor@example.com',
            'role': 'doctor',
          },
        );

        final tokenStorage = _FakeTokenStorage(operations: operations);

        final service = AuthService(
          authApi: authApi,
          tokenStorage: tokenStorage,
          googleAuthService: _UnusedGoogleAuthService(),
          encryptedChatCache: _UnusedEncryptedChatCache(),
        );

        await service.register(
          username: 'doctor-user',
          email: 'doctor@example.com',
          password: 'Test12345!',
          passwordConfirm: 'Test12345!',
          role: 'doctor',
        );

        expect(authApi.registerCallCount, 1);
        expect(authApi.receivedUsername, 'doctor-user');
        expect(authApi.receivedEmail, 'doctor@example.com');
        expect(authApi.receivedPassword, 'Test12345!');
        expect(authApi.receivedPasswordConfirm, 'Test12345!');
        expect(authApi.receivedRole, 'doctor');

        expect(authApi.meCallCount, 1);
        expect(authApi.receivedMeToken, 'access-token');

        expect(tokenStorage.saveUserCallCount, 1);
        expect(tokenStorage.savedUserId, 42);
        expect(tokenStorage.savedUsername, 'doctor-user');
        expect(tokenStorage.savedRole, 'doctor');

        expect(tokenStorage.saveTokensCallCount, 1);
        expect(tokenStorage.savedAccessToken, 'access-token');
        expect(tokenStorage.savedRefreshToken, 'refresh-token');

        expect(operations, [
          'register-api',
          'me-api',
          'save-user',
          'save-tokens',
        ]);
      },
    );

    test('does not load or save a session when tokens are missing', () async {
      final operations = <String>[];

      final authApi = _FakeAuthApi(
        operations: operations,
        registrationResponse: {
          'user': {'id': 42, 'username': 'doctor-user', 'role': 'doctor'},
        },
        meResponse: {'id': 42, 'username': 'doctor-user', 'role': 'doctor'},
      );

      final tokenStorage = _FakeTokenStorage(operations: operations);

      final service = AuthService(
        authApi: authApi,
        tokenStorage: tokenStorage,
        googleAuthService: _UnusedGoogleAuthService(),
        encryptedChatCache: _UnusedEncryptedChatCache(),
      );

      await expectLater(
        service.register(
          username: 'doctor-user',
          password: 'Test12345!',
          passwordConfirm: 'Test12345!',
          role: 'doctor',
        ),
        throwsA(isA<ApiException>()),
      );

      expect(authApi.registerCallCount, 1);
      expect(authApi.meCallCount, 0);
      expect(tokenStorage.saveUserCallCount, 0);
      expect(tokenStorage.saveTokensCallCount, 0);
      expect(operations, ['register-api']);
    });
  });
}
