import 'chat_api.dart';
import 'chat_reply_result.dart';

class ChatReplyService {
  final ChatApi? chatApi;

  const ChatReplyService({
    this.chatApi,
  });

  static const bool useApi = bool.fromEnvironment(
    'USE_API',
    defaultValue: false,
  );

  Future<ChatReplyResult> getReply({
    required String message,
    String? sessionId,
    String? token,
  }) async {
    if (useApi && chatApi != null) {
      return chatApi!.sendMessage(
        message: message,
        sessionId: sessionId,
        token: token,
      );
    }

    await Future.delayed(const Duration(milliseconds: 700));

    return ChatReplyResult(
      reply: _buildMockHakimReply(message),
      sessionId: sessionId,
    );
  }

  String _buildMockHakimReply(String userText) {
    final text = _normalizeArabic(userText);

    final hasEmergencyFlag = _containsAny(text, [
      'الم صدر',
      'ضغط بالصدر',
      'ضيق نفس',
      'صعوبه تنفس',
      'اغماء',
      'فقدان الوعي',
      'نزيف شديد',
      'تشنج',
      'شلل',
      'ضعف مفاجئ',
      'صعوبه بالكلام',
      'اضطراب بالكلام',
      'الم شديد جدا',
    ]);

    if (hasEmergencyFlag) {
      return 'تنبيه مهم: بعض الأعراض التي ذكرتها قد تحتاج إلى رعاية عاجلة، خاصة إذا كانت شديدة أو ظهرت بشكل مفاجئ. يرجى مراجعة الطوارئ أو الاتصال بالإسعاف فوراً. حكيم يساعد في التوجيه الأولي فقط ولا يقدم تشخيصاً نهائياً.';
    }

    return 'فهمت عليك. حتى أقدر أوجهك بشكل أفضل، أحتاج منك بعض التفاصيل:\n\n'
        '1. منذ متى بدأت الأعراض؟\n'
        '2. ما شدة الألم أو التعب من 1 إلى 10؟\n'
        '3. هل يوجد حرارة، دوخة، ضيق تنفس، أو ألم صدر؟\n'
        '4. هل لديك أمراض مزمنة، أدوية دائمة، أو حساسية؟';
  }

  String _normalizeArabic(String value) {
    return value
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
}