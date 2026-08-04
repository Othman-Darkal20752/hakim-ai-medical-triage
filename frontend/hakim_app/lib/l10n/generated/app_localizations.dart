import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Hakim'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Clear health guidance, from the first step.'**
  String get appTagline;

  /// No description provided for @welcomeDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Hakim helps you understand urgency and reach the right specialty and doctor. It does not provide a final diagnosis or prescriptions.'**
  String get welcomeDisclaimer;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get getStarted;

  /// No description provided for @chooseRole.
  ///
  /// In en, this message translates to:
  /// **'Choose Role'**
  String get chooseRole;

  /// No description provided for @roleQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do you want to use Hakim?'**
  String get roleQuestion;

  /// No description provided for @patient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patient;

  /// No description provided for @patientSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Describe symptoms and get guided to the right specialty.'**
  String get patientSubtitle;

  /// No description provided for @doctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get doctor;

  /// No description provided for @doctorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage profile and receive suitable patient requests later.'**
  String get doctorSubtitle;

  /// No description provided for @doctorFlowLater.
  ///
  /// In en, this message translates to:
  /// **'Doctor flow will be added later.'**
  String get doctorFlowLater;

  /// No description provided for @hakimChat.
  ///
  /// In en, this message translates to:
  /// **'Hakim Chat'**
  String get hakimChat;

  /// No description provided for @chatWelcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello, I am Hakim. I can help guide you to the right medical specialty.'**
  String get chatWelcomeMessage;

  /// No description provided for @chatAskSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Please describe your symptoms clearly.'**
  String get chatAskSymptoms;

  /// No description provided for @symptomInputHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your symptoms...'**
  String get symptomInputHint;

  /// No description provided for @mockBotResponse.
  ///
  /// In en, this message translates to:
  /// **'Your message has been received. In the next step, Hakim will ask follow-up questions and check emergency warning signs before suggesting the suitable specialty.'**
  String get mockBotResponse;

  /// No description provided for @welcomePrivacy.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to the privacy policy and preliminary medical guidance.'**
  String get welcomePrivacy;

  /// No description provided for @patientLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Patient Sign In'**
  String get patientLoginTitle;

  /// No description provided for @doctorLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor Sign In'**
  String get doctorLoginTitle;

  /// No description provided for @patientLoginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Hakim'**
  String get patientLoginWelcome;

  /// No description provided for @doctorLoginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the Doctor Portal'**
  String get doctorLoginWelcome;

  /// No description provided for @loginDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your account and securely restore your session.'**
  String get loginDescription;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginButton;

  /// No description provided for @orLabel.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orLabel;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @loginRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Enter your username and password.'**
  String get loginRequiredFields;

  /// No description provided for @loginServerError.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in. Check that the server is running and that you are connected to the network.'**
  String get loginServerError;

  /// No description provided for @googleLoginCanceled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in was canceled.'**
  String get googleLoginCanceled;

  /// No description provided for @googleClientConfigurationError.
  ///
  /// In en, this message translates to:
  /// **'Google configuration is invalid. Check the package name, SHA-1, and Web Client ID.'**
  String get googleClientConfigurationError;

  /// No description provided for @googleProviderConfigurationError.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In is unavailable or not configured on this device.'**
  String get googleProviderConfigurationError;

  /// No description provided for @googleUiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to display the Google account selection window.'**
  String get googleUiUnavailable;

  /// No description provided for @googleLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed.'**
  String get googleLoginFailed;

  /// No description provided for @googleLoginServerError.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in with Google. Check the connection and server configuration.'**
  String get googleLoginServerError;

  /// No description provided for @noAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccountQuestion;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @alreadyHaveAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccountQuestion;

  /// No description provided for @signInInstead.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInInstead;

  /// No description provided for @patientRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Patient Account'**
  String get patientRegisterTitle;

  /// No description provided for @doctorRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Doctor Account'**
  String get doctorRegisterTitle;

  /// No description provided for @patientRegisterWelcome.
  ///
  /// In en, this message translates to:
  /// **'Start with Hakim'**
  String get patientRegisterWelcome;

  /// No description provided for @doctorRegisterWelcome.
  ///
  /// In en, this message translates to:
  /// **'Join Hakim'**
  String get doctorRegisterWelcome;

  /// No description provided for @registerDescription.
  ///
  /// In en, this message translates to:
  /// **'Create your account now. You can complete the rest of your information later.'**
  String get registerDescription;

  /// No description provided for @emailOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailOptionalLabel;

  /// No description provided for @passwordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get passwordConfirmLabel;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerButton;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a username.'**
  String get usernameRequired;

  /// No description provided for @usernameTooLong.
  ///
  /// In en, this message translates to:
  /// **'The username must not exceed 150 characters.'**
  String get usernameTooLong;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address or leave the field empty.'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a password.'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'The password must contain at least 8 characters.'**
  String get passwordTooShort;

  /// No description provided for @passwordConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the password again.'**
  String get passwordConfirmRequired;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get passwordMismatch;

  /// No description provided for @registerServerError.
  ///
  /// In en, this message translates to:
  /// **'Unable to create the account. Check that the server is running and that you are connected to the network.'**
  String get registerServerError;

  /// No description provided for @doctorProfileSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Doctor Profile'**
  String get doctorProfileSetupTitle;

  /// No description provided for @doctorProfileSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your core professional information. The administration will review your profile before it appears to patients.'**
  String get doctorProfileSetupDescription;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Professional name'**
  String get displayNameLabel;

  /// No description provided for @specialtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Medical specialty'**
  String get specialtyLabel;

  /// No description provided for @medicalLicenseNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Medical license number'**
  String get medicalLicenseNumberLabel;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumberLabel;

  /// No description provided for @whatsappNumberOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number (optional)'**
  String get whatsappNumberOptionalLabel;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// No description provided for @bioOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Professional bio (optional)'**
  String get bioOptionalLabel;

  /// No description provided for @yearsOfExperienceOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Years of experience (optional)'**
  String get yearsOfExperienceOptionalLabel;

  /// No description provided for @workingHoursOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Working hours (optional)'**
  String get workingHoursOptionalLabel;

  /// No description provided for @saveDoctorProfileButton.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get saveDoctorProfileButton;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredField;

  /// No description provided for @specialtyRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a medical specialty.'**
  String get specialtyRequired;

  /// No description provided for @yearsOfExperienceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a non-negative whole number.'**
  String get yearsOfExperienceInvalid;

  /// No description provided for @specialtiesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load medical specialties.'**
  String get specialtiesLoadError;

  /// No description provided for @specialtiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No medical specialties are currently available.'**
  String get specialtiesEmpty;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get retryButton;

  /// No description provided for @doctorProfileSaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save the doctor profile. Check your connection and try again.'**
  String get doctorProfileSaveError;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logoutButton;

  /// No description provided for @logoutError.
  ///
  /// In en, this message translates to:
  /// **'Unable to log out. Please try again.'**
  String get logoutError;

  /// No description provided for @patientHealthProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'My Health Profile'**
  String get patientHealthProfileTitle;

  /// No description provided for @patientHealthProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep your core health information updated so Hakim can use only the minimum necessary context during preliminary medical guidance.'**
  String get patientHealthProfileDescription;

  /// No description provided for @patientHealthProfilePrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'This is sensitive health information. It must remain limited to your account and authorized medical guidance purposes.'**
  String get patientHealthProfilePrivacyNote;

  /// No description provided for @medicalHistorySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical History'**
  String get medicalHistorySectionTitle;

  /// No description provided for @lifestyleSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Additional Health Information'**
  String get lifestyleSectionTitle;

  /// No description provided for @chronicConditionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Chronic conditions'**
  String get chronicConditionsLabel;

  /// No description provided for @allergiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergiesLabel;

  /// No description provided for @currentMedicationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Current medications'**
  String get currentMedicationsLabel;

  /// No description provided for @previousSurgeriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous surgeries'**
  String get previousSurgeriesLabel;

  /// No description provided for @oneItemPerLineHint.
  ///
  /// In en, this message translates to:
  /// **'Enter each item on a separate line.'**
  String get oneItemPerLineHint;

  /// No description provided for @smokingStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Smoking status'**
  String get smokingStatusLabel;

  /// No description provided for @alcoholUseLabel.
  ///
  /// In en, this message translates to:
  /// **'Alcohol use'**
  String get alcoholUseLabel;

  /// No description provided for @pregnancyStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy status'**
  String get pregnancyStatusLabel;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get statusUnknown;

  /// No description provided for @statusNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get statusNever;

  /// No description provided for @statusFormer.
  ///
  /// In en, this message translates to:
  /// **'Former'**
  String get statusFormer;

  /// No description provided for @statusCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get statusCurrent;

  /// No description provided for @pregnancyNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Not applicable'**
  String get pregnancyNotApplicable;

  /// No description provided for @pregnancyNotPregnant.
  ///
  /// In en, this message translates to:
  /// **'Not pregnant'**
  String get pregnancyNotPregnant;

  /// No description provided for @pregnancyPregnant.
  ///
  /// In en, this message translates to:
  /// **'Pregnant'**
  String get pregnancyPregnant;

  /// No description provided for @saveHealthProfileButton.
  ///
  /// In en, this message translates to:
  /// **'Save Health Profile'**
  String get saveHealthProfileButton;

  /// No description provided for @healthProfileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the health profile. Check your connection and try again.'**
  String get healthProfileLoadError;

  /// No description provided for @healthProfileSaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save the health profile. Check your connection and try again.'**
  String get healthProfileSaveError;

  /// No description provided for @healthProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Health profile saved successfully.'**
  String get healthProfileSaved;

  /// No description provided for @healthProfileListTooMany.
  ///
  /// In en, this message translates to:
  /// **'A maximum of 50 items is allowed.'**
  String get healthProfileListTooMany;

  /// No description provided for @healthProfileItemTooLong.
  ///
  /// In en, this message translates to:
  /// **'Each item must not exceed 200 characters.'**
  String get healthProfileItemTooLong;

  /// No description provided for @healthProfileLastReviewed.
  ///
  /// In en, this message translates to:
  /// **'Information last reviewed'**
  String get healthProfileLastReviewed;

  /// No description provided for @healthProfileNeverReviewed.
  ///
  /// In en, this message translates to:
  /// **'The information has not been reviewed yet'**
  String get healthProfileNeverReviewed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
