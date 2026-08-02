import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'authenticated_home.dart';
import 'auth_role.dart';
import 'data/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final AuthRole role;
  final AuthService? authService;

  const RegisterScreen({super.key, required this.role, this.authService});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final AuthService _authService;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _passwordConfirmError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  bool _validate() {
    final l10n = AppLocalizations.of(context);

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    String? usernameError;
    String? emailError;
    String? passwordError;
    String? passwordConfirmError;

    if (username.isEmpty) {
      usernameError = l10n.usernameRequired;
    } else if (username.length > 150) {
      usernameError = l10n.usernameTooLong;
    }

    if (email.isNotEmpty && !_isValidEmail(email)) {
      emailError = l10n.emailInvalid;
    }

    if (password.isEmpty) {
      passwordError = l10n.passwordRequired;
    } else if (password.length < 8) {
      passwordError = l10n.passwordTooShort;
    }

    if (passwordConfirm.isEmpty) {
      passwordConfirmError = l10n.passwordConfirmRequired;
    } else if (passwordConfirm != password) {
      passwordConfirmError = l10n.passwordMismatch;
    }

    setState(() {
      _usernameError = usernameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _passwordConfirmError = passwordConfirmError;
      _generalError = null;
    });

    return usernameError == null &&
        emailError == null &&
        passwordError == null &&
        passwordConfirmError == null;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  Future<void> _register() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    try {
      await _authService.register(
        username: username,
        email: email.isEmpty ? null : email,
        password: _passwordController.text,
        passwordConfirm: _passwordConfirmController.text,
        role: widget.role.apiValue,
      );

      _openAuthenticatedHome();
    } on ApiException catch (error) {
      _applyApiError(error);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _generalError = AppLocalizations.of(context).registerServerError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyApiError(ApiException error) {
    if (!mounted) {
      return;
    }

    final usernameError = _joinedErrors(error, 'username');
    final emailError = _joinedErrors(error, 'email');
    final passwordError = _joinedErrors(error, 'password');
    final passwordConfirmError = _joinedErrors(error, 'password_confirm');

    final displayedFieldMessages = <String>[
      ...error.errorsFor('username'),
      ...error.errorsFor('email'),
      ...error.errorsFor('password'),
      ...error.errorsFor('password_confirm'),
    ].map((message) => message.trim()).where((message) => message.isNotEmpty);

    final apiMessage = error.message.trim();
    final generalError =
        apiMessage.isNotEmpty && !displayedFieldMessages.contains(apiMessage)
        ? apiMessage
        : null;

    setState(() {
      _usernameError = usernameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _passwordConfirmError = passwordConfirmError;
      _generalError = generalError;
    });
  }

  String? _joinedErrors(ApiException error, String fieldName) {
    final errors = error.errorsFor(fieldName);

    if (errors.isEmpty) {
      return null;
    }

    return errors.join('\n');
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

  void _clearUsernameError() {
    if (_usernameError == null && _generalError == null) {
      return;
    }

    setState(() {
      _usernameError = null;
      _generalError = null;
    });
  }

  void _clearEmailError() {
    if (_emailError == null && _generalError == null) {
      return;
    }

    setState(() {
      _emailError = null;
      _generalError = null;
    });
  }

  void _clearPasswordError() {
    if (_passwordError == null &&
        _passwordConfirmError == null &&
        _generalError == null) {
      return;
    }

    setState(() {
      _passwordError = null;
      _passwordConfirmError = null;
      _generalError = null;
    });
  }

  void _clearPasswordConfirmError() {
    if (_passwordConfirmError == null && _generalError == null) {
      return;
    }

    setState(() {
      _passwordConfirmError = null;
      _generalError = null;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDoctor = widget.role == AuthRole.doctor;

    final title = isDoctor
        ? l10n.doctorRegisterTitle
        : l10n.patientRegisterTitle;

    final welcomeTitle = isDoctor
        ? l10n.doctorRegisterWelcome
        : l10n.patientRegisterWelcome;

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
                  const SizedBox(height: 24),
                  Icon(
                    isDoctor
                        ? Icons.medical_services_rounded
                        : Icons.person_add_alt_1_rounded,
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
                    l10n.registerDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    key: const Key('register_username_field'),
                    controller: _usernameController,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.next,
                    textAlign: TextAlign.start,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.newUsername],
                    onChanged: (_) => _clearUsernameError(),
                    decoration: InputDecoration(
                      labelText: l10n.usernameLabel,
                      prefixIcon: const Icon(Icons.person_rounded),
                      errorText: _usernameError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('register_email_field'),
                    controller: _emailController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    textAlign: TextAlign.start,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) => _clearEmailError(),
                    decoration: InputDecoration(
                      labelText: l10n.emailOptionalLabel,
                      prefixIcon: const Icon(Icons.email_rounded),
                      errorText: _emailError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('register_password_field'),
                    controller: _passwordController,
                    enabled: !_isLoading,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    textAlign: TextAlign.start,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) => _clearPasswordError(),
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      prefixIcon: const Icon(Icons.lock_rounded),
                      errorText: _passwordError,
                      suffixIcon: IconButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('register_password_confirm_field'),
                    controller: _passwordConfirmController,
                    enabled: !_isLoading,
                    obscureText: _obscurePasswordConfirm,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.start,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) => _clearPasswordConfirmError(),
                    onSubmitted: (_) {
                      if (!_isLoading) {
                        _register();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: l10n.passwordConfirmLabel,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      errorText: _passwordConfirmError,
                      suffixIcon: IconButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _obscurePasswordConfirm =
                                      !_obscurePasswordConfirm;
                                });
                              },
                        icon: Icon(
                          _obscurePasswordConfirm
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_generalError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        _generalError!,
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
                    key: const Key('register_submit_button'),
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.registerButton),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.alreadyHaveAccountQuestion,
                        style: const TextStyle(color: AppTheme.textLight),
                      ),
                      TextButton(
                        key: const Key('register_sign_in_button'),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.signInInstead),
                      ),
                    ],
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
