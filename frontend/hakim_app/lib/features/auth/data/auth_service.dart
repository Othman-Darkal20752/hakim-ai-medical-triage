import '../../../core/network/api_client.dart';
import 'auth_api.dart';
import 'token_storage.dart';

class AuthService {
  final AuthApi _authApi;
  final TokenStorage _tokenStorage;

  AuthService({
    AuthApi? authApi,
    TokenStorage? tokenStorage,
  })  : _authApi = authApi ?? AuthApi(ApiClient()),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final loginData = await _authApi.login(
      username: username,
      password: password,
    );

    final accessToken = loginData['access']?.toString();
    final refreshToken = loginData['refresh']?.toString();

    if (accessToken == null || refreshToken == null) {
      throw const ApiException('لم يصل التوكن من الخادم.');
    }

    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    final userData = await _authApi.me(token: accessToken);

    await _tokenStorage.saveUser(
      username: userData['username']?.toString() ?? username,
      role: userData['role']?.toString() ?? 'patient',
    );
  }

  Future<String?> getAccessToken() {
    return _tokenStorage.getAccessToken();
  }

  Future<bool> isLoggedIn() {
    return _tokenStorage.isLoggedIn();
  }

  Future<void> logout() {
    return _tokenStorage.clear();
  }
}