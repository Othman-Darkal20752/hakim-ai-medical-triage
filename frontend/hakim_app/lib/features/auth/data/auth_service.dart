import '../../../core/network/api_client.dart';
import 'auth_api.dart';
import 'google_auth_service.dart';
import 'token_storage.dart';

class AuthService {
  final AuthApi _authApi;
  final TokenStorage _tokenStorage;
  final GoogleAuthService _googleAuthService;

  AuthService({
    AuthApi? authApi,
    TokenStorage? tokenStorage,
    GoogleAuthService? googleAuthService,
  }) : _authApi = authApi ?? AuthApi(ApiClient()),
       _tokenStorage = tokenStorage ?? TokenStorage(),
       _googleAuthService = googleAuthService ?? GoogleAuthService();

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

    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    final userData = await _authApi.me(token: accessToken);

    await _tokenStorage.saveUser(
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
      await _authApi.me(token: accessToken);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode != 401) {
        // يوجد توكن محفوظ، لكن الخادم أو الشبكة غير متاحين مؤقتًا.
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

      await _tokenStorage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      await _authApi.me(token: newAccessToken);

      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _tokenStorage.clear();
        return false;
      }

      // لا نحذف تسجيل الدخول بسبب مشكلة شبكة مؤقتة.
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<String?> getAccessToken() {
    return _tokenStorage.getAccessToken();
  }

  Future<bool> isLoggedIn() {
    return _tokenStorage.isLoggedIn();
  }

  Future<void> logout() async {
    await _tokenStorage.clear();

    try {
      await _googleAuthService.signOut();
    } catch (_) {
      // Local Hakim logout must still succeed if Google sign-out fails.
    }
  }
}
