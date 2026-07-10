import 'chat_session_detail.dart';
import 'chat_session_summary.dart';

class ChatHistorySnapshot {
  final List<ChatSessionSummary> sessions;
  final Map<String, ChatSessionDetail> sessionDetails;

  const ChatHistorySnapshot({
    required this.sessions,
    required this.sessionDetails,
  });

  const ChatHistorySnapshot.empty()
    : sessions = const [],
      sessionDetails = const {};

  factory ChatHistorySnapshot.fromJson(Map<String, dynamic> json) {
    final sessionsJson = json['sessions'] as List? ?? const [];
    final sessionDetailsJson =
        json['session_details'] as Map? ?? const <String, dynamic>{};

    final sessions = sessionsJson
        .whereType<Map>()
        .map(
          (session) =>
              ChatSessionSummary.fromJson(Map<String, dynamic>.from(session)),
        )
        .where((session) => session.id.isNotEmpty)
        .toList();

    final sessionDetails = <String, ChatSessionDetail>{};

    for (final entry in sessionDetailsJson.entries) {
      final sessionId = entry.key.toString();
      final rawDetail = entry.value;

      if (sessionId.isEmpty || rawDetail is! Map) {
        continue;
      }

      final detail = ChatSessionDetail.fromJson(
        Map<String, dynamic>.from(rawDetail),
      );

      if (detail.id != sessionId) {
        continue;
      }

      sessionDetails[sessionId] = detail;
    }

    return ChatHistorySnapshot(
      sessions: sessions,
      sessionDetails: sessionDetails,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessions': sessions.map((session) => session.toJson()).toList(),
      'session_details': sessionDetails.map(
        (sessionId, detail) => MapEntry(sessionId, detail.toJson()),
      ),
    };
  }

  ChatSessionDetail? detailFor(String sessionId) {
    return sessionDetails[sessionId];
  }
}
