import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/role_selection_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    size: 48,
                    color: AppTheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                l10n.appName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                l10n.appTagline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppTheme.textMedium,
                ),
              ),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  l10n.welcomeDisclaimer,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Color(0xFF334155),
                  ),
                ),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoleSelectionScreen(),
                    ),
                  );
                },
                child: Text(l10n.getStarted),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}