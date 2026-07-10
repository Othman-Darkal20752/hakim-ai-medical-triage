import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../auth/data/auth_service.dart';
import 'chat_screen.dart';
import 'data/chat_history_api.dart';
import 'data/chat_session_summary.dart';

enum _SessionAction { open, delete }

class ChatSessionsScreen extends StatefulWidget {
  const ChatSessionsScreen({super.key});

  @override
  State<ChatSessionsScreen> createState() => _ChatSessionsScreenState();
}

class _ChatSessionsScreenState extends State<ChatSessionsScreen> {
  final AuthService _authService = AuthService();
  final ChatHistoryApi _chatHistoryApi = ChatHistoryApi(ApiClient());

  List<ChatSessionSummary> _sessions = [];

  bool _isLoading = true;
  String? _errorMessage;
  String? _openingSessionId;
  String? _deletingSessionId;

  bool get _isBusy => _openingSessionId != null || _deletingSessionId != null;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<String> _requireAccessToken() async {
    final token = await _authService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw const ApiException(
        'جلسة تسجيل الدخول غير موجودة.',
        statusCode: 401,
      );
    }

    return token;
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _requireAccessToken();
      final sessions = await _chatHistoryApi.getSessions(token: token);

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'تعذر تحميل المحادثات السابقة. تأكد من تشغيل الخادم والاتصال بالشبكة.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openSession(ChatSessionSummary session) async {
    if (_isBusy) return;

    setState(() {
      _openingSessionId = session.id;
    });

    try {
      final token = await _requireAccessToken();

      final detail = await _chatHistoryApi.getSessionDetail(
        sessionId: session.id,
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _openingSessionId = null;
      });

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            initialSessionId: detail.id,
            initialMessages: detail.messages,
          ),
        ),
      );

      if (mounted) {
        await _loadSessions();
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _openingSessionId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر فتح المحادثة. تأكد من تشغيل الخادم والاتصال بالشبكة.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteSession(ChatSessionSummary session) async {
    if (_isBusy) return;

    final title = session.title.isEmpty ? 'محادثة بدون عنوان' : session.title;

    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('حذف المحادثة'),
              content: Text(
                'هل أنت متأكد من حذف "$title"؟\n\n'
                'لا يمكن التراجع عن هذا الإجراء.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('حذف'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete || !mounted) return;

    await _deleteSession(session);
  }

  Future<void> _deleteSession(ChatSessionSummary session) async {
    setState(() {
      _deletingSessionId = session.id;
    });

    try {
      final token = await _requireAccessToken();

      await _chatHistoryApi.deleteSession(sessionId: session.id, token: token);

      if (!mounted) return;

      setState(() {
        _sessions.removeWhere((item) => item.id == session.id);
        _deletingSessionId = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف المحادثة بنجاح.')));
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _deletingSessionId = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _deletingSessionId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر حذف المحادثة. يلزم الاتصال بالخادم للمحاولة من جديد.',
          ),
        ),
      );
    }
  }

  void _handleSessionAction(_SessionAction action, ChatSessionSummary session) {
    switch (action) {
      case _SessionAction.open:
        _openSession(session);
      case _SessionAction.delete:
        _confirmDeleteSession(session);
    }
  }

  String _formatDate(BuildContext context, DateTime dateTime) {
    final localDateTime = dateTime.toLocal();

    final date =
        '${localDateTime.year}/${localDateTime.month.toString().padLeft(2, '0')}/${localDateTime.day.toString().padLeft(2, '0')}';

    final time = TimeOfDay.fromDateTime(localDateTime).format(context);

    return '$date - $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحادثات السابقة')),
      body: RefreshIndicator(onRefresh: _loadSessions, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    if (_sessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.chat_bubble_outline_rounded, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'لا توجد محادثات سابقة حتى الآن.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final isOpening = _openingSessionId == session.id;
        final isDeleting = _deletingSessionId == session.id;

        return Card(
          child: ListTile(
            onTap: _isBusy ? null : () => _openSession(session),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            leading: const CircleAvatar(child: Icon(Icons.chat_rounded)),
            title: Text(
              session.title.isEmpty ? 'محادثة بدون عنوان' : session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (session.lastMessage.isNotEmpty)
                    Text(
                      session.lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${session.messagesCount} رسالة • ${_formatDate(context, session.updatedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            trailing: isOpening || isDeleting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PopupMenuButton<_SessionAction>(
                    enabled: !_isBusy,
                    tooltip: 'خيارات المحادثة',
                    onSelected: (action) {
                      _handleSessionAction(action, session);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _SessionAction.open,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.open_in_new_rounded),
                          title: Text('فتح المحادثة'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _SessionAction.delete,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                          title: Text(
                            'حذف المحادثة',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
