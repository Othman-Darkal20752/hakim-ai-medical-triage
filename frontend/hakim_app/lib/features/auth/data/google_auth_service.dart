import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthConfigurationException implements Exception {
  final String message;

  const GoogleAuthConfigurationException(this.message);

  @override
  String toString() => message;
}

class GoogleAuthService {
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static Future<void>? _initialization;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void> _ensureInitialized() async {
    if (_serverClientId.isEmpty) {
      throw const GoogleAuthConfigurationException(
        'GOOGLE_SERVER_CLIENT_ID غير موجود في إعدادات تشغيل Flutter.',
      );
    }

    final existingInitialization = _initialization;
    if (existingInitialization != null) {
      await existingInitialization;
      return;
    }

    final initialization = _googleSignIn.initialize(
      serverClientId: _serverClientId,
    );

    _initialization = initialization;

    try {
      await initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<String> authenticateAndGetIdToken() async {
    await _ensureInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw const GoogleAuthConfigurationException(
        'تسجيل الدخول التفاعلي عبر Google غير مدعوم على هذه المنصة.',
      );
    }

    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw const GoogleAuthConfigurationException('لم يصل Google ID Token.');
    }

    return idToken;
  }

  Future<void> signOut() async {
    if (_serverClientId.isEmpty) return;

    await _ensureInitialized();
    await _googleSignIn.signOut();
  }
}
