import 'dart:async';

import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../onboarding/welcome_screen.dart';
import 'data/auth_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();

  bool? _hasLocalSession;

  @override
  void initState() {
    super.initState();
    _initializeAuthentication();
  }

  Future<void> _initializeAuthentication() async {
    final hasLocalSession = await _authService.isLoggedIn();

    if (!mounted) return;

    setState(() {
      _hasLocalSession = hasLocalSession;
    });

    if (hasLocalSession) {
      unawaited(_validateSessionInBackground());
    }
  }

  Future<void> _validateSessionInBackground() async {
    try {
      final restored = await _authService.restoreSession().timeout(
        const Duration(seconds: 8),
        onTimeout: () => true,
      );

      if (!restored && mounted) {
        setState(() {
          _hasLocalSession = false;
        });
      }
    } catch (_) {
      // A temporary network or server failure must not block app startup.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalSession = _hasLocalSession;

    if (hasLocalSession == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (hasLocalSession) {
      return const ChatScreen();
    }

    return const WelcomeScreen();
  }
}
