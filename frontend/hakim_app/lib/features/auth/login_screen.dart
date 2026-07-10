import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_screen.dart';
import 'data/auth_service.dart';
import 'data/google_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _usernameController = TextEditingController(
    text: 'patient1',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: 'Test12345!',
  );

  bool _isPasswordLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  bool get _isBusy => _isPasswordLoading || _isGoogleLoading;

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'أدخل اسم المستخدم وكلمة المرور.';
      });
      return;
    }

    setState(() {
      _isPasswordLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.login(username: username, password: password);

      _openChat();
    } on ApiException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('تعذر تسجيل الدخول. تأكد من تشغيل الخادم.');
    } finally {
      if (mounted) {
        setState(() {
          _isPasswordLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.loginWithGoogle();

      _openChat();
    } on GoogleAuthConfigurationException catch (e) {
      _setError(e.message);
    } on GoogleSignInException catch (e) {
      _setError(_googleErrorMessage(e));
    } on ApiException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError(
        'تعذر تسجيل الدخول باستخدام Google. تحقق من الاتصال وإعدادات الخادم.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  String _googleErrorMessage(GoogleSignInException exception) {
    return switch (exception.code) {
      GoogleSignInExceptionCode.canceled =>
        'تم إلغاء تسجيل الدخول باستخدام Google.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'إعداد Google غير صحيح. تحقق من package name وSHA-1 وWeb Client ID.',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'خدمة Google Sign-In غير متاحة أو غير مضبوطة على الجهاز.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'تعذر عرض نافذة اختيار حساب Google.',
      _ => 'فشل تسجيل الدخول باستخدام Google.',
    };
  }

  void _setError(String message) {
    if (!mounted) return;

    setState(() {
      _errorMessage = message;
    });
  }

  void _openChat() {
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('تسجيل دخول المريض')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(
                Icons.health_and_safety_rounded,
                size: 72,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'مرحباً بك في Hakim',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'سجّل الدخول حتى يتم حفظ محادثاتك وربطها بحسابك.',
                textAlign: TextAlign.center,
                style: TextStyle(
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
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                enabled: !_isBusy,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_isBusy) {
                    _login();
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.lock_rounded),
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
                    : const Text('تسجيل الدخول'),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'أو',
                      style: TextStyle(color: AppTheme.textLight),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
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
                label: const Text('المتابعة باستخدام Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
