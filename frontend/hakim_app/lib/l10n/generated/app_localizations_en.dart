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
  String get appTagline => 'Your guide to the right doctor';

  @override
  String get welcomeDisclaimer =>
      'Hakim helps collect symptoms, detect emergency warning signs, and suggest the suitable medical specialty. It does not provide final diagnosis or prescribe treatment.';

  @override
  String get getStarted => 'Get Started';

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
}
