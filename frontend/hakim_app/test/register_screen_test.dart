import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/core/theme/app_theme.dart';
import 'package:hakim_app/features/auth/auth_role.dart';
import 'package:hakim_app/features/auth/data/auth_service.dart';
import 'package:hakim_app/features/auth/register_screen.dart';
import 'package:hakim_app/l10n/generated/app_localizations.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({this.registerError});

  final ApiException? registerError;
  final Completer<String?> _roleCompleter = Completer<String?>();

  int registerCallCount = 0;

  String? receivedUsername;
  String? receivedEmail;
  String? receivedPassword;
  String? receivedPasswordConfirm;
  String? receivedRole;

  @override
  Future<void> register({
    required String username,
    String? email,
    required String password,
    required String passwordConfirm,
    required String role,
  }) async {
    registerCallCount++;

    receivedUsername = username;
    receivedEmail = email;
    receivedPassword = password;
    receivedPasswordConfirm = passwordConfirm;
    receivedRole = role;

    final error = registerError;

    if (error != null) {
      throw error;
    }
  }

  @override
  Future<String?> getRole() {
    return _roleCompleter.future;
  }
}

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
      home: RegisterScreen(role: role, authService: authService),
    );
  }

  Future<void> enterRegistrationData(
    WidgetTester tester, {
    String username = 'test-user',
    String email = 'test@example.com',
    String password = 'Test12345!',
    String passwordConfirm = 'Test12345!',
  }) async {
    await tester.enterText(
      find.byKey(const Key('register_username_field')),
      username,
    );

    if (email.isNotEmpty) {
      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        email,
      );
    }

    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      password,
    );

    await tester.enterText(
      find.byKey(const Key('register_password_confirm_field')),
      passwordConfirm,
    );
  }

  Future<Finder> prepareSubmitButton(WidgetTester tester) async {
    final button = find.byKey(const Key('register_submit_button'));

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    return button;
  }

  testWidgets('required fields prevent registration', (tester) async {
    final authService = _FakeAuthService();

    await tester.pumpWidget(
      buildTestApp(role: AuthRole.patient, authService: authService),
    );
    await tester.pumpAndSettle();

    final button = await prepareSubmitButton(tester);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Enter a username.'), findsOneWidget);
    expect(find.text('Enter a password.'), findsOneWidget);
    expect(find.text('Enter the password again.'), findsOneWidget);

    expect(authService.registerCallCount, 0);
  });

  testWidgets('invalid email and password values are rejected locally', (
    tester,
  ) async {
    final authService = _FakeAuthService();

    await tester.pumpWidget(
      buildTestApp(role: AuthRole.patient, authService: authService),
    );
    await tester.pumpAndSettle();

    await enterRegistrationData(
      tester,
      email: 'invalid-email',
      password: '1234567',
      passwordConfirm: 'different-password',
    );

    final button = await prepareSubmitButton(tester);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid email address or leave the field empty.'),
      findsOneWidget,
    );

    expect(
      find.text('The password must contain at least 8 characters.'),
      findsOneWidget,
    );

    expect(find.text('The passwords do not match.'), findsOneWidget);

    expect(authService.registerCallCount, 0);
  });

  testWidgets('doctor registration sends trimmed values and doctor role', (
    tester,
  ) async {
    final authService = _FakeAuthService();

    await tester.pumpWidget(
      buildTestApp(role: AuthRole.doctor, authService: authService),
    );
    await tester.pumpAndSettle();

    await enterRegistrationData(
      tester,
      username: '  doctor-user  ',
      email: '  doctor@example.com  ',
    );

    final button = await prepareSubmitButton(tester);

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(authService.registerCallCount, 1);
    expect(authService.receivedUsername, 'doctor-user');
    expect(authService.receivedEmail, 'doctor@example.com');
    expect(authService.receivedPassword, 'Test12345!');
    expect(authService.receivedPasswordConfirm, 'Test12345!');
    expect(authService.receivedRole, 'doctor');
  });

  testWidgets('empty optional email is sent as null for patient registration', (
    tester,
  ) async {
    final authService = _FakeAuthService();

    await tester.pumpWidget(
      buildTestApp(role: AuthRole.patient, authService: authService),
    );
    await tester.pumpAndSettle();

    await enterRegistrationData(tester, username: 'patient-user', email: '');

    final button = await prepareSubmitButton(tester);

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(authService.registerCallCount, 1);
    expect(authService.receivedEmail, isNull);
    expect(authService.receivedRole, 'patient');
  });

  testWidgets('DRF field errors are displayed beside their fields', (
    tester,
  ) async {
    final authService = _FakeAuthService(
      registerError: const ApiException(
        'Username already exists.',
        statusCode: 400,
        fieldErrors: {
          'username': ['Username already exists.'],
          'password_confirm': ['Passwords do not match.'],
        },
      ),
    );

    await tester.pumpWidget(
      buildTestApp(role: AuthRole.patient, authService: authService),
    );
    await tester.pumpAndSettle();

    await enterRegistrationData(tester);

    final button = await prepareSubmitButton(tester);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Username already exists.'), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(authService.registerCallCount, 1);
  });

  testWidgets('general API error is displayed above the submit button', (
    tester,
  ) async {
    final authService = _FakeAuthService(
      registerError: const ApiException(
        'Registration is temporarily unavailable.',
        statusCode: 503,
      ),
    );

    await tester.pumpWidget(
      buildTestApp(role: AuthRole.patient, authService: authService),
    );
    await tester.pumpAndSettle();

    await enterRegistrationData(tester);

    final button = await prepareSubmitButton(tester);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      find.text('Registration is temporarily unavailable.'),
      findsOneWidget,
    );

    expect(authService.registerCallCount, 1);
  });

  testWidgets('general API message remains visible with DRF field errors', (
    tester,
  ) async {
    final authService = _FakeAuthService(
      registerError: const ApiException(
        'Registration is temporarily unavailable.',
        statusCode: 503,
        fieldErrors: {
          'username': ['Invalid username.'],
        },
      ),
    );

    await tester.pumpWidget(
      buildTestApp(role: AuthRole.patient, authService: authService),
    );
    await tester.pumpAndSettle();

    await enterRegistrationData(tester);

    final button = await prepareSubmitButton(tester);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Invalid username.'), findsOneWidget);
    expect(
      find.text('Registration is temporarily unavailable.'),
      findsOneWidget,
    );

    expect(authService.registerCallCount, 1);
  });
}
