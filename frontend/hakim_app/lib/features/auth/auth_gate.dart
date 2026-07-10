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

  late final Future<bool> _restoreSessionFuture;

  @override
  void initState() {
    super.initState();
    _restoreSessionFuture = _authService.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _restoreSessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return const ChatScreen();
        }

        return const WelcomeScreen();
      },
    );
  }
}
