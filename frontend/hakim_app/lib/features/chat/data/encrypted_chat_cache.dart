import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'chat_history_snapshot.dart';

class CachedChatSnapshot {
  final ChatHistorySnapshot history;
  final DateTime cachedAt;

  const CachedChatSnapshot({required this.history, required this.cachedAt});
}

class EncryptedChatCache {
  static const int _schemaVersion = 1;
  static const String _boxName = 'hakim_encrypted_chat_cache_v1';
  static const String _secureKeyPrefix = 'hakim_chat_cache_key_user_';

  static Future<Box<String>>? _boxFuture;

  final AesGcm _cipher;
  final FlutterSecureStorage _secureStorage;

  EncryptedChatCache({FlutterSecureStorage? secureStorage})
    : _cipher = AesGcm.with256bits(),
      _secureStorage =
          secureStorage ??
          FlutterSecureStorage(
            aOptions: const AndroidOptions(
              storageNamespace: 'hakim_chat_cache',
              migrateWithBackup: true,
            ),
          );

  Future<void> saveSnapshot({
    required int userId,
    required ChatHistorySnapshot history,
  }) async {
    _validateUserId(userId);

    final secretKey = await _getOrCreateSecretKey(userId);
    final cachedAt = DateTime.now().toUtc();

    final payload = <String, dynamic>{
      'schema_version': _schemaVersion,
      'user_id': userId,
      'cached_at': cachedAt.toIso8601String(),
      'data': history.toJson(),
    };

    final clearBytes = utf8.encode(jsonEncode(payload));

    final secretBox = await _cipher.encrypt(
      clearBytes,
      secretKey: secretKey,
      nonce: _cipher.newNonce(),
      aad: _buildAdditionalAuthenticatedData(userId),
    );

    final encryptedValue = base64Encode(secretBox.concatenation());

    final box = await _getBox();

    await box.put(_buildCacheEntryKey(userId), encryptedValue);
  }

  Future<CachedChatSnapshot?> readSnapshot({required int userId}) async {
    _validateUserId(userId);

    final box = await _getBox();
    final cacheEntryKey = _buildCacheEntryKey(userId);
    final encryptedValue = box.get(cacheEntryKey);

    if (encryptedValue == null || encryptedValue.isEmpty) {
      return null;
    }

    final secretKey = await _readExistingSecretKey(userId);

    if (secretKey == null) {
      await box.delete(cacheEntryKey);
      return null;
    }

    try {
      final encryptedBytes = base64Decode(encryptedValue);

      final secretBox = SecretBox.fromConcatenation(
        encryptedBytes,
        nonceLength: _cipher.nonceLength,
        macLength: _cipher.macAlgorithm.macLength,
        copy: false,
      );

      final clearBytes = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: _buildAdditionalAuthenticatedData(userId),
      );

      final decodedValue = jsonDecode(utf8.decode(clearBytes));

      if (decodedValue is! Map) {
        throw const FormatException(
          'Encrypted chat cache must contain a JSON object.',
        );
      }

      final payload = Map<String, dynamic>.from(decodedValue);

      final schemaVersion = (payload['schema_version'] as num?)?.toInt();

      final cachedUserId = (payload['user_id'] as num?)?.toInt();

      final cachedAt = DateTime.tryParse(
        payload['cached_at']?.toString() ?? '',
      );

      final rawData = payload['data'];

      if (schemaVersion != _schemaVersion ||
          cachedUserId != userId ||
          cachedAt == null ||
          rawData is! Map) {
        throw const FormatException(
          'Encrypted chat cache metadata is invalid.',
        );
      }

      final history = ChatHistorySnapshot.fromJson(
        Map<String, dynamic>.from(rawData),
      );

      return CachedChatSnapshot(history: history, cachedAt: cachedAt.toUtc());
    } on FormatException {
      await box.delete(cacheEntryKey);
      return null;
    } on SecretBoxAuthenticationError {
      await box.delete(cacheEntryKey);
      return null;
    } on TypeError {
      await box.delete(cacheEntryKey);
      return null;
    }
  }

  Future<void> deleteUserCache({required int userId}) async {
    _validateUserId(userId);

    final box = await _getBox();

    await box.delete(_buildCacheEntryKey(userId));

    await _secureStorage.delete(key: _buildSecureKeyName(userId));
  }

  Future<SecretKey> _getOrCreateSecretKey(int userId) async {
    final existingKey = await _readExistingSecretKey(userId);

    if (existingKey != null) {
      return existingKey;
    }

    final secretKey = await _cipher.newSecretKey();
    final secretKeyBytes = await secretKey.extractBytes();
    final encodedKey = base64Encode(secretKeyBytes);
    final secureKeyName = _buildSecureKeyName(userId);

    await _secureStorage.write(key: secureKeyName, value: encodedKey);

    final verifiedValue = await _secureStorage.read(key: secureKeyName);

    if (verifiedValue != encodedKey) {
      throw StateError('Failed to verify the encrypted chat cache key.');
    }

    return secretKey;
  }

  Future<SecretKey?> _readExistingSecretKey(int userId) async {
    final secureKeyName = _buildSecureKeyName(userId);

    final encodedKey = await _secureStorage.read(key: secureKeyName);

    if (encodedKey == null || encodedKey.isEmpty) {
      return null;
    }

    try {
      final secretKeyBytes = base64Decode(encodedKey);

      if (secretKeyBytes.length != _cipher.secretKeyLength) {
        await _secureStorage.delete(key: secureKeyName);
        return null;
      }

      return _cipher.newSecretKeyFromBytes(secretKeyBytes);
    } on FormatException {
      await _secureStorage.delete(key: secureKeyName);
      return null;
    }
  }

  Future<Box<String>> _getBox() async {
    final runningInitialization = _boxFuture;

    if (runningInitialization != null) {
      return runningInitialization;
    }

    final initialization = _initializeBox();
    _boxFuture = initialization;

    try {
      return await initialization;
    } catch (_) {
      if (identical(_boxFuture, initialization)) {
        _boxFuture = null;
      }

      rethrow;
    }
  }

  static Future<Box<String>> _initializeBox() async {
    await Hive.initFlutter();

    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }

    return Hive.openBox<String>(_boxName);
  }

  List<int> _buildAdditionalAuthenticatedData(int userId) {
    return utf8.encode('hakim-chat-cache:v$_schemaVersion:user:$userId');
  }

  String _buildCacheEntryKey(int userId) {
    return 'snapshot_user_$userId';
  }

  String _buildSecureKeyName(int userId) {
    return '$_secureKeyPrefix$userId';
  }

  void _validateUserId(int userId) {
    if (userId <= 0) {
      throw ArgumentError.value(
        userId,
        'userId',
        'User ID must be greater than zero.',
      );
    }
  }
}
