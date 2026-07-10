import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _accessTokenKey = 'hakim_access_token';
  static const String _refreshTokenKey = 'hakim_refresh_token';
  static const String _usernameKey = 'hakim_username';
  static const String _roleKey = 'hakim_role';

  static const List<String> _allKeys = [
    _accessTokenKey,
    _refreshTokenKey,
    _usernameKey,
    _roleKey,
  ];

  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(
      storageNamespace: 'hakim_auth',
      migrateWithBackup: true,
    ),
  );

  static Future<void>? _migrationFuture;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _ensureLegacyDataMigrated();

    await _secureStorage.write(key: _accessTokenKey, value: accessToken);

    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> saveUser({
    required String username,
    required String role,
  }) async {
    await _ensureLegacyDataMigrated();

    await _secureStorage.write(key: _usernameKey, value: username);

    await _secureStorage.write(key: _roleKey, value: role);
  }

  Future<String?> getAccessToken() async {
    await _ensureLegacyDataMigrated();

    return _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    await _ensureLegacyDataMigrated();

    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<String?> getUsername() async {
    await _ensureLegacyDataMigrated();

    return _secureStorage.read(key: _usernameKey);
  }

  Future<String?> getRole() async {
    await _ensureLegacyDataMigrated();

    return _secureStorage.read(key: _roleKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();

    return token != null && token.isNotEmpty;
  }

  Future<void> clear() async {
    final runningMigration = _migrationFuture;

    if (runningMigration != null) {
      try {
        await runningMigration;
      } catch (_) {
        // Continue clearing both secure and legacy storage.
      }
    }

    Object? firstError;
    StackTrace? firstStackTrace;

    for (final key in _allKeys) {
      try {
        await _secureStorage.delete(key: key);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    try {
      final preferences = await SharedPreferences.getInstance();

      for (final key in _allKeys) {
        try {
          final removed = await preferences.remove(key);

          if (!removed && preferences.containsKey(key)) {
            throw StateError(
              'Failed to remove legacy authentication key: $key',
            );
          }
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }

    _migrationFuture = null;

    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }

  Future<void> _ensureLegacyDataMigrated() async {
    final runningMigration = _migrationFuture;

    if (runningMigration != null) {
      await runningMigration;
      return;
    }

    final migration = _migrateLegacyData();
    _migrationFuture = migration;

    try {
      await migration;
    } catch (_) {
      _migrationFuture = null;
      rethrow;
    }
  }

  Future<void> _migrateLegacyData() async {
    final preferences = await SharedPreferences.getInstance();

    final legacyValues = <String, String?>{
      _accessTokenKey: preferences.getString(_accessTokenKey),
      _refreshTokenKey: preferences.getString(_refreshTokenKey),
      _usernameKey: preferences.getString(_usernameKey),
      _roleKey: preferences.getString(_roleKey),
    };

    for (final entry in legacyValues.entries) {
      final legacyValue = entry.value;

      if (legacyValue == null || legacyValue.isEmpty) {
        continue;
      }

      final secureValue = await _secureStorage.read(key: entry.key);

      if (secureValue == null || secureValue.isEmpty) {
        await _secureStorage.write(key: entry.key, value: legacyValue);

        final verifiedValue = await _secureStorage.read(key: entry.key);

        if (verifiedValue != legacyValue) {
          throw StateError(
            'Failed to verify secure migration for key: ${entry.key}',
          );
        }
      }
    }

    for (final key in _allKeys) {
      final removed = await preferences.remove(key);

      if (!removed && preferences.containsKey(key)) {
        throw StateError('Failed to remove legacy authentication key: $key');
      }
    }
  }
}
