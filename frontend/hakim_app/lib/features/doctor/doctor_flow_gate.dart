import 'package:flutter/material.dart';

import '../auth/data/auth_service.dart';
import 'data/doctor_profile.dart';
import 'data/doctor_profile_api.dart';
import 'doctor_home_screen.dart';
import 'doctor_onboarding_screen.dart';

typedef DoctorProfileLoader = Future<DoctorProfile> Function();

typedef DoctorProfileWidgetBuilder =
    Widget Function(BuildContext context, DoctorProfile profile);

class DoctorFlowGate extends StatefulWidget {
  final AuthService? authService;
  final DoctorProfileLoader? profileLoader;
  final SpecialtyListLoader? specialtiesLoader;
  final DoctorProfileUpdater? profileUpdater;
  final DoctorProfileWidgetBuilder? completedBuilder;
  final DoctorProfileWidgetBuilder? onboardingBuilder;

  const DoctorFlowGate({
    super.key,
    this.authService,
    this.profileLoader,
    this.specialtiesLoader,
    this.profileUpdater,
    this.completedBuilder,
    this.onboardingBuilder,
  });

  @override
  State<DoctorFlowGate> createState() => _DoctorFlowGateState();
}

class _DoctorFlowGateState extends State<DoctorFlowGate> {
  late final AuthService _authService;
  late final DoctorProfileApi _profileApi;
  late final DoctorProfileLoader _profileLoader;

  late Future<DoctorProfile> _profileFuture;

  @override
  void initState() {
    super.initState();

    _authService = widget.authService ?? AuthService();

    _profileApi = DoctorProfileApi(_authService.authenticatedApiClient);

    _profileLoader = widget.profileLoader ?? _profileApi.getProfile;

    _profileFuture = _profileLoader();
  }

  void _retry() {
    setState(() {
      _profileFuture = _profileLoader();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DoctorProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              key: Key('doctor-flow-loading'),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _DoctorFlowErrorScreen(onRetry: _retry);
        }

        final profile = snapshot.requireData;

        if (!profile.isProfileComplete) {
          return widget.onboardingBuilder?.call(context, profile) ??
              DoctorOnboardingScreen(
                profile: profile,
                specialtiesLoader:
                    widget.specialtiesLoader ?? _profileApi.getSpecialties,
                profileUpdater:
                    widget.profileUpdater ?? _profileApi.updateProfile,
                onCompleted: _retry,
                authService: _authService,
              );
        }

        return widget.completedBuilder?.call(context, profile) ??
            DoctorHomeScreen(authService: _authService);
      },
    );
  }
}

class _DoctorFlowErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _DoctorFlowErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    final message = isArabic
        ? 'تعذر تحميل ملف الطبيب. تحقق من الاتصال وحاول مرة أخرى.'
        : 'Unable to load the doctor profile. Check your connection and try again.';

    final retryLabel = isArabic ? 'إعادة المحاولة' : 'Try again';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const Key('doctor-flow-error'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 120),
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),
            Center(
              child: FilledButton.icon(
                key: const Key('doctor-flow-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
