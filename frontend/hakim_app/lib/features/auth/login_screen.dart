import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'authenticated_home.dart';
import 'auth_role.dart';
import 'data/auth_service.dart';
import 'data/google_auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthRole role;
  final AuthService? authService;

  const LoginScreen({
    super.key,
    this.role = AuthRole.patient,
    this.authService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _authService;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  bool get _isBusy => _isPasswordLoading || _isGoogleLoading;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = l10n.loginRequiredFields;
      });
      return;
    }

    setState(() {
      _isPasswordLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.login(username: username, password: password);
      _openAuthenticatedHome();
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError(l10n.loginServerError);
    } finally {
      if (mounted) {
        setState(() {
          _isPasswordLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.loginWithGoogle();
      _openAuthenticatedHome();
    } on GoogleAuthConfigurationException catch (error) {
      _setError(error.message);
    } on GoogleSignInException catch (error) {
      _setError(_googleErrorMessage(error, l10n));
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError(l10n.googleLoginServerError);
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  String _googleErrorMessage(
    GoogleSignInException exception,
    AppLocalizations l10n,
  ) {
    return switch (exception.code) {
      GoogleSignInExceptionCode.canceled => l10n.googleLoginCanceled,
      GoogleSignInExceptionCode.clientConfigurationError =>
        l10n.googleClientConfigurationError,
      GoogleSignInExceptionCode.providerConfigurationError =>
        l10n.googleProviderConfigurationError,
      GoogleSignInExceptionCode.uiUnavailable => l10n.googleUiUnavailable,
      _ => l10n.googleLoginFailed,
    };
  }

  void _setError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = message;
    });
  }

  void _openRegisterScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RegisterScreen(role: widget.role, authService: _authService),
      ),
    );
  }

  void _openAuthenticatedHome() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AuthenticatedHome(authService: _authService),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDoctor = widget.role == AuthRole.doctor;

    final title = isDoctor ? l10n.doctorLoginTitle : l10n.patientLoginTitle;

    final welcomeTitle = isDoctor
        ? l10n.doctorLoginWelcome
        : l10n.patientLoginWelcome;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Icon(
                    isDoctor
                        ? Icons.medical_services_rounded
                        : Icons.health_and_safety_rounded,
                    size: 72,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    welcomeTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.loginDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _usernameController,
                    enabled: !_isBusy,
                    textInputAction: TextInputAction.next,
                    textAlign: TextAlign.start,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(
                      labelText: l10n.usernameLabel,
                      prefixIcon: const Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    enabled: !_isBusy,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.start,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) {
                      if (!_isBusy) {
                        _login();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      prefixIcon: const Icon(Icons.lock_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: _isBusy ? null : _login,
                    child: _isPasswordLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.loginButton),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.noAccountQuestion,
                        style: const TextStyle(color: AppTheme.textLight),
                      ),
                      TextButton(
                        key: const Key('login_create_account_button'),
                        onPressed: _isBusy ? null : _openRegisterScreen,
                        child: Text(l10n.createAccount),
                      ),
                    ],
                  ),
                  if (!isDoctor) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            l10n.orLabel,
                            style: const TextStyle(color: AppTheme.textLight),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      key: const Key('login_google_button'),
                      onPressed: _isBusy ? null : _loginWithGoogle,
                      icon: _isGoogleLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'G',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      label: Text(l10n.continueWithGoogle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
