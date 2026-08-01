import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/core/theme/app_theme.dart';
import 'package:hakim_app/features/auth/auth_role.dart';
import 'package:hakim_app/features/auth/login_screen.dart';
import 'package:hakim_app/features/onboarding/welcome_screen.dart';
import 'package:hakim_app/l10n/generated/app_localizations.dart';

void main() {
  Widget buildTestApp() {
    return MaterialApp(
      locale: const Locale('en'),
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const WelcomeScreen(),
    );
  }

  Future<void> selectRoleAndContinue(
    WidgetTester tester, {
    required String roleLabel,
  }) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final roleFinder = find.text(roleLabel);

    await tester.ensureVisible(roleFinder);
    await tester.pumpAndSettle();

    await tester.tap(roleFinder);
    await tester.pump();

    final continueFinder = find.text('Continue');

    await tester.ensureVisible(continueFinder);
    await tester.pumpAndSettle();

    await tester.tap(continueFinder);
    await tester.pumpAndSettle();
  }

  testWidgets('patient selection opens patient login flow', (tester) async {
    await selectRoleAndContinue(tester, roleLabel: 'Patient');

    expect(find.byType(LoginScreen), findsOneWidget);

    final loginScreen = tester.widget<LoginScreen>(find.byType(LoginScreen));

    expect(loginScreen.role, AuthRole.patient);
    expect(find.text('Patient Sign In'), findsOneWidget);
  });

  testWidgets('doctor selection opens doctor login flow', (tester) async {
    await selectRoleAndContinue(tester, roleLabel: 'Doctor');

    expect(find.byType(LoginScreen), findsOneWidget);

    final loginScreen = tester.widget<LoginScreen>(find.byType(LoginScreen));

    expect(loginScreen.role, AuthRole.doctor);
    expect(find.text('Doctor Sign In'), findsOneWidget);
  });
}
