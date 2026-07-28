// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Hakim';

  @override
  String get appTagline => 'Clear health guidance, from the first step.';

  @override
  String get welcomeDisclaimer =>
      'Hakim helps you understand urgency and reach the right specialty and doctor. It does not provide a final diagnosis or prescriptions.';

  @override
  String get getStarted => 'Continue';

  @override
  String get chooseRole => 'Choose Role';

  @override
  String get roleQuestion => 'How do you want to use Hakim?';

  @override
  String get patient => 'Patient';

  @override
  String get patientSubtitle =>
      'Describe symptoms and get guided to the right specialty.';

  @override
  String get doctor => 'Doctor';

  @override
  String get doctorSubtitle =>
      'Manage profile and receive suitable patient requests later.';

  @override
  String get doctorFlowLater => 'Doctor flow will be added later.';

  @override
  String get hakimChat => 'Hakim Chat';

  @override
  String get chatWelcomeMessage =>
      'Hello, I am Hakim. I can help guide you to the right medical specialty.';

  @override
  String get chatAskSymptoms => 'Please describe your symptoms clearly.';

  @override
  String get symptomInputHint => 'Describe your symptoms...';

  @override
  String get mockBotResponse =>
      'Your message has been received. In the next step, Hakim will ask follow-up questions and check emergency warning signs before suggesting the suitable specialty.';

  @override
  String get welcomePrivacy =>
      'By continuing, you agree to the privacy policy and preliminary medical guidance.';
}
