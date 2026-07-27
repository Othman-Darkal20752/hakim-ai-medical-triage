import '../../../core/network/api_client.dart';
import 'auth_api.dart';
import 'session_token_manager.dart';

class SessionRefreshCoordinator {
  final SessionTokenManager _tokenManager;
  final AuthApi _authApi;

  Future<String>? _activeRefresh;

  SessionRefreshCoordinator({
    required SessionTokenManager tokenManager,
    required AuthApi authApi,
  }) : this._(tokenManager, authApi);

  SessionRefreshCoordinator._(this._tokenManager, this._authApi);

  Future<String> refreshAccessToken() {
    final activeRefresh = _activeRefresh;

    if (activeRefresh != null) {
      return activeRefresh;
    }

    final refreshFuture = _refreshAccessTokenOnce();
    _activeRefresh = refreshFuture;

    return refreshFuture;
  }

  Future<String> _refreshAccessTokenOnce() async {
    try {
      return await _performRefresh();
    } finally {
      _activeRefresh = null;
    }
  }

  Future<String> _performRefresh() async {
    final refreshToken = await _tokenManager.readRefreshToken();

    if (refreshToken == null) {
      return await _tokenManager.expireSession();
    }

    try {
      final refreshData = await _authApi.refresh(refreshToken: refreshToken);

      final accessToken = refreshData['access']?.toString();

      if (accessToken == null || accessToken.trim().isEmpty) {
        return await _tokenManager.expireSession();
      }

      await _tokenManager.saveAccessToken(accessToken);

      return accessToken;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        return await _tokenManager.expireSession();
      }

      rethrow;
    }
  }
}
