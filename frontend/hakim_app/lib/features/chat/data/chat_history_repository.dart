import '../../../core/network/api_client.dart';
import 'chat_history_api.dart';
import 'chat_history_snapshot.dart';
import 'encrypted_chat_cache.dart';
import 'chat_session_detail.dart';

class ChatHistoryLoadResult {
  final ChatHistorySnapshot history;
  final bool isOffline;
  final DateTime? cachedAt;

  const ChatHistoryLoadResult({
    required this.history,
    required this.isOffline,
    required this.cachedAt,
  });

  const ChatHistoryLoadResult.online({required this.history})
    : isOffline = false,
      cachedAt = null;

  const ChatHistoryLoadResult.offline({
    required this.history,
    required DateTime this.cachedAt,
  }) : isOffline = true;
}

class ChatHistoryRepository {
  final ChatHistoryApi _historyApi;
  final EncryptedChatCache _encryptedCache;

  ChatHistoryRepository(this._historyApi, {EncryptedChatCache? encryptedCache})
    : _encryptedCache = encryptedCache ?? EncryptedChatCache();

  Future<ChatHistoryLoadResult> loadHistory({
    required String token,
    required int userId,
  }) async {
    ChatHistorySnapshot onlineHistory;

    try {
      onlineHistory = await _historyApi.getHistory(token: token);
    } catch (error, stackTrace) {
      if (!_canUseOfflineCache(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      final cachedSnapshot = await _readCacheSafely(userId: userId);

      if (cachedSnapshot == null) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      return ChatHistoryLoadResult.offline(
        history: cachedSnapshot.history,
        cachedAt: cachedSnapshot.cachedAt,
      );
    }

    await _saveCacheSafely(userId: userId, history: onlineHistory);

    return ChatHistoryLoadResult.online(history: onlineHistory);
  }

  Future<void> deleteUserCache({required int userId}) {
    return _encryptedCache.deleteUserCache(userId: userId);
  }

  Future<void> removeSessionFromCache({
    required int userId,
    required String sessionId,
  }) async {
    try {
      final cachedSnapshot = await _encryptedCache.readSnapshot(userId: userId);

      if (cachedSnapshot == null) {
        return;
      }

      final updatedSessions = cachedSnapshot.history.sessions
          .where((session) => session.id != sessionId)
          .toList();

      final updatedDetails = Map<String, ChatSessionDetail>.from(
        cachedSnapshot.history.sessionDetails,
      )..remove(sessionId);

      await _encryptedCache.saveSnapshot(
        userId: userId,
        history: ChatHistorySnapshot(
          sessions: updatedSessions,
          sessionDetails: updatedDetails,
        ),
      );
    } catch (_) {
      // Never retain a possibly stale deleted medical conversation.
      try {
        await _encryptedCache.deleteUserCache(userId: userId);
      } catch (_) {
        // The server deletion has already succeeded.
      }
    }
  }

  Future<CachedChatSnapshot?> _readCacheSafely({required int userId}) async {
    try {
      return await _encryptedCache.readSnapshot(userId: userId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCacheSafely({
    required int userId,
    required ChatHistorySnapshot history,
  }) async {
    try {
      await _encryptedCache.saveSnapshot(userId: userId, history: history);
    } catch (_) {
      // Online history remains usable even if local cache writing fails.
    }
  }

  bool _canUseOfflineCache(Object error) {
    if (error is ApiException) {
      final statusCode = error.statusCode;

      if (statusCode == null) {
        return true;
      }

      return statusCode >= 500;
    }

    if (error is FormatException ||
        error is TypeError ||
        error is ArgumentError ||
        error is StateError) {
      return false;
    }

    // Timeouts and transport/network exceptions reach this branch.
    return true;
  }
}
