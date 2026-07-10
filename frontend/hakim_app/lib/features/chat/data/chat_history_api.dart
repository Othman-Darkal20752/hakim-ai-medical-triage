import '../../../core/network/api_client.dart';
import 'chat_session_detail.dart';
import 'chat_session_summary.dart';

class ChatHistoryApi {
  final ApiClient _apiClient;

  ChatHistoryApi(this._apiClient);

  Future<List<ChatSessionSummary>> getSessions({required String token}) async {
    final response = await _apiClient.get('/chat/sessions/', token: token);

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
    required String token,
  }) async {
    final response = await _apiClient.get(
      '/chat/sessions/$sessionId/',
      token: token,
    );

    return ChatSessionDetail.fromJson(response);
  }

  Future<void> deleteSession({
    required String sessionId,
    required String token,
  }) async {
    await _apiClient.delete('/chat/sessions/$sessionId/', token: token);
  }
}
