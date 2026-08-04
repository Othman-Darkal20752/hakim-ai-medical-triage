import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/features/chat/chat_screen.dart';
import 'package:hakim_app/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('opens patient health profile from the chat app bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          healthProfileBuilder: (_) => const Scaffold(
            body: Center(
              key: Key('patient-health-profile-destination'),
              child: Text('Patient health profile'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final healthProfileButton = find.byKey(const Key('chat-health-profile'));

    expect(healthProfileButton, findsOneWidget);

    final iconButton = tester.widget<IconButton>(healthProfileButton);

    expect(iconButton.tooltip, 'My Health Profile');

    await tester.tap(healthProfileButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('patient-health-profile-destination')),
      findsOneWidget,
    );
  });
}
