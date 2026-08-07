import '../../../core/network/authenticated_api_client.dart';
import 'chat_reply_result.dart';

class ChatApi {
  final AuthenticatedApiClient _apiClient;

  ChatApi(this._apiClient);

  Future<ChatReplyResult> sendMessage({
    required String message,
    required String language,
    String? sessionId,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'language': language,
    };

    if (sessionId != null) {
      body['session_id'] = sessionId;
    }

    final data = await _apiClient.post('/chat/messages/', body: body);

    return ChatReplyResult(
      reply: data['reply']?.toString() ?? 'لم يصل رد من الخادم.',
      sessionId: data['session_id']?.toString() ?? sessionId,
    );
  }
}