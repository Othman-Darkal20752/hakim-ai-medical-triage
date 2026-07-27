import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../doctor/doctor_home_screen.dart';
import '../onboarding/welcome_screen.dart';
import 'data/auth_service.dart';

class AuthenticatedHome extends StatefulWidget {
  final AuthService? authService;
  final Future<String?> Function()? roleLoader;
  final WidgetBuilder? patientBuilder;
  final WidgetBuilder? doctorBuilder;
  final WidgetBuilder? unsupportedBuilder;

  const AuthenticatedHome({
    super.key,
    this.authService,
    this.roleLoader,
    this.patientBuilder,
    this.doctorBuilder,
    this.unsupportedBuilder,
  });

  @override
  State<AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<AuthenticatedHome> {
  late final AuthService _authService;
  late final Future<String?> _roleFuture;

  @override
  void initState() {
    super.initState();

    _authService = widget.authService ?? AuthService();
    _roleFuture = (widget.roleLoader ?? _authService.getRole)();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = snapshot.data?.trim().toLowerCase();

        return switch (role) {
          'patient' =>
            widget.patientBuilder?.call(context) ?? const ChatScreen(),
          'doctor' =>
            widget.doctorBuilder?.call(context) ??
                DoctorHomeScreen(authService: _authService),
          _ =>
            widget.unsupportedBuilder?.call(context) ??
                _UnsupportedMobileRoleScreen(authService: _authService),
        };
      },
    );
  }
}

class _UnsupportedMobileRoleScreen extends StatefulWidget {
  final AuthService authService;

  const _UnsupportedMobileRoleScreen({required this.authService});

  @override
  State<_UnsupportedMobileRoleScreen> createState() =>
      _UnsupportedMobileRoleScreenState();
}

class _UnsupportedMobileRoleScreenState
    extends State<_UnsupportedMobileRoleScreen> {
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
        ? 'هذا الحساب غير متاح في تطبيق الموبايل'
        : 'This account is not available in the mobile app';

    final description = _isArabic
        ? 'لوحة الإدارة تعمل كتطبيق ويب مستقل. سجّل الدخول بحساب مريض أو طبيب لاستخدام تطبيق Hakim.'
        : 'The administration dashboard is a separate web application. Sign in with a patient or doctor account to use Hakim.';

    final logoutLabel = _isArabic ? 'تسجيل الخروج' : 'Log out';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Hakim'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 72),
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
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _isLoggingOut ? null : _logout,
                    icon: _isLoggingOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(logoutLabel),
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
