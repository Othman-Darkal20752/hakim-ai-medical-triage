import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/core/network/api_client.dart';
import 'package:hakim_app/features/doctor/data/doctor_profile.dart';
import 'package:hakim_app/features/doctor/doctor_flow_gate.dart';

void main() {
  DoctorProfile buildProfile({required bool isComplete}) {
    return DoctorProfile.fromJson({'id': 1, 'is_profile_complete': isComplete});
  }

  Widget buildTestApp({
    required Future<DoctorProfile> Function() profileLoader,
    Widget Function(BuildContext, DoctorProfile)? completedBuilder,
  }) {
    return MaterialApp(
      home: DoctorFlowGate(
        profileLoader: profileLoader,
        completedBuilder: completedBuilder,
      ),
    );
  }

  testWidgets('shows loading while doctor profile is being loaded', (
    tester,
  ) async {
    final completer = Completer<DoctorProfile>();

    await tester.pumpWidget(
      buildTestApp(profileLoader: () => completer.future),
    );

    expect(find.byKey(const Key('doctor-flow-loading')), findsOneWidget);
  });

  testWidgets('shows onboarding placeholder when profile is incomplete', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(profileLoader: () async => buildProfile(isComplete: false)),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('doctor-flow-onboarding-placeholder')),
      findsOneWidget,
    );
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
    expect(
      find.byKey(const Key('doctor-flow-onboarding-placeholder')),
      findsNothing,
    );
  });

  testWidgets('retry loads the doctor profile again after an error', (
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
    expect(find.byKey(const Key('doctor-flow-error')), findsNothing);
  });
}
