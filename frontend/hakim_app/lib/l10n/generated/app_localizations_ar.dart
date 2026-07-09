// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'حكيم';

  @override
  String get appTagline => 'دليلك إلى الطبيب المناسب';

  @override
  String get welcomeDisclaimer =>
      'يساعدك حكيم على جمع الأعراض، كشف علامات الخطر، واقتراح الاختصاص الطبي المناسب. التطبيق لا يقدم تشخيصاً نهائياً ولا يصف علاجاً أو أدوية.';

  @override
  String get getStarted => 'ابدأ الآن';

  @override
  String get chooseRole => 'اختيار الدور';

  @override
  String get roleQuestion => 'كيف تريد استخدام حكيم؟';

  @override
  String get patient => 'مريض';

  @override
  String get patientSubtitle =>
      'اشرح الأعراض واحصل على توجيه نحو الاختصاص المناسب.';

  @override
  String get doctor => 'طبيب';

  @override
  String get doctorSubtitle =>
      'إدارة الملف المهني واستقبال طلبات المرضى المناسبة لاحقاً.';

  @override
  String get doctorFlowLater => 'سيتم إضافة مسار الطبيب لاحقاً.';

  @override
  String get hakimChat => 'محادثة حكيم';

  @override
  String get chatWelcomeMessage =>
      'مرحباً، أنا حكيم. أستطيع مساعدتك في التوجه إلى الاختصاص الطبي المناسب.';

  @override
  String get chatAskSymptoms => 'يرجى وصف الأعراض التي تشعر بها بوضوح.';

  @override
  String get symptomInputHint => 'اكتب الأعراض التي تشعر بها...';

  @override
  String get mockBotResponse =>
      'تم استلام رسالتك. في الخطوة القادمة سيقوم حكيم بطرح أسئلة متابعة وفحص علامات الخطر قبل اقتراح الاختصاص المناسب.';
}
