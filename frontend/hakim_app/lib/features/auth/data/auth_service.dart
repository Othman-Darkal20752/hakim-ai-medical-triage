import '../../../core/network/api_client.dart';
import '../../../core/network/authenticated_api_client.dart';
import 'auth_api.dart';
import 'google_auth_service.dart';
import 'session_refresh_coordinator.dart';
import 'session_token_manager.dart';
import 'token_storage.dart';
import '../../chat/data/encrypted_chat_cache.dart';

class AuthService {
  final AuthApi _authApi;
  final TokenStorage _tokenStorage;
  final GoogleAuthService _googleAuthService;
  final EncryptedChatCache _encryptedChatCache;

  late final SessionTokenManager _sessionTokenManager;
  late final SessionRefreshCoordinator _sessionRefreshCoordinator;
  late final AuthenticatedApiClient _authenticatedApiClient;

  AuthService({
    AuthApi? authApi,
    TokenStorage? tokenStorage,
    GoogleAuthService? googleAuthService,
    EncryptedChatCache? encryptedChatCache,
    ApiClient? protectedApiClient,
  }) : _authApi = authApi ?? AuthApi(ApiClient()),
       _tokenStorage = tokenStorage ?? TokenStorage(),
       _googleAuthService = googleAuthService ?? GoogleAuthService(),
       _encryptedChatCache = encryptedChatCache ?? EncryptedChatCache() {
    _sessionTokenManager = SessionTokenManager(
      tokenStorage: _tokenStorage,
      invalidateLocalSession: invalidateLocalSession,
    );

    _sessionRefreshCoordinator = SessionRefreshCoordinator(
      tokenManager: _sessionTokenManager,
      authApi: _authApi,
    );

    _authenticatedApiClient = AuthenticatedApiClient(
      apiClient: protectedApiClient ?? ApiClient(),
      readAccessToken: _sessionTokenManager.readAccessToken,
      refreshAccessToken: _sessionRefreshCoordinator.refreshAccessToken,
      expireSession: _sessionTokenManager.expireSession,
    );
  }

  Future<void> register({
    required String username,
    String? email,
    required String password,
    required String passwordConfirm,
    required String role,
  }) async {
    final registrationData = await _authApi.register(
      username: username,
      email: email,
      password: password,
      passwordConfirm: passwordConfirm,
      role: role,
    );

    await _saveAuthenticatedSession(
      loginData: registrationData,
      fallbackUsername: username,
    );
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final loginData = await _authApi.login(
      username: username,
      password: password,
    );

    await _saveAuthenticatedSession(
      loginData: loginData,
      fallbackUsername: username,
    );
  }

  Future<void> loginWithGoogle() async {
    final idToken = await _googleAuthService.authenticateAndGetIdToken();

    final loginData = await _authApi.googleLogin(idToken: idToken);

    await _saveAuthenticatedSession(
      loginData: loginData,
      fallbackUsername: 'google-user',
    );
  }

  Future<void> _saveAuthenticatedSession({
    required Map<String, dynamic> loginData,
    required String fallbackUsername,
  }) async {
    final accessToken = loginData['access']?.toString();
    final refreshToken = loginData['refresh']?.toString();

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw const ApiException('لم يصل التوكن من الخادم.');
    }

    final userData = await _authApi.me(token: accessToken);

    await _saveUserData(userData: userData, fallbackUsername: fallbackUsername);

    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<void> _saveUserData({
    required Map<String, dynamic> userData,
    required String fallbackUsername,
  }) async {
    final rawUserId = userData['id'];

    final userId = rawUserId is num
        ? rawUserId.toInt()
        : int.tryParse(rawUserId?.toString() ?? '');

    if (userId == null || userId <= 0) {
      throw const ApiException('لم يصل معرف المستخدم الصحيح من الخادم.');
    }

    await _tokenStorage.saveUser(
      userId: userId,
      username: userData['username']?.toString() ?? fallbackUsername,
      role: userData['role']?.toString() ?? 'patient',
    );
  }

  Future<bool> restoreSession() async {
    final accessToken = await _tokenStorage.getAccessToken();
    final refreshToken = await _tokenStorage.getRefreshToken();

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      await invalidateLocalSession();
      return false;
    }

    try {
      final userData = await _authApi.me(token: accessToken);

      await _saveUserData(
        userData: userData,
        fallbackUsername:
            await _tokenStorage.getUsername() ?? 'authenticated-user',
      );

      return true;
    } on ApiException catch (error) {
      if (error.statusCode != 401) {
        // Temporary server or network failure must not remove the local session.
        return true;
      }
    } catch (_) {
      return true;
    }

    try {
      final refreshData = await _authApi.refresh(refreshToken: refreshToken);

      final newAccessToken = refreshData['access']?.toString();

      if (newAccessToken == null || newAccessToken.isEmpty) {
        await invalidateLocalSession();
        return false;
      }

      final newRefreshToken =
          refreshData['refresh']?.toString() ?? refreshToken;

      final userData = await _authApi.me(token: newAccessToken);

      await _saveUserData(
        userData: userData,
        fallbackUsername:
            await _tokenStorage.getUsername() ?? 'authenticated-user',
      );

      await _tokenStorage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await invalidateLocalSession();
        return false;
      }

      // Temporary server or network failure must not remove the local session.
      return true;
    } catch (_) {
      return true;
    }
  }

  AuthenticatedApiClient get authenticatedApiClient {
    return _authenticatedApiClient;
  }

  Future<String?> getAccessToken() {
    return _tokenStorage.getAccessToken();
  }

  Future<int?> getUserId() {
    return _tokenStorage.getUserId();
  }

  Future<String?> getRole() {
    return _tokenStorage.getRole();
  }

  Future<bool> isLoggedIn() {
    return _tokenStorage.isLoggedIn();
  }

  Future<void> invalidateLocalSession() async {
    final userId = await _tokenStorage.getUserId();

    if (userId != null && userId > 0) {
      try {
        await _encryptedChatCache.deleteUserCache(userId: userId);
      } catch (_) {
        // Authentication data must still be cleared if cache deletion fails.
      }
    }

    await _tokenStorage.clear();
  }

  Future<void> logout() async {
    await invalidateLocalSession();

    try {
      await _googleAuthService.signOut();
    } catch (_) {
      // Local Hakim logout must still succeed if Google sign-out fails.
    }
  }
}
