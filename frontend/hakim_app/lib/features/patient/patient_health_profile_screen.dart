import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/data/auth_service.dart';
import '../auth/data/session_expired_exception.dart';
import '../onboarding/welcome_screen.dart';
import 'data/patient_health_profile.dart';
import 'data/patient_health_profile_api.dart';
import 'data/patient_health_profile_update.dart';

typedef PatientHealthProfileLoader = Future<PatientHealthProfile> Function();

typedef PatientHealthProfileUpdater =
    Future<PatientHealthProfile> Function(PatientHealthProfileUpdate update);

class PatientHealthProfileScreen extends StatefulWidget {
  final AuthService? authService;
  final PatientHealthProfileLoader? profileLoader;
  final PatientHealthProfileUpdater? profileUpdater;

  const PatientHealthProfileScreen({
    super.key,
    this.authService,
    this.profileLoader,
    this.profileUpdater,
  });

  @override
  State<PatientHealthProfileScreen> createState() =>
      _PatientHealthProfileScreenState();
}

class _PatientHealthProfileScreenState
    extends State<PatientHealthProfileScreen> {
  late final AuthService _authService;
  late final PatientHealthProfileApi _profileApi;
  late final PatientHealthProfileLoader _profileLoader;
  late final PatientHealthProfileUpdater _profileUpdater;

  final TextEditingController _chronicConditionsController =
      TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _currentMedicationsController =
      TextEditingController();
  final TextEditingController _previousSurgeriesController =
      TextEditingController();

  final Map<String, String> _fieldErrors = {};

  PatientHealthProfile? _profile;

  SmokingStatus _smokingStatus = SmokingStatus.unknown;
  AlcoholUse _alcoholUse = AlcoholUse.unknown;
  PregnancyStatus _pregnancyStatus = PregnancyStatus.notApplicable;

  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isSaving = false;

  String? _generalError;

  @override
  void initState() {
    super.initState();

    _authService = widget.authService ?? AuthService();
    _profileApi = PatientHealthProfileApi(_authService.authenticatedApiClient);

    _profileLoader = widget.profileLoader ?? _profileApi.getProfile;
    _profileUpdater = widget.profileUpdater ?? _profileApi.updateProfile;

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }

    try {
      final profile = await _profileLoader();

      if (!mounted) {
        return;
      }

      _populateForm(profile);

      setState(() {
        _profile = profile;
        _isLoading = false;
        _loadFailed = false;
      });
    } on SessionExpiredException {
      _redirectToWelcome();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  void _populateForm(PatientHealthProfile profile) {
    _chronicConditionsController.text = profile.chronicConditions.join('\n');
    _allergiesController.text = profile.allergies.join('\n');
    _currentMedicationsController.text = profile.currentMedications.join('\n');
    _previousSurgeriesController.text = profile.previousSurgeries.join('\n');

    _smokingStatus = profile.smokingStatus;
    _alcoholUse = profile.alcoholUse;
    _pregnancyStatus = profile.pregnancyStatus;
  }

  List<String> _parseItems(TextEditingController controller) {
    return controller.text
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  bool _validate() {
    final l10n = AppLocalizations.of(context);
    final errors = <String, String>{};

    void validateList(String fieldName, TextEditingController controller) {
      final items = _parseItems(controller);

      if (items.length > 50) {
        errors[fieldName] = l10n.healthProfileListTooMany;
        return;
      }

      if (items.any((item) => item.length > 200)) {
        errors[fieldName] = l10n.healthProfileItemTooLong;
      }
    }

    validateList('chronic_conditions', _chronicConditionsController);
    validateList('allergies', _allergiesController);
    validateList('current_medications', _currentMedicationsController);
    validateList('previous_surgeries', _previousSurgeriesController);

    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);

      _generalError = null;
    });

    return errors.isEmpty;
  }

  Future<void> _save() async {
    if (_isSaving || !_validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _generalError = null;
    });

    final update = PatientHealthProfileUpdate(
      chronicConditions: _parseItems(_chronicConditionsController),
      allergies: _parseItems(_allergiesController),
      currentMedications: _parseItems(_currentMedicationsController),
      previousSurgeries: _parseItems(_previousSurgeriesController),
      smokingStatus: _smokingStatus,
      alcoholUse: _alcoholUse,
      pregnancyStatus: _pregnancyStatus,
    );

    try {
      final updatedProfile = await _profileUpdater(update);

      if (!mounted) {
        return;
      }

      _populateForm(updatedProfile);

      setState(() {
        _profile = updatedProfile;
        _fieldErrors.clear();
        _generalError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).healthProfileSaved),
        ),
      );
    } on SessionExpiredException {
      _redirectToWelcome();
    } on ApiException catch (error) {
      _applyApiError(error);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _generalError = AppLocalizations.of(context).healthProfileSaveError;
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
      'chronic_conditions',
      'allergies',
      'current_medications',
      'previous_surgeries',
      'smoking_status',
      'alcohol_use',
      'pregnancy_status',
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

  void _redirectToWelcome() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _chronicConditionsController.dispose();
    _allergiesController.dispose();
    _currentMedicationsController.dispose();
    _previousSurgeriesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.patientHealthProfileTitle)),
      body: SafeArea(
        child: switch ((_isLoading, _loadFailed, _profile)) {
          (true, _, _) => const Center(
            key: Key('patient-health-profile-loading'),
            child: CircularProgressIndicator(),
          ),
          (false, true, _) => _buildLoadError(),
          (false, false, final profile?) => _buildForm(profile),
          _ => _buildLoadError(),
        },
      ),
    );
  }

  Widget _buildLoadError() {
    final l10n = AppLocalizations.of(context);

    return ListView(
      key: const Key('patient-health-profile-load-error'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.error_outline_rounded,
          size: 64,
          color: AppTheme.destructive,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.healthProfileLoadError,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            key: const Key('patient-health-profile-retry'),
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retryButton),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(PatientHealthProfile profile) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      key: const Key('patient-health-profile-form'),
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(
          Icons.health_and_safety_outlined,
          size: 68,
          color: AppTheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.patientHealthProfileTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.patientHealthProfileDescription,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.secondary,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.patientHealthProfilePrivacyNote,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: l10n.medicalHistorySectionTitle,
          icon: Icons.medical_information_outlined,
          children: [
            _buildListField(
              key: const Key('patient-health-profile-chronic-conditions'),
              controller: _chronicConditionsController,
              fieldName: 'chronic_conditions',
              label: l10n.chronicConditionsLabel,
              icon: Icons.monitor_heart_outlined,
            ),
            const SizedBox(height: 16),
            _buildListField(
              key: const Key('patient-health-profile-allergies'),
              controller: _allergiesController,
              fieldName: 'allergies',
              label: l10n.allergiesLabel,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 16),
            _buildListField(
              key: const Key('patient-health-profile-current-medications'),
              controller: _currentMedicationsController,
              fieldName: 'current_medications',
              label: l10n.currentMedicationsLabel,
              icon: Icons.medication_outlined,
            ),
            const SizedBox(height: 16),
            _buildListField(
              key: const Key('patient-health-profile-previous-surgeries'),
              controller: _previousSurgeriesController,
              fieldName: 'previous_surgeries',
              label: l10n.previousSurgeriesLabel,
              icon: Icons.healing_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: l10n.lifestyleSectionTitle,
          icon: Icons.fact_check_outlined,
          children: [
            DropdownButtonFormField<SmokingStatus>(
              key: const Key('patient-health-profile-smoking-status'),
              initialValue: _smokingStatus,
              isExpanded: true,
              items: SmokingStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_smokingLabel(status, l10n)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _smokingStatus = value;
                        _fieldErrors.remove('smoking_status');
                        _generalError = null;
                      });
                    },
              decoration: InputDecoration(
                labelText: l10n.smokingStatusLabel,
                prefixIcon: const Icon(Icons.smoke_free_outlined),
                errorText: _fieldErrors['smoking_status'],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AlcoholUse>(
              key: const Key('patient-health-profile-alcohol-use'),
              initialValue: _alcoholUse,
              isExpanded: true,
              items: AlcoholUse.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_alcoholLabel(status, l10n)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _alcoholUse = value;
                        _fieldErrors.remove('alcohol_use');
                        _generalError = null;
                      });
                    },
              decoration: InputDecoration(
                labelText: l10n.alcoholUseLabel,
                prefixIcon: const Icon(Icons.local_bar_outlined),
                errorText: _fieldErrors['alcohol_use'],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PregnancyStatus>(
              key: const Key('patient-health-profile-pregnancy-status'),
              initialValue: _pregnancyStatus,
              isExpanded: true,
              items: PregnancyStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_pregnancyLabel(status, l10n)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _pregnancyStatus = value;
                        _fieldErrors.remove('pregnancy_status');
                        _generalError = null;
                      });
                    },
              decoration: InputDecoration(
                labelText: l10n.pregnancyStatusLabel,
                prefixIcon: const Icon(Icons.family_restroom_outlined),
                errorText: _fieldErrors['pregnancy_status'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildReviewInformation(profile),
        if (_generalError != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.emergencyBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.emergencyForeground),
            ),
            child: Text(
              _generalError!,
              textAlign: TextAlign.start,
              style: const TextStyle(
                color: AppTheme.emergencyForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('patient-health-profile-save'),
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(l10n.saveHealthProfileButton),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildListField({
    required Key key,
    required TextEditingController controller,
    required String fieldName,
    required String label,
    required IconData icon,
  }) {
    final l10n = AppLocalizations.of(context);

    return TextField(
      key: key,
      controller: controller,
      enabled: !_isSaving,
      minLines: 3,
      maxLines: 5,
      textAlign: TextAlign.start,
      textCapitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.multiline,
      onChanged: (_) => _clearError(fieldName),
      decoration: InputDecoration(
        labelText: label,
        helperText: l10n.oneItemPerLineHint,
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 56),
          child: Icon(icon),
        ),
        errorText: _fieldErrors[fieldName],
      ),
    );
  }

  Widget _buildReviewInformation(PatientHealthProfile profile) {
    final l10n = AppLocalizations.of(context);
    final reviewedAt = profile.lastReviewedAt?.toLocal();

    final reviewedValue = reviewedAt == null
        ? l10n.healthProfileNeverReviewed
        : '${MaterialLocalizations.of(context).formatMediumDate(reviewedAt)}'
              ' • ${TimeOfDay.fromDateTime(reviewedAt).format(context)}';

    return Card(
      child: ListTile(
        leading: const Icon(Icons.update_rounded, color: AppTheme.primary),
        title: Text(l10n.healthProfileLastReviewed),
        subtitle: Text(reviewedValue),
      ),
    );
  }

  String _smokingLabel(SmokingStatus status, AppLocalizations l10n) {
    return switch (status) {
      SmokingStatus.unknown => l10n.statusUnknown,
      SmokingStatus.never => l10n.statusNever,
      SmokingStatus.former => l10n.statusFormer,
      SmokingStatus.current => l10n.statusCurrent,
    };
  }

  String _alcoholLabel(AlcoholUse status, AppLocalizations l10n) {
    return switch (status) {
      AlcoholUse.unknown => l10n.statusUnknown,
      AlcoholUse.never => l10n.statusNever,
      AlcoholUse.former => l10n.statusFormer,
      AlcoholUse.current => l10n.statusCurrent,
    };
  }

  String _pregnancyLabel(PregnancyStatus status, AppLocalizations l10n) {
    return switch (status) {
      PregnancyStatus.notApplicable => l10n.pregnancyNotApplicable,
      PregnancyStatus.unknown => l10n.statusUnknown,
      PregnancyStatus.notPregnant => l10n.pregnancyNotPregnant,
      PregnancyStatus.pregnant => l10n.pregnancyPregnant,
    };
  }
}
