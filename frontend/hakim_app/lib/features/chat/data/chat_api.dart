import '../../../core/network/api_client.dart';

class ChatApi {
  final ApiClient _apiClient;

  ChatApi(this._apiClient);

  Future<String> sendMessage({
    required String message,
    String? sessionId,
    String? token,
  }) async {
    final data = await _apiClient.post(
      '/chat/messages/',
      token: token,
      body: {
        'message': message,
        'session_id': ?sessionId,
      },
    );

    return data['reply']?.toString() ?? 'لم يصل رد من الخادم.';
  }
}