import 'package:flutter/material.dart';

import '../auth/data/auth_service.dart';
import '../onboarding/welcome_screen.dart';
import 'data/doctor_profile.dart';
import 'data/doctor_profile_api.dart';
import 'doctor_home_screen.dart';

typedef DoctorProfileLoader = Future<DoctorProfile> Function();

typedef DoctorProfileWidgetBuilder =
    Widget Function(BuildContext context, DoctorProfile profile);

class DoctorFlowGate extends StatefulWidget {
  final AuthService? authService;
  final DoctorProfileLoader? profileLoader;
  final DoctorProfileWidgetBuilder? completedBuilder;
  final DoctorProfileWidgetBuilder? onboardingBuilder;

  const DoctorFlowGate({
    super.key,
    this.authService,
    this.profileLoader,
    this.completedBuilder,
    this.onboardingBuilder,
  });

  @override
  State<DoctorFlowGate> createState() => _DoctorFlowGateState();
}

class _DoctorFlowGateState extends State<DoctorFlowGate> {
  late final AuthService _authService;
  late final DoctorProfileLoader _profileLoader;
  late Future<DoctorProfile> _profileFuture;

  @override
  void initState() {
    super.initState();

    _authService = widget.authService ?? AuthService();

    _profileLoader =
        widget.profileLoader ??
        DoctorProfileApi(_authService.authenticatedApiClient).getProfile;

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
              _DoctorOnboardingPlaceholderScreen(authService: _authService);
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

class _DoctorOnboardingPlaceholderScreen extends StatefulWidget {
  final AuthService authService;

  const _DoctorOnboardingPlaceholderScreen({required this.authService});

  @override
  State<_DoctorOnboardingPlaceholderScreen> createState() =>
      _DoctorOnboardingPlaceholderScreenState();
}

class _DoctorOnboardingPlaceholderScreenState
    extends State<_DoctorOnboardingPlaceholderScreen> {
  bool _isLoggingOut = false;

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await widget.authService.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'تعذر تسجيل الخروج. حاول مرة أخرى.'
                : 'Unable to log out. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isArabic
        ? 'أكمل ملفك المهني'
        : 'Complete your professional profile';

    final description = _isArabic
        ? 'يجب إدخال بيانات الطبيب الأساسية والمهنية قبل الدخول إلى مساحة الطبيب.'
        : 'Your basic and professional information must be completed before entering the doctor area.';

    final temporaryNote = _isArabic
        ? 'سيتم إضافة نموذج استكمال الملف في الخطوة التالية.'
        : 'The profile completion form will be added in the next step.';

    final logoutLabel = _isArabic ? 'تسجيل الخروج' : 'Log out';

    return Scaffold(
      key: const Key('doctor-flow-onboarding-placeholder'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Hakim'),
        actions: [
          IconButton(
            tooltip: logoutLabel,
            onPressed: _isLoggingOut ? null : _logout,
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const Icon(Icons.badge_outlined, size: 72),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    temporaryNote,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
