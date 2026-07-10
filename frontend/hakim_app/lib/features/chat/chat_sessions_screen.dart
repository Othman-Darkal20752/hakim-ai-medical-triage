import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../auth/data/auth_service.dart';
import 'chat_screen.dart';
import 'data/chat_history_api.dart';
import 'data/chat_history_repository.dart';
import 'data/chat_history_snapshot.dart';
import 'data/chat_session_detail.dart';
import 'data/chat_session_summary.dart';

enum _SessionAction { open, delete }

class ChatSessionsScreen extends StatefulWidget {
  const ChatSessionsScreen({super.key});

  @override
  State<ChatSessionsScreen> createState() => _ChatSessionsScreenState();
}

class _ChatSessionsScreenState extends State<ChatSessionsScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final ChatHistoryApi _chatHistoryApi = ChatHistoryApi(ApiClient());
  final Connectivity _connectivity = Connectivity();

  late final ChatHistoryRepository _chatHistoryRepository =
      ChatHistoryRepository(_chatHistoryApi);

  ChatHistorySnapshot _history = const ChatHistorySnapshot.empty();

  bool _isLoading = true;
  bool _isOffline = false;
  DateTime? _cachedAt;

  String? _errorMessage;
  String? _openingSessionId;
  String? _deletingSessionId;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _autoRetryTimer;
  bool _isAutoRefreshing = false;

  bool get _isBusy => _openingSessionId != null || _deletingSessionId != null;

  bool get _needsAutoRefresh => _isOffline || _errorMessage != null;

  List<ChatSessionSummary> get _sessions => _history.sessions;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );

    _loadSessions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retryWhenNetworkAvailable();
    }
  }

  Future<void> _handleConnectivityChanged(
    List<ConnectivityResult> connectivityResults,
  ) async {
    if (!mounted || !_needsAutoRefresh || _isLoading || _isAutoRefreshing) {
      return;
    }

    final hasNetwork = connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );

    if (!hasNetwork) {
      return;
    }

    _isAutoRefreshing = true;

    try {
      await _loadSessions(showLoadingIndicator: false);
    } finally {
      _isAutoRefreshing = false;
    }
  }

  Future<void> _retryWhenNetworkAvailable() async {
    if (!mounted || !_needsAutoRefresh || _isLoading || _isAutoRefreshing) {
      return;
    }

    try {
      final connectivityResults = await _connectivity.checkConnectivity();

      await _handleConnectivityChanged(connectivityResults);
    } catch (_) {
      // The existing encrypted cache remains available.
    }
  }

  void _syncAutoRetryTimer() {
    if (!_needsAutoRefresh) {
      _autoRetryTimer?.cancel();
      _autoRetryTimer = null;
      return;
    }

    _autoRetryTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _retryWhenNetworkAvailable(),
    );
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

  Future<int> _requireUserId() async {
    final userId = await _authService.getUserId();

    if (userId == null || userId <= 0) {
      throw const ApiException(
        'معرف المستخدم غير موجود. يرجى تسجيل الدخول مجددًا.',
        statusCode: 401,
      );
    }

    return userId;
  }

  Future<void> _loadSessions({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final token = await _requireAccessToken();
      final userId = await _requireUserId();

      final result = await _chatHistoryRepository.loadHistory(
        token: token,
        userId: userId,
      );

      if (!mounted) return;

      setState(() {
        _history = result.history;
        _isOffline = result.isOffline;
        _cachedAt = result.cachedAt;
        _isLoading = false;
      });

      _syncAutoRetryTimer();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'تعذر تحميل المحادثات السابقة، ولا توجد نسخة محلية متاحة.';
        _isOffline = false;
        _cachedAt = null;
        _isLoading = false;
      });

      _syncAutoRetryTimer();
    }
  }

  Future<void> _openSession(ChatSessionSummary session) async {
    if (_isBusy) return;

    setState(() {
      _openingSessionId = session.id;
    });

    try {
      final detail = _history.detailFor(session.id);

      if (detail == null) {
        throw StateError(
          'Session details are missing from the chat history snapshot.',
        );
      }

      if (!mounted) return;

      setState(() {
        _openingSessionId = null;
      });

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            initialSessionId: detail.id,
            initialMessages: detail.messages,
            isReadOnly: _isOffline,
          ),
        ),
      );

      if (mounted && !_isOffline) {
        await _loadSessions();
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _openingSessionId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح المحادثة المحفوظة.')),
      );
    }
  }

  Future<void> _confirmDeleteSession(ChatSessionSummary session) async {
    if (_isBusy) return;

    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف المحادثات أثناء العمل دون اتصال.'),
        ),
      );
      return;
    }

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
    if (_isOffline) return;

    setState(() {
      _deletingSessionId = session.id;
    });

    try {
      final token = await _requireAccessToken();
      final userId = await _requireUserId();

      await _chatHistoryApi.deleteSession(sessionId: session.id, token: token);

      await _chatHistoryRepository.removeSessionFromCache(
        userId: userId,
        sessionId: session.id,
      );

      if (!mounted) return;

      final updatedSessions = _history.sessions
          .where((item) => item.id != session.id)
          .toList();

      final updatedDetails = Map<String, ChatSessionDetail>.from(
        _history.sessionDetails,
      )..remove(session.id);

      setState(() {
        _history = ChatHistorySnapshot(
          sessions: updatedSessions,
          sessionDetails: updatedDetails,
        );
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
        '${localDateTime.year}/'
        '${localDateTime.month.toString().padLeft(2, '0')}/'
        '${localDateTime.day.toString().padLeft(2, '0')}';

    final time = TimeOfDay.fromDateTime(localDateTime).format(context);

    return '$date - $time';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _autoRetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحادثات السابقة')),
      body: Column(
        children: [
          if (_isOffline) _buildOfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadSessions,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    final cachedAt = _cachedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.amber.shade100,
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.amber.shade900),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cachedAt == null
                  ? 'أنت تعمل دون اتصال. يتم عرض النسخة المحفوظة.'
                  : 'أنت تعمل دون اتصال. آخر تحديث: '
                        '${_formatDate(context, cachedAt)}',
              style: TextStyle(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
                    '${session.messagesCount} رسالة • '
                    '${_formatDate(context, session.updatedAt)}',
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
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _SessionAction.open,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.open_in_new_rounded),
                          title: Text('فتح المحادثة'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _SessionAction.delete,
                        enabled: !_isOffline,
                        child: ListTile(
                          enabled: !_isOffline,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: _isOffline ? Colors.grey : Colors.red,
                          ),
                          title: Text(
                            _isOffline
                                ? 'الحذف غير متاح دون اتصال'
                                : 'حذف المحادثة',
                            style: TextStyle(
                              color: _isOffline ? Colors.grey : Colors.red,
                            ),
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
