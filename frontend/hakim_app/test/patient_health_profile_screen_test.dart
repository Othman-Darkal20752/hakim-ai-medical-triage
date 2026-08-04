import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/features/patient/data/patient_health_profile.dart';
import 'package:hakim_app/features/patient/data/patient_health_profile_update.dart';
import 'package:hakim_app/features/patient/patient_health_profile_screen.dart';
import 'package:hakim_app/l10n/generated/app_localizations.dart';

void main() {
  PatientHealthProfile buildProfile({
    List<String> chronicConditions = const [],
    List<String> allergies = const [],
    List<String> currentMedications = const [],
    List<String> previousSurgeries = const [],
    SmokingStatus smokingStatus = SmokingStatus.unknown,
    AlcoholUse alcoholUse = AlcoholUse.unknown,
    PregnancyStatus pregnancyStatus = PregnancyStatus.notApplicable,
    DateTime? lastReviewedAt,
  }) {
    return PatientHealthProfile(
      id: 15,
      chronicConditions: chronicConditions,
      allergies: allergies,
      currentMedications: currentMedications,
      previousSurgeries: previousSurgeries,
      smokingStatus: smokingStatus,
      alcoholUse: alcoholUse,
      pregnancyStatus: pregnancyStatus,
      lastReviewedAt: lastReviewedAt,
      createdAt: DateTime.utc(2026, 8, 3),
      updatedAt: DateTime.utc(2026, 8, 4),
    );
  }

  Widget buildTestApp({
    required Future<PatientHealthProfile> Function() profileLoader,
    required Future<PatientHealthProfile> Function(
      PatientHealthProfileUpdate update,
    )
    profileUpdater,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: PatientHealthProfileScreen(
        profileLoader: profileLoader,
        profileUpdater: profileUpdater,
      ),
    );
  }

  Future<void> revealWidget(WidgetTester tester, Finder target) async {
    await tester.dragUntilVisible(
      target,
      find.byKey(const Key('patient-health-profile-form')),
      const Offset(0, -500),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('shows loading while health profile is loading', (tester) async {
    final completer = Completer<PatientHealthProfile>();

    await tester.pumpWidget(
      buildTestApp(
        profileLoader: () => completer.future,
        profileUpdater: (_) async => buildProfile(),
      ),
    );

    expect(
      find.byKey(const Key('patient-health-profile-loading')),
      findsOneWidget,
    );
  });

  testWidgets('retries loading after an error', (tester) async {
    var loadCount = 0;

    Future<PatientHealthProfile> loadProfile() async {
      loadCount++;

      if (loadCount == 1) {
        throw const ApiException('Temporary failure.', statusCode: 500);
      }

      return buildProfile();
    }

    await tester.pumpWidget(
      buildTestApp(
        profileLoader: loadProfile,
        profileUpdater: (_) async => buildProfile(),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('patient-health-profile-load-error')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('patient-health-profile-retry')));

    await tester.pumpAndSettle();

    expect(loadCount, 2);

    expect(
      find.byKey(const Key('patient-health-profile-form')),
      findsOneWidget,
    );
  });

  testWidgets('prefills medical list fields from the profile', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        profileLoader: () async => buildProfile(
          chronicConditions: const ['Asthma', 'Diabetes'],
          allergies: const ['Penicillin'],
          currentMedications: const ['Medication A'],
          previousSurgeries: const ['Appendectomy'],
          smokingStatus: SmokingStatus.former,
          alcoholUse: AlcoholUse.never,
        ),
        profileUpdater: (_) async => buildProfile(),
      ),
    );

    await tester.pumpAndSettle();

    final chronicConditions = tester.widget<TextField>(
      find.byKey(const Key('patient-health-profile-chronic-conditions')),
    );

    final allergies = tester.widget<TextField>(
      find.byKey(const Key('patient-health-profile-allergies')),
    );

    expect(chronicConditions.controller?.text, 'Asthma\nDiabetes');
    expect(allergies.controller?.text, 'Penicillin');
  });

  testWidgets('submits normalized editable health profile data', (
    tester,
  ) async {
    PatientHealthProfileUpdate? submittedUpdate;

    await tester.pumpWidget(
      buildTestApp(
        profileLoader: () async => buildProfile(
          smokingStatus: SmokingStatus.former,
          alcoholUse: AlcoholUse.never,
          pregnancyStatus: PregnancyStatus.notApplicable,
        ),
        profileUpdater: (update) async {
          submittedUpdate = update;

          return buildProfile(
            chronicConditions: update.chronicConditions,
            allergies: update.allergies,
            currentMedications: update.currentMedications,
            previousSurgeries: update.previousSurgeries,
            smokingStatus: update.smokingStatus,
            alcoholUse: update.alcoholUse,
            pregnancyStatus: update.pregnancyStatus,
            lastReviewedAt: DateTime.utc(2026, 8, 4, 8),
          );
        },
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('patient-health-profile-chronic-conditions')),
      ' Asthma \n\n Diabetes ',
    );

    await tester.enterText(
      find.byKey(const Key('patient-health-profile-allergies')),
      ' Penicillin ',
    );

    await tester.enterText(
      find.byKey(const Key('patient-health-profile-current-medications')),
      ' Medication A ',
    );

    await tester.enterText(
      find.byKey(const Key('patient-health-profile-previous-surgeries')),
      ' Appendectomy ',
    );

    final saveButton = find.byKey(const Key('patient-health-profile-save'));

    await revealWidget(tester, saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(submittedUpdate, isNotNull);
    expect(submittedUpdate!.chronicConditions, ['Asthma', 'Diabetes']);
    expect(submittedUpdate!.allergies, ['Penicillin']);
    expect(submittedUpdate!.currentMedications, ['Medication A']);
    expect(submittedUpdate!.previousSurgeries, ['Appendectomy']);
    expect(submittedUpdate!.smokingStatus, SmokingStatus.former);
    expect(submittedUpdate!.alcoholUse, AlcoholUse.never);
    expect(submittedUpdate!.pregnancyStatus, PregnancyStatus.notApplicable);

    expect(find.text('Health profile saved successfully.'), findsOneWidget);
  });

  testWidgets('rejects medical lists with more than 50 items', (tester) async {
    var updateCalled = false;

    await tester.pumpWidget(
      buildTestApp(
        profileLoader: () async => buildProfile(),
        profileUpdater: (update) async {
          updateCalled = true;
          return buildProfile();
        },
      ),
    );

    await tester.pumpAndSettle();

    final tooManyItems = List.generate(51, (index) => 'Item $index').join('\n');

    final chronicConditionsFinder = find.byKey(
      const Key('patient-health-profile-chronic-conditions'),
    );

    await tester.enterText(chronicConditionsFinder, tooManyItems);

    final saveButton = find.byKey(const Key('patient-health-profile-save'));

    await revealWidget(tester, saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    final chronicConditionsField = tester.widget<TextField>(
      chronicConditionsFinder,
    );

    expect(
      chronicConditionsField.decoration?.errorText,
      'A maximum of 50 items is allowed.',
    );
    expect(updateCalled, isFalse);
  });
}
