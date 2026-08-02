import 'api_client.dart';

typedef AccessTokenReader = Future<String?> Function();
typedef AccessTokenRefresher = Future<String> Function();
typedef SessionExpirer = Future<Never> Function();

typedef _AuthenticatedRequest =
    Future<Map<String, dynamic>> Function(String accessToken);

class AuthenticatedApiClient {
  final ApiClient _apiClient;
  final AccessTokenReader _readAccessToken;
  final AccessTokenRefresher _refreshAccessToken;
  final SessionExpirer _expireSession;

  AuthenticatedApiClient({
    required ApiClient apiClient,
    required AccessTokenReader readAccessToken,
    required AccessTokenRefresher refreshAccessToken,
    required SessionExpirer expireSession,
  }) : this._(apiClient, readAccessToken, refreshAccessToken, expireSession);

  AuthenticatedApiClient._(
    this._apiClient,
    this._readAccessToken,
    this._refreshAccessToken,
    this._expireSession,
  );

  Future<Map<String, dynamic>> get(String path) {
    return _sendWithAuthentication(
      (accessToken) => _apiClient.get(path, token: accessToken),
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
  }) {
    return _sendWithAuthentication(
      (accessToken) => _apiClient.post(path, body: body, token: accessToken),
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    required Map<String, dynamic> body,
  }) {
    return _sendWithAuthentication(
      (accessToken) => _apiClient.patch(path, body: body, token: accessToken),
    );
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _sendWithAuthentication(
      (accessToken) => _apiClient.delete(path, token: accessToken),
    );
  }

  Future<Map<String, dynamic>> _sendWithAuthentication(
    _AuthenticatedRequest request,
  ) async {
    final accessToken = _nonEmptyToken(await _readAccessToken());

    if (accessToken == null) {
      return await _expireSession();
    }

    try {
      return await request(accessToken);
    } on ApiException catch (error) {
      if (error.statusCode != 401) {
        rethrow;
      }
    }

    final retryToken = await _resolveRetryToken(failedAccessToken: accessToken);

    try {
      return await request(retryToken);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        return await _expireSession();
      }

      rethrow;
    }
  }

  Future<String> _resolveRetryToken({required String failedAccessToken}) async {
    final currentAccessToken = _nonEmptyToken(await _readAccessToken());

    if (currentAccessToken != null && currentAccessToken != failedAccessToken) {
      return currentAccessToken;
    }

    final refreshedAccessToken = _nonEmptyToken(await _refreshAccessToken());

    if (refreshedAccessToken == null) {
      return await _expireSession();
    }

    return refreshedAccessToken;
  }

  String? _nonEmptyToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      return null;
    }

    return token;
  }
}
