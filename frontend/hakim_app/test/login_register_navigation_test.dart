import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/core/theme/app_theme.dart';
import 'package:hakim_app/features/auth/auth_role.dart';
import 'package:hakim_app/features/auth/data/auth_service.dart';
import 'package:hakim_app/features/auth/login_screen.dart';
import 'package:hakim_app/features/auth/register_screen.dart';
import 'package:hakim_app/l10n/generated/app_localizations.dart';

void main() {
  Widget buildTestApp({
    required AuthRole role,
    required AuthService authService,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginScreen(role: role, authService: authService),
    );
  }

  Future<void> openRegisterScreen(WidgetTester tester) async {
    final createAccountButton = find.byKey(
      const Key('login_create_account_button'),
    );

    expect(createAccountButton, findsOneWidget);

    await tester.ensureVisible(createAccountButton);
    await tester.pumpAndSettle();

    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'patient login opens patient registration with same AuthService',
    (tester) async {
      final authService = AuthService();

      await tester.pumpWidget(
        buildTestApp(role: AuthRole.patient, authService: authService),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_google_button')), findsOneWidget);

      await openRegisterScreen(tester);

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Create Patient Account'), findsOneWidget);

      final registerScreen = tester.widget<RegisterScreen>(
        find.byType(RegisterScreen),
      );

      expect(registerScreen.role, AuthRole.patient);
      expect(registerScreen.authService, same(authService));
    },
  );

  testWidgets(
    'doctor login opens doctor registration and hides Google sign-in',
    (tester) async {
      final authService = AuthService();

      await tester.pumpWidget(
        buildTestApp(role: AuthRole.doctor, authService: authService),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_google_button')), findsNothing);

      await openRegisterScreen(tester);

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Create Doctor Account'), findsOneWidget);

      final registerScreen = tester.widget<RegisterScreen>(
        find.byType(RegisterScreen),
      );

      expect(registerScreen.role, AuthRole.doctor);
      expect(registerScreen.authService, same(authService));
    },
  );
}
