import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/chat/chat_sessions_screen.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/data/auth_service.dart';
import 'l10n/generated/app_localizations.dart';

class HakimApp extends StatelessWidget {
  const HakimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hakim',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // مؤقتاً نخلي التطبيق عربي لاختبار RTL
      locale: const Locale('ar'),

      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      onGenerateRoute: (settings) {
        if (settings.name != '/chat-sessions') {
          return null;
        }

        final authService = settings.arguments;

        if (authService is! AuthService) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const AuthGate(),
          );
        }

        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ChatSessionsScreen(authService: authService),
        );
      },

      home: const AuthGate(),
    );
  }
}
