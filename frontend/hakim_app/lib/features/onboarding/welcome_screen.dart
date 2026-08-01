import 'package:flutter/material.dart';

import '../../core/localization/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_role.dart';
import '../auth/login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  AuthRole? _selectedRole;

  void _selectRole(AuthRole role) {
    if (_selectedRole == role) {
      return;
    }

    setState(() {
      _selectedRole = role;
    });
  }

  void _continue() {
    final selectedRole = _selectedRole;

    if (selectedRole == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LoginScreen(role: selectedRole)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                compact ? 14 : 20,
                24,
                compact ? 16 : 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        isArabic: isArabic,
                        onLanguagePressed: () async {
                          await LocaleController.instance.toggleLocale();
                        },
                      ),

                      SizedBox(height: compact ? 24 : 38),

                      Center(child: _OfficialLogo(size: compact ? 112 : 132)),

                      SizedBox(height: compact ? 20 : 28),

                      Text(
                        isArabic
                            ? 'إرشاد طبي أولي'
                            : 'PRELIMINARY MEDICAL GUIDANCE',
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: const Color(0xFFAEE5D9),
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          letterSpacing: isArabic ? 0 : 1.4,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        l10n.appTagline,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 27 : 30,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        l10n.welcomeDisclaimer,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 14,
                          height: 1.75,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      SizedBox(height: compact ? 22 : 30),

                      Text(
                        l10n.roleQuestion,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              icon: Icons.person_rounded,
                              label: l10n.patient,
                              selected: _selectedRole == AuthRole.patient,
                              onPressed: () {
                                _selectRole(AuthRole.patient);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RoleCard(
                              icon: Icons.medical_services_rounded,
                              label: l10n.doctor,
                              selected: _selectedRole == AuthRole.doctor,
                              onPressed: () {
                                _selectRole(AuthRole.doctor);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      FilledButton(
                        onPressed: _selectedRole == null
                            ? null
                            : () {
                                _continue();
                              },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.12,
                          ),
                          disabledForegroundColor: Colors.white.withValues(
                            alpha: 0.38,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.getStarted,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isArabic
                                  ? Icons.arrow_back_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 19,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.42),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              l10n.welcomePrivacy,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.46),
                                fontSize: 11,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isArabic;
  final VoidCallback onLanguagePressed;

  const _TopBar({required this.isArabic, required this.onLanguagePressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Hakim',
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const Spacer(),
        Material(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onLanguagePressed,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.language_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isArabic ? 'EN' : 'ع',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfficialLogo extends StatelessWidget {
  final double size;

  const _OfficialLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: Transform.scale(
          scale: 1.5,
          child: Image.asset(
            'assets/branding/hakim_icon_foreground.png',
            fit: BoxFit.contain,
            semanticLabel: 'Hakim official logo',
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppTheme.primaryDark : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 96,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF76D6C6)
              : Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF76D6C6)
                : Colors.white.withValues(alpha: 0.14),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF76D6C6).withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 25, color: foreground),
                      const SizedBox(height: 9),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 17,
                      color: AppTheme.primaryDark,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
