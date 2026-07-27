import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakim_app/features/auth/authenticated_home.dart';

void main() {
  Widget buildTestApp({required String? role}) {
    return MaterialApp(
      home: AuthenticatedHome(
        roleLoader: () async => role,
        patientBuilder: (_) => const Text('patient-home'),
        doctorBuilder: (_) => const Text('doctor-home'),
        unsupportedBuilder: (_) => const Text('unsupported-home'),
      ),
    );
  }

  testWidgets('patient role opens patient destination', (tester) async {
    await tester.pumpWidget(buildTestApp(role: 'patient'));
    await tester.pumpAndSettle();

    expect(find.text('patient-home'), findsOneWidget);
    expect(find.text('doctor-home'), findsNothing);
  });

  testWidgets('doctor role opens doctor destination', (tester) async {
    await tester.pumpWidget(buildTestApp(role: 'doctor'));
    await tester.pumpAndSettle();

    expect(find.text('doctor-home'), findsOneWidget);
    expect(find.text('patient-home'), findsNothing);
  });

  testWidgets('admin role is blocked from mobile destinations', (tester) async {
    await tester.pumpWidget(buildTestApp(role: 'admin'));
    await tester.pumpAndSettle();

    expect(find.text('unsupported-home'), findsOneWidget);
    expect(find.text('patient-home'), findsNothing);
    expect(find.text('doctor-home'), findsNothing);
  });

  testWidgets('unknown role is handled safely', (tester) async {
    await tester.pumpWidget(buildTestApp(role: 'unexpected-role'));
    await tester.pumpAndSettle();

    expect(find.text('unsupported-home'), findsOneWidget);
  });
}
