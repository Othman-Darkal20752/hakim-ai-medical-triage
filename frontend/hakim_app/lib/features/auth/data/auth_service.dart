import '../../../core/network/api_client.dart';
import 'auth_api.dart';
import 'google_auth_service.dart';
import 'token_storage.dart';
import '../../chat/data/encrypted_chat_cache.dart';

class AuthService {
  final AuthApi _authApi;
  final TokenStorage _tokenStorage;
  final GoogleAuthService _googleAuthService;
  final EncryptedChatCache _encryptedChatCache;

  AuthService({
    AuthApi? authApi,
    TokenStorage? tokenStorage,
    GoogleAuthService? googleAuthService,
    EncryptedChatCache? encryptedChatCache,
  }) : _authApi = authApi ?? AuthApi(ApiClient()),
       _tokenStorage = tokenStorage ?? TokenStorage(),
       _googleAuthService = googleAuthService ?? GoogleAuthService(),
       _encryptedChatCache = encryptedChatCache ?? EncryptedChatCache();

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
      await _tokenStorage.clear();
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
        await _tokenStorage.clear();
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
        await _tokenStorage.clear();
        return false;
      }

      // Temporary server or network failure must not remove the local session.
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<String?> getAccessToken() {
    return _tokenStorage.getAccessToken();
  }

  Future<int?> getUserId() {
    return _tokenStorage.getUserId();
  }

  Future<bool> isLoggedIn() {
    return _tokenStorage.isLoggedIn();
  }

  Future<void> logout() async {
    final userId = await _tokenStorage.getUserId();

    if (userId != null && userId > 0) {
      await _encryptedChatCache.deleteUserCache(userId: userId);
    }

    await _tokenStorage.clear();

    try {
      await _googleAuthService.signOut();
    } catch (_) {
      // Local Hakim logout must still succeed if Google sign-out fails.
    }
  }
}
