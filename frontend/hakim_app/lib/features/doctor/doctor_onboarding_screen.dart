import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/data/auth_service.dart';
import '../onboarding/welcome_screen.dart';
import 'data/doctor_profile.dart';
import 'data/doctor_profile_update.dart';
import 'data/specialty.dart';

typedef SpecialtyListLoader = Future<List<Specialty>> Function();

typedef DoctorProfileUpdater =
    Future<DoctorProfile> Function(DoctorProfileUpdate update);

class DoctorOnboardingScreen extends StatefulWidget {
  final DoctorProfile profile;
  final SpecialtyListLoader specialtiesLoader;
  final DoctorProfileUpdater profileUpdater;
  final VoidCallback onCompleted;
  final AuthService? authService;

  const DoctorOnboardingScreen({
    super.key,
    required this.profile,
    required this.specialtiesLoader,
    required this.profileUpdater,
    required this.onCompleted,
    this.authService,
  });

  @override
  State<DoctorOnboardingScreen> createState() => _DoctorOnboardingScreenState();
}

class _DoctorOnboardingScreenState extends State<DoctorOnboardingScreen> {
  late final AuthService _authService;

  late final TextEditingController _displayNameController;
  late final TextEditingController _licenseController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _bioController;
  late final TextEditingController _experienceController;
  late final TextEditingController _workingHoursController;

  late Future<List<Specialty>> _specialtiesFuture;

  final Map<String, String> _fieldErrors = {};

  int? _selectedSpecialtyId;
  String? _generalError;

  bool _isSaving = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();

    _authService = widget.authService ?? AuthService();

    final profile = widget.profile;

    _displayNameController = TextEditingController(text: profile.displayName);
    _licenseController = TextEditingController(
      text: profile.medicalLicenseNumber ?? '',
    );
    _phoneController = TextEditingController(text: profile.phoneNumber);
    _whatsappController = TextEditingController(text: profile.whatsappNumber);
    _cityController = TextEditingController(text: profile.city);
    _addressController = TextEditingController(text: profile.address);
    _bioController = TextEditingController(text: profile.bio);
    _experienceController = TextEditingController(
      text: profile.yearsOfExperience?.toString() ?? '',
    );
    _workingHoursController = TextEditingController(text: profile.workingHours);

    _selectedSpecialtyId = profile.specialty?.id;
    _specialtiesFuture = widget.specialtiesLoader();
  }

  void _retrySpecialties() {
    setState(() {
      _specialtiesFuture = widget.specialtiesLoader();
    });
  }

  bool _validate() {
    final l10n = AppLocalizations.of(context);
    final errors = <String, String>{};

    void requireField(String fieldName, TextEditingController controller) {
      if (controller.text.trim().isEmpty) {
        errors[fieldName] = l10n.requiredField;
      }
    }

    requireField('display_name', _displayNameController);
    requireField('medical_license_number', _licenseController);
    requireField('phone_number', _phoneController);
    requireField('city', _cityController);
    requireField('address', _addressController);

    if (_selectedSpecialtyId == null) {
      errors['specialty_id'] = l10n.specialtyRequired;
    }

    final experienceText = _experienceController.text.trim();

    if (experienceText.isNotEmpty) {
      final experience = int.tryParse(experienceText);

      if (experience == null || experience < 0) {
        errors['years_of_experience'] = l10n.yearsOfExperienceInvalid;
      }
    }

    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);

      _generalError = null;
    });

    return errors.isEmpty;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _generalError = null;
    });

    final experienceText = _experienceController.text.trim();

    final update = DoctorProfileUpdate(
      displayName: _displayNameController.text.trim(),
      specialtyId: _selectedSpecialtyId!,
      medicalLicenseNumber: _licenseController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      whatsappNumber: _whatsappController.text.trim(),
      city: _cityController.text.trim(),
      address: _addressController.text.trim(),
      bio: _bioController.text.trim(),
      yearsOfExperience: experienceText.isEmpty
          ? null
          : int.parse(experienceText),
      workingHours: _workingHoursController.text.trim(),
    );

    try {
      await widget.profileUpdater(update);

      if (!mounted) {
        return;
      }

      widget.onCompleted();
    } on ApiException catch (error) {
      _applyApiError(error);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _generalError = AppLocalizations.of(context).doctorProfileSaveError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _applyApiError(ApiException error) {
    if (!mounted) {
      return;
    }

    const supportedFields = [
      'display_name',
      'specialty_id',
      'medical_license_number',
      'phone_number',
      'whatsapp_number',
      'city',
      'address',
      'bio',
      'years_of_experience',
      'working_hours',
    ];

    final errors = <String, String>{};
    final displayedMessages = <String>{};

    for (final fieldName in supportedFields) {
      final messages = error.errorsFor(fieldName);

      if (messages.isEmpty) {
        continue;
      }

      errors[fieldName] = messages.join('\n');

      displayedMessages.addAll(
        messages
            .map((message) => message.trim())
            .where((message) => message.isNotEmpty),
      );
    }

    final apiMessage = error.message.trim();

    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);

      _generalError =
          apiMessage.isNotEmpty && !displayedMessages.contains(apiMessage)
          ? apiMessage
          : null;
    });
  }

  void _clearError(String fieldName) {
    if (!_fieldErrors.containsKey(fieldName) && _generalError == null) {
      return;
    }

    setState(() {
      _fieldErrors.remove(fieldName);
      _generalError = null;
    });
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).logoutError)),
      );
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _licenseController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _workingHoursController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.doctorProfileSetupTitle),
        actions: [
          IconButton(
            tooltip: l10n.logoutButton,
            onPressed: _isSaving || _isLoggingOut ? null : _logout,
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
        child: FutureBuilder<List<Specialty>>(
          future: _specialtiesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                key: Key('doctor-onboarding-specialties-loading'),
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return _buildSpecialtiesState(
                key: const Key('doctor-onboarding-specialties-error'),
                icon: Icons.error_outline_rounded,
                message: l10n.specialtiesLoadError,
              );
            }

            final specialties = List<Specialty>.of(snapshot.data ?? const []);

            final currentSpecialty = widget.profile.specialty;

            if (currentSpecialty != null &&
                !specialties.any(
                  (specialty) => specialty.id == currentSpecialty.id,
                )) {
              specialties.insert(0, currentSpecialty);
            }

            if (specialties.isEmpty) {
              return _buildSpecialtiesState(
                key: const Key('doctor-onboarding-specialties-empty'),
                icon: Icons.medical_information_outlined,
                message: l10n.specialtiesEmpty,
              );
            }

            return _buildForm(specialties);
          },
        ),
      ),
    );
  }

  Widget _buildSpecialtiesState({
    required Key key,
    required IconData icon,
    required String message,
  }) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      key: key,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 64, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            key: const Key('doctor-onboarding-specialties-retry'),
            onPressed: _retrySpecialties,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retryButton),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(List<Specialty> specialties) {
    final l10n = AppLocalizations.of(context);

    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    return ListView(
      key: const Key('doctor-onboarding-form'),
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.badge_outlined, size: 72, color: AppTheme.primary),
        const SizedBox(height: 20),
        Text(
          l10n.doctorProfileSetupTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.doctorProfileSetupDescription,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppTheme.textLight,
          ),
        ),
        const SizedBox(height: 28),
        _buildTextField(
          key: const Key('doctor-onboarding-display-name'),
          controller: _displayNameController,
          fieldName: 'display_name',
          label: l10n.displayNameLabel,
          icon: Icons.person_rounded,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: const Key('doctor-onboarding-specialty'),
          initialValue: _selectedSpecialtyId,
          isExpanded: true,
          items: specialties
              .map(
                (specialty) => DropdownMenuItem<int>(
                  value: specialty.id,
                  child: Text(
                    isArabic ? specialty.nameAr : specialty.nameEn,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: _isSaving
              ? null
              : (value) {
                  setState(() {
                    _selectedSpecialtyId = value;
                    _fieldErrors.remove('specialty_id');
                    _generalError = null;
                  });
                },
          decoration: InputDecoration(
            labelText: l10n.specialtyLabel,
            prefixIcon: const Icon(Icons.medical_services_rounded),
            errorText: _fieldErrors['specialty_id'],
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          key: const Key('doctor-onboarding-license'),
          controller: _licenseController,
          fieldName: 'medical_license_number',
          label: l10n.medicalLicenseNumberLabel,
          icon: Icons.verified_user_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          key: const Key('doctor-onboarding-phone'),
          controller: _phoneController,
          fieldName: 'phone_number',
          label: l10n.phoneNumberLabel,
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          key: const Key('doctor-onboarding-whatsapp'),
          controller: _whatsappController,
          fieldName: 'whatsapp_number',
          label: l10n.whatsappNumberOptionalLabel,
          icon: Icons.chat_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          key: const Key('doctor-onboarding-city'),
          controller: _cityController,
          fieldName: 'city',
          label: l10n.cityLabel,
          icon: Icons.location_city_rounded,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          key: const Key('doctor-onboarding-address'),
          controller: _addressController,
          fieldName: 'address',
          label: l10n.addressLabel,
          icon: Icons.location_on_outlined,
          maxLines: 2,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          key: const Key('doctor-onboarding-bio'),
          controller: _bioController,
          fieldName: 'bio',
          label: l10n.bioOptionalLabel,
          icon: Icons.description_outlined,
          maxLines: 4,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          key: const Key('doctor-onboarding-experience'),
          controller: _experienceController,
          fieldName: 'years_of_experience',
          label: l10n.yearsOfExperienceOptionalLabel,
          icon: Icons.timeline_rounded,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          key: const Key('doctor-onboarding-working-hours'),
          controller: _workingHoursController,
          fieldName: 'working_hours',
          label: l10n.workingHoursOptionalLabel,
          icon: Icons.schedule_rounded,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_isSaving) {
              _save();
            }
          },
        ),
        if (_generalError != null) ...[
          const SizedBox(height: 20),
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
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('doctor-onboarding-save'),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.saveDoctorProfileButton),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    required String fieldName,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    int maxLines = 1,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      key: key,
      controller: controller,
      enabled: !_isSaving,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      textAlign: TextAlign.start,
      onChanged: (_) => _clearError(fieldName),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        errorText: _fieldErrors[fieldName],
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}
