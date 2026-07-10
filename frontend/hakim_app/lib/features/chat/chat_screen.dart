import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/data/auth_service.dart';
import '../onboarding/welcome_screen.dart';
import 'data/chat_api.dart';
import 'data/chat_message_dto.dart';
import 'data/chat_reply_service.dart';

class ChatScreen extends StatefulWidget {
  final String? initialSessionId;
  final List<ChatMessageDto> initialMessages;
  final bool isReadOnly;

  const ChatScreen({
    super.key,
    this.initialSessionId,
    this.initialMessages = const [],
    this.isReadOnly = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();

  final ChatReplyService _chatReplyService = ChatReplyService(
    chatApi: ChatApi(ApiClient()),
  );

  final List<_ChatMessage> _messages = [];

  String? _sessionId;
  bool _isHakimTyping = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();

    _sessionId = widget.initialSessionId;

    _messages.addAll(
      widget.initialMessages.map(
        (message) => _ChatMessage(
          text: message.content,
          isUser: message.isUser,
          createdAt: message.createdAt.toLocal(),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_messages.isEmpty && widget.initialSessionId == null) {
      final l10n = AppLocalizations.of(context);

      _messages.addAll([
        _ChatMessage(
          text: l10n.chatWelcomeMessage,
          isUser: false,
          createdAt: DateTime.now(),
        ),
        _ChatMessage(
          text: l10n.chatAskSymptoms,
          isUser: false,
          createdAt: DateTime.now(),
        ),
      ]);
    }
  }

  Future<void> _sendMessage() async {
    if (widget.isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هذه المحادثة معروضة من النسخة المحلية. يلزم الاتصال بالخادم لإرسال رسالة.',
          ),
        ),
      );
      return;
    }

    final text = _messageController.text.trim();

    if (text.isEmpty || _isHakimTyping) return;

    setState(() {
      _messages.add(
        _ChatMessage(text: text, isUser: true, createdAt: DateTime.now()),
      );
      _isHakimTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final token = await _authService.getAccessToken();

      final result = await _chatReplyService.getReply(
        message: text,
        sessionId: _sessionId,
        token: token,
      );

      if (!mounted) return;

      _sessionId = result.sessionId;

      setState(() {
        _messages.add(
          _ChatMessage(
            text: result.reply,
            isUser: false,
            createdAt: DateTime.now(),
          ),
        );
        _isHakimTyping = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(
            text:
                'تعذر الاتصال بالخادم حالياً. تأكد من تشغيل السيرفر واتصال الجوال واللابتوب على نفس الشبكة.',
            isUser: false,
            createdAt: DateTime.now(),
          ),
        );
        _isHakimTyping = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _confirmLogout() async {
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('تسجيل الخروج'),
              content: const Text(
                'هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('تسجيل الخروج'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout || !mounted) return;

    await _logout();
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تسجيل الخروج. حاول مرة أخرى.')),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(l10n.hakimChat),
        actions: [
          if (widget.initialSessionId == null)
            IconButton(
              tooltip: 'المحادثات السابقة',
              onPressed: _isLoggingOut
                  ? null
                  : () {
                      Navigator.of(context).pushNamed('/chat-sessions');
                    },
              icon: const Icon(Icons.history_rounded),
            ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: _isLoggingOut ? null : _confirmLogout,
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.isReadOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.amber.shade100,
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.amber.shade900),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'أنت تعمل دون اتصال. هذه المحادثة متاحة للقراءة فقط.',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length + (_isHakimTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isHakimTyping && index == _messages.length) {
                  return const _TypingBubble();
                }

                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !widget.isReadOnly && !_isLoggingOut,
                    textInputAction: TextInputAction.send,
                    textAlign: TextAlign.start,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: widget.isReadOnly
                          ? 'الاتصال بالخادم مطلوب لمتابعة المحادثة'
                          : l10n.symptomInputHint,
                      filled: true,
                      fillColor: AppTheme.inputBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: widget.isReadOnly
                        ? null
                        : (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: widget.isReadOnly || _isHakimTyping
                      ? Colors.grey.shade400
                      : AppTheme.primary,
                  child: IconButton(
                    onPressed: widget.isReadOnly || _isHakimTyping
                        ? null
                        : _sendMessage,
                    icon: const Icon(Icons.send_rounded),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: isUser ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(18),
              topEnd: const Radius.circular(18),
              bottomStart: Radius.circular(isUser ? 18 : 4),
              bottomEnd: Radius.circular(isUser ? 4 : 18),
            ),
            border: Border.all(
              color: isUser ? AppTheme.primary : AppTheme.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? 'أنت' : 'حكيم',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isUser ? Colors.white70 : AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message.text,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: isUser ? Colors.white : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                TimeOfDay.fromDateTime(message.createdAt).format(context),
                style: TextStyle(
                  fontSize: 11,
                  color: isUser ? Colors.white60 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'حكيم يكتب...',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime createdAt;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.createdAt,
  });
}
