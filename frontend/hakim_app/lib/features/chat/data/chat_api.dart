import '../../../core/network/api_client.dart';
import 'chat_reply_result.dart';

class ChatApi {
  final ApiClient _apiClient;

  ChatApi(this._apiClient);

  Future<ChatReplyResult> sendMessage({
    required String message,
    String? sessionId,
    String? token,
  }) async {
    final data = await _apiClient.post(
      '/chat/messages/',
      token: token,
      body: {
        'message': message,
        if (sessionId != null) 'session_id': sessionId,
      },
    );

    return ChatReplyResult(
      reply: data['reply']?.toString() ?? 'لم يصل رد من الخادم.',
      sessionId: data['session_id']?.toString() ?? sessionId,
    );
  }
}