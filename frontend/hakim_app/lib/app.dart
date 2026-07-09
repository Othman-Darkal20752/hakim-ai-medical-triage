import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/welcome_screen.dart';
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

      home: const WelcomeScreen(),
    );
  }
}