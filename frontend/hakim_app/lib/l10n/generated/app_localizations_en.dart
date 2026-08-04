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

  @override
  String get patientLoginTitle => 'Patient Sign In';

  @override
  String get doctorLoginTitle => 'Doctor Sign In';

  @override
  String get patientLoginWelcome => 'Welcome to Hakim';

  @override
  String get doctorLoginWelcome => 'Welcome to the Doctor Portal';

  @override
  String get loginDescription =>
      'Sign in to access your account and securely restore your session.';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginButton => 'Sign In';

  @override
  String get orLabel => 'OR';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get loginRequiredFields => 'Enter your username and password.';

  @override
  String get loginServerError =>
      'Unable to sign in. Check that the server is running and that you are connected to the network.';

  @override
  String get googleLoginCanceled => 'Google sign-in was canceled.';

  @override
  String get googleClientConfigurationError =>
      'Google configuration is invalid. Check the package name, SHA-1, and Web Client ID.';

  @override
  String get googleProviderConfigurationError =>
      'Google Sign-In is unavailable or not configured on this device.';

  @override
  String get googleUiUnavailable =>
      'Unable to display the Google account selection window.';

  @override
  String get googleLoginFailed => 'Google sign-in failed.';

  @override
  String get googleLoginServerError =>
      'Unable to sign in with Google. Check the connection and server configuration.';

  @override
  String get noAccountQuestion => 'Don\'t have an account?';

  @override
  String get createAccount => 'Create Account';

  @override
  String get alreadyHaveAccountQuestion => 'Already have an account?';

  @override
  String get signInInstead => 'Sign In';

  @override
  String get patientRegisterTitle => 'Create Patient Account';

  @override
  String get doctorRegisterTitle => 'Create Doctor Account';

  @override
  String get patientRegisterWelcome => 'Start with Hakim';

  @override
  String get doctorRegisterWelcome => 'Join Hakim';

  @override
  String get registerDescription =>
      'Create your account now. You can complete the rest of your information later.';

  @override
  String get emailOptionalLabel => 'Email (optional)';

  @override
  String get passwordConfirmLabel => 'Confirm Password';

  @override
  String get registerButton => 'Create Account';

  @override
  String get usernameRequired => 'Enter a username.';

  @override
  String get usernameTooLong => 'The username must not exceed 150 characters.';

  @override
  String get emailInvalid =>
      'Enter a valid email address or leave the field empty.';

  @override
  String get passwordRequired => 'Enter a password.';

  @override
  String get passwordTooShort =>
      'The password must contain at least 8 characters.';

  @override
  String get passwordConfirmRequired => 'Enter the password again.';

  @override
  String get passwordMismatch => 'The passwords do not match.';

  @override
  String get registerServerError =>
      'Unable to create the account. Check that the server is running and that you are connected to the network.';

  @override
  String get doctorProfileSetupTitle => 'Complete Doctor Profile';

  @override
  String get doctorProfileSetupDescription =>
      'Enter your core professional information. The administration will review your profile before it appears to patients.';

  @override
  String get displayNameLabel => 'Professional name';

  @override
  String get specialtyLabel => 'Medical specialty';

  @override
  String get medicalLicenseNumberLabel => 'Medical license number';

  @override
  String get phoneNumberLabel => 'Phone number';

  @override
  String get whatsappNumberOptionalLabel => 'WhatsApp number (optional)';

  @override
  String get cityLabel => 'City';

  @override
  String get addressLabel => 'Address';

  @override
  String get bioOptionalLabel => 'Professional bio (optional)';

  @override
  String get yearsOfExperienceOptionalLabel => 'Years of experience (optional)';

  @override
  String get workingHoursOptionalLabel => 'Working hours (optional)';

  @override
  String get saveDoctorProfileButton => 'Save Profile';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get specialtyRequired => 'Select a medical specialty.';

  @override
  String get yearsOfExperienceInvalid => 'Enter a non-negative whole number.';

  @override
  String get specialtiesLoadError => 'Unable to load medical specialties.';

  @override
  String get specialtiesEmpty =>
      'No medical specialties are currently available.';

  @override
  String get retryButton => 'Try Again';

  @override
  String get doctorProfileSaveError =>
      'Unable to save the doctor profile. Check your connection and try again.';

  @override
  String get logoutButton => 'Log out';

  @override
  String get logoutError => 'Unable to log out. Please try again.';

  @override
  String get patientHealthProfileTitle => 'My Health Profile';

  @override
  String get patientHealthProfileDescription =>
      'Keep your core health information updated so Hakim can use only the minimum necessary context during preliminary medical guidance.';

  @override
  String get patientHealthProfilePrivacyNote =>
      'This is sensitive health information. It must remain limited to your account and authorized medical guidance purposes.';

  @override
  String get medicalHistorySectionTitle => 'Medical History';

  @override
  String get lifestyleSectionTitle => 'Additional Health Information';

  @override
  String get chronicConditionsLabel => 'Chronic conditions';

  @override
  String get allergiesLabel => 'Allergies';

  @override
  String get currentMedicationsLabel => 'Current medications';

  @override
  String get previousSurgeriesLabel => 'Previous surgeries';

  @override
  String get oneItemPerLineHint => 'Enter each item on a separate line.';

  @override
  String get smokingStatusLabel => 'Smoking status';

  @override
  String get alcoholUseLabel => 'Alcohol use';

  @override
  String get pregnancyStatusLabel => 'Pregnancy status';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get statusNever => 'Never';

  @override
  String get statusFormer => 'Former';

  @override
  String get statusCurrent => 'Current';

  @override
  String get pregnancyNotApplicable => 'Not applicable';

  @override
  String get pregnancyNotPregnant => 'Not pregnant';

  @override
  String get pregnancyPregnant => 'Pregnant';

  @override
  String get saveHealthProfileButton => 'Save Health Profile';

  @override
  String get healthProfileLoadError =>
      'Unable to load the health profile. Check your connection and try again.';

  @override
  String get healthProfileSaveError =>
      'Unable to save the health profile. Check your connection and try again.';

  @override
  String get healthProfileSaved => 'Health profile saved successfully.';

  @override
  String get healthProfileListTooMany => 'A maximum of 50 items is allowed.';

  @override
  String get healthProfileItemTooLong =>
      'Each item must not exceed 200 characters.';

  @override
  String get healthProfileLastReviewed => 'Information last reviewed';

  @override
  String get healthProfileNeverReviewed =>
      'The information has not been reviewed yet';
}
