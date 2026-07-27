import 'session_expired_exception.dart';
import 'token_storage.dart';

typedef LocalSessionInvalidator = Future<void> Function();

class SessionTokenManager {
  final TokenStorage _tokenStorage;
  final LocalSessionInvalidator _invalidateLocalSession;

  SessionTokenManager({
    required TokenStorage tokenStorage,
    required LocalSessionInvalidator invalidateLocalSession,
  }) : this._(tokenStorage, invalidateLocalSession);

  SessionTokenManager._(this._tokenStorage, this._invalidateLocalSession);

  Future<String?> readAccessToken() async {
    return _nonEmptyToken(await _tokenStorage.getAccessToken());
  }

  Future<String?> readRefreshToken() async {
    return _nonEmptyToken(await _tokenStorage.getRefreshToken());
  }

  Future<void> saveAccessToken(String accessToken) {
    if (accessToken.trim().isEmpty) {
      throw ArgumentError.value(
        accessToken,
        'accessToken',
        'Access token must not be empty.',
      );
    }

    return _tokenStorage.saveAccessToken(accessToken: accessToken);
  }

  Future<Never> expireSession() async {
    await _invalidateLocalSession();

    throw const SessionExpiredException();
  }

  String? _nonEmptyToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      return null;
    }

    return token;
  }
}
