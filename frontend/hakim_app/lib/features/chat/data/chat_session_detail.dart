import 'chat_message_dto.dart';

class ChatSessionDetail {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessageDto> messages;

  const ChatSessionDetail({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  factory ChatSessionDetail.fromJson(Map<String, dynamic> json) {
    final sessionJson = Map<String, dynamic>.from(
      json['session'] as Map? ?? const <String, dynamic>{},
    );

    final messagesJson = json['messages'] as List? ?? const [];

    return ChatSessionDetail(
      id: sessionJson['id']?.toString() ?? '',
      title: sessionJson['title']?.toString() ?? '',
      createdAt: _parseDateTime(sessionJson['created_at']),
      updatedAt: _parseDateTime(sessionJson['updated_at']),
      messages: messagesJson
          .whereType<Map>()
          .map(
            (message) =>
                ChatMessageDto.fromJson(Map<String, dynamic>.from(message)),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session': {
        'id': id,
        'title': title,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      },
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }

  static DateTime _parseDateTime(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
