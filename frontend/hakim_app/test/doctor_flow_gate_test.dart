import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/features/doctor/data/doctor_profile.dart';
import 'package:hakim_app/features/doctor/data/doctor_profile_update.dart';
import 'package:hakim_app/features/doctor/data/specialty.dart';
import 'package:hakim_app/features/doctor/doctor_flow_gate.dart';
import 'package:hakim_app/l10n/generated/app_localizations.dart';

void main() {
  const specialty = Specialty(
    id: 1,
    code: 'cardiology',
    nameAr: 'قلبية',
    nameEn: 'Cardiology',
    descriptionAr: '',
    descriptionEn: '',
  );

  DoctorProfile buildProfile({
    required bool isComplete,
    bool validValues = false,
  }) {
    return DoctorProfile.fromJson({
      'id': 1,
      'is_profile_complete': isComplete,
      'specialty': validValues
          ? {
              'id': 1,
              'code': 'cardiology',
              'name_ar': 'قلبية',
              'name_en': 'Cardiology',
              'description_ar': '',
              'description_en': '',
            }
          : null,
      'display_name': validValues ? 'Dr. Test' : '',
      'medical_license_number': validValues ? 'LIC-100' : null,
      'phone_number': validValues ? '0500000000' : '',
      'city': validValues ? 'Jeddah' : '',
      'address': validValues ? 'Clinic address' : '',
    });
  }

  Widget buildTestApp({
    required Future<DoctorProfile> Function() profileLoader,
    Future<List<Specialty>> Function()? specialtiesLoader,
    Future<DoctorProfile> Function(DoctorProfileUpdate update)? profileUpdater,
    Widget Function(BuildContext context, DoctorProfile profile)?
    completedBuilder,
    Widget Function(BuildContext context, DoctorProfile profile)?
    onboardingBuilder,
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
      home: DoctorFlowGate(
        profileLoader: profileLoader,
        specialtiesLoader: specialtiesLoader,
        profileUpdater: profileUpdater,
        completedBuilder: completedBuilder,
        onboardingBuilder: onboardingBuilder,
      ),
    );
  }

  testWidgets('shows loading while doctor profile is loading', (tester) async {
    final completer = Completer<DoctorProfile>();

    await tester.pumpWidget(
      buildTestApp(profileLoader: () => completer.future),
    );

    expect(find.byKey(const Key('doctor-flow-loading')), findsOneWidget);
  });

  testWidgets('opens doctor onboarding when profile is incomplete', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        profileLoader: () async => buildProfile(isComplete: false),
        specialtiesLoader: () async => const [specialty],
        profileUpdater: (_) async =>
            buildProfile(isComplete: true, validValues: true),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('doctor-onboarding-form')), findsOneWidget);

    expect(find.text('doctor-home'), findsNothing);
  });

  testWidgets('opens doctor home when profile is complete', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        profileLoader: () async => buildProfile(isComplete: true),
        completedBuilder: (_, _) => const Text('doctor-home'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('doctor-home'), findsOneWidget);

    expect(find.byKey(const Key('doctor-onboarding-form')), findsNothing);
  });

  testWidgets('retry loads doctor profile again after an error', (
    tester,
  ) async {
    var callCount = 0;

    Future<DoctorProfile> loadProfile() async {
      callCount++;

      if (callCount == 1) {
        throw const ApiException('temporary failure', statusCode: 500);
      }

      return buildProfile(isComplete: true);
    }

    await tester.pumpWidget(
      buildTestApp(
        profileLoader: loadProfile,
        completedBuilder: (_, _) => const Text('doctor-home'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('doctor-flow-error')), findsOneWidget);

    expect(callCount, 1);

    await tester.tap(find.byKey(const Key('doctor-flow-retry')));

    await tester.pumpAndSettle();

    expect(callCount, 2);

    expect(find.text('doctor-home'), findsOneWidget);
  });

  testWidgets('successful onboarding reloads profile and opens doctor home', (
    tester,
  ) async {
    var profileLoadCount = 0;
    var updateCount = 0;

    Future<DoctorProfile> loadProfile() async {
      profileLoadCount++;

      if (profileLoadCount == 1) {
        return buildProfile(isComplete: false, validValues: true);
      }

      return buildProfile(isComplete: true, validValues: true);
    }

    await tester.pumpWidget(
      buildTestApp(
        profileLoader: loadProfile,
        specialtiesLoader: () async => const [specialty],
        profileUpdater: (update) async {
          updateCount++;

          return buildProfile(isComplete: true, validValues: true);
        },
        completedBuilder: (_, _) => const Text('doctor-home'),
      ),
    );

    await tester.pumpAndSettle();

    final saveButton = find.byKey(const Key('doctor-onboarding-save'));

    await tester.dragUntilVisible(
      saveButton,
      find.byKey(const Key('doctor-onboarding-form')),
      const Offset(0, -500),
    );

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(updateCount, 1);
    expect(profileLoadCount, 2);

    expect(find.text('doctor-home'), findsOneWidget);
  });
}
