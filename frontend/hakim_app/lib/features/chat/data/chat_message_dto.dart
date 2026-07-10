class ChatMessageDto {
  final int id;
  final String sender;
  final String content;
  final DateTime createdAt;

  const ChatMessageDto({
    required this.id,
    required this.sender,
    required this.content,
    required this.createdAt,
  });

  bool get isUser => sender == 'user';

  bool get isAssistant => sender == 'assistant';

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sender: json['sender']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  static DateTime _parseDateTime(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}
