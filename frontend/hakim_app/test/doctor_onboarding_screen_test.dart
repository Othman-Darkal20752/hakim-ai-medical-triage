import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/features/doctor/data/doctor_profile.dart';
import 'package:hakim_app/features/doctor/data/doctor_profile_update.dart';
import 'package:hakim_app/features/doctor/data/specialty.dart';
import 'package:hakim_app/features/doctor/doctor_onboarding_screen.dart';
import 'package:hakim_app/l10n/generated/app_localizations.dart';

void main() {
  const specialty = Specialty(
    id: 1,
    code: 'cardiology',
    nameAr: '\u0642\u0644\u0628\u064a\u0629',
    nameEn: 'Cardiology',
    descriptionAr: '',
    descriptionEn: '',
  );

  DoctorProfile buildProfile({bool validValues = false}) {
    return DoctorProfile.fromJson({
      'id': 10,
      'is_profile_complete': false,
      'specialty': validValues
          ? {
              'id': 1,
              'code': 'cardiology',
              'name_ar': '\u0642\u0644\u0628\u064a\u0629',
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
    required DoctorProfile profile,
    required Future<List<Specialty>> Function() specialtiesLoader,
    required Future<DoctorProfile> Function(DoctorProfileUpdate update)
    profileUpdater,
    VoidCallback? onCompleted,
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
      home: DoctorOnboardingScreen(
        profile: profile,
        specialtiesLoader: specialtiesLoader,
        profileUpdater: profileUpdater,
        onCompleted: onCompleted ?? () {},
      ),
    );
  }

  Future<void> revealWidget(
    WidgetTester tester,
    Finder target, {
    required Offset moveStep,
  }) async {
    await tester.dragUntilVisible(
      target,
      find.byKey(const Key('doctor-onboarding-form')),
      moveStep,
    );

    await tester.pumpAndSettle();
  }

  Future<void> expectTextFieldError(
    WidgetTester tester, {
    required String keyName,
    required String expectedError,
  }) async {
    final finder = find.byKey(Key(keyName));

    await revealWidget(tester, finder, moveStep: const Offset(0, 500));

    final textField = tester.widget<TextField>(finder);

    expect(textField.decoration?.errorText, expectedError);
  }

  testWidgets('shows loading while specialties are being loaded', (
    tester,
  ) async {
    final completer = Completer<List<Specialty>>();

    await tester.pumpWidget(
      buildTestApp(
        profile: buildProfile(),
        specialtiesLoader: () => completer.future,
        profileUpdater: (_) async => buildProfile(),
      ),
    );

    expect(
      find.byKey(const Key('doctor-onboarding-specialties-loading')),
      findsOneWidget,
    );
  });

  testWidgets('retries loading specialties after an error', (tester) async {
    var callCount = 0;

    Future<List<Specialty>> loadSpecialties() async {
      callCount++;

      if (callCount == 1) {
        throw const ApiException('temporary failure', statusCode: 500);
      }

      return const [specialty];
    }

    await tester.pumpWidget(
      buildTestApp(
        profile: buildProfile(),
        specialtiesLoader: loadSpecialties,
        profileUpdater: (_) async => buildProfile(),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('doctor-onboarding-specialties-error')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('doctor-onboarding-specialties-retry')),
    );

    await tester.pumpAndSettle();

    expect(callCount, 2);

    expect(find.byKey(const Key('doctor-onboarding-form')), findsOneWidget);
  });

  testWidgets('validates required professional fields', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        profile: buildProfile(),
        specialtiesLoader: () async => const [specialty],
        profileUpdater: (_) async => buildProfile(),
      ),
    );

    await tester.pumpAndSettle();

    final saveButton = find.byKey(const Key('doctor-onboarding-save'));

    await revealWidget(tester, saveButton, moveStep: const Offset(0, -500));

    await tester.tap(saveButton);
    await tester.pump();

    await expectTextFieldError(
      tester,
      keyName: 'doctor-onboarding-address',
      expectedError: 'This field is required.',
    );

    await expectTextFieldError(
      tester,
      keyName: 'doctor-onboarding-city',
      expectedError: 'This field is required.',
    );

    await expectTextFieldError(
      tester,
      keyName: 'doctor-onboarding-phone',
      expectedError: 'This field is required.',
    );

    await expectTextFieldError(
      tester,
      keyName: 'doctor-onboarding-license',
      expectedError: 'This field is required.',
    );

    await expectTextFieldError(
      tester,
      keyName: 'doctor-onboarding-display-name',
      expectedError: 'This field is required.',
    );

    final specialtyFinder = find.byKey(
      const Key('doctor-onboarding-specialty'),
    );

    await revealWidget(tester, specialtyFinder, moveStep: const Offset(0, 500));

    final specialtyField = tester.widget<DropdownButtonFormField<int>>(
      specialtyFinder,
    );

    expect(specialtyField.decoration.errorText, 'Select a medical specialty.');
  });

  testWidgets('submits the allowed doctor profile fields', (tester) async {
    DoctorProfileUpdate? submittedUpdate;
    var completed = false;

    await tester.pumpWidget(
      buildTestApp(
        profile: buildProfile(validValues: true),
        specialtiesLoader: () async => const [specialty],
        profileUpdater: (update) async {
          submittedUpdate = update;
          return buildProfile(validValues: true);
        },
        onCompleted: () {
          completed = true;
        },
      ),
    );

    await tester.pumpAndSettle();

    final saveButton = find.byKey(const Key('doctor-onboarding-save'));

    await revealWidget(tester, saveButton, moveStep: const Offset(0, -500));

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(submittedUpdate, isNotNull);
    expect(submittedUpdate!.displayName, 'Dr. Test');
    expect(submittedUpdate!.specialtyId, 1);
    expect(submittedUpdate!.medicalLicenseNumber, 'LIC-100');
    expect(submittedUpdate!.phoneNumber, '0500000000');
    expect(submittedUpdate!.city, 'Jeddah');
    expect(submittedUpdate!.address, 'Clinic address');
    expect(completed, isTrue);
  });

  testWidgets('shows backend validation error under its field', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        profile: buildProfile(validValues: true),
        specialtiesLoader: () async => const [specialty],
        profileUpdater: (_) async {
          throw const ApiException(
            'License already exists.',
            statusCode: 400,
            fieldErrors: {
              'medical_license_number': ['License already exists.'],
            },
          );
        },
      ),
    );

    await tester.pumpAndSettle();

    final saveButton = find.byKey(const Key('doctor-onboarding-save'));

    await revealWidget(tester, saveButton, moveStep: const Offset(0, -500));

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final licenseFinder = find.byKey(const Key('doctor-onboarding-license'));

    await revealWidget(tester, licenseFinder, moveStep: const Offset(0, 500));

    final licenseField = tester.widget<TextField>(licenseFinder);

    expect(licenseField.decoration?.errorText, 'License already exists.');
  });
}
