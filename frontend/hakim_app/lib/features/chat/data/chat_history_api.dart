import '../../../core/network/authenticated_api_client.dart';
import 'chat_history_snapshot.dart';
import 'chat_session_detail.dart';
import 'chat_session_summary.dart';

class ChatHistoryApi {
  final AuthenticatedApiClient _apiClient;

  ChatHistoryApi(this._apiClient);

  Future<ChatHistorySnapshot> getHistory() async {
    final response = await _apiClient.get('/chat/history/');

    return ChatHistorySnapshot.fromJson(response);
  }

  Future<List<ChatSessionSummary>> getSessions() async {
    final response = await _apiClient.get('/chat/sessions/');

    final sessionsJson = response['sessions'] as List? ?? const [];

    return sessionsJson
        .whereType<Map>()
        .map(
          (session) =>
              ChatSessionSummary.fromJson(Map<String, dynamic>.from(session)),
        )
        .toList();
  }

  Future<ChatSessionDetail> getSessionDetail({
    required String sessionId,
  }) async {
    final response = await _apiClient.get('/chat/sessions/$sessionId/');

    return ChatSessionDetail.fromJson(response);
  }

  Future<void> deleteSession({required String sessionId}) async {
    await _apiClient.delete('/chat/sessions/$sessionId/');
  }
}
