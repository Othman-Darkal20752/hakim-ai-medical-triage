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
  String get appTagline => 'توجيه صحي واضح، من أول خطوة.';

  @override
  String get welcomeDisclaimer =>
      'يساعدك حكيم على فهم درجة الاستعجال والوصول إلى الاختصاص والطبيب المناسبين. لا يقدّم تشخيصًا نهائيًا أو وصفات علاجية.';

  @override
  String get getStarted => 'متابعة';

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

  @override
  String get welcomePrivacy =>
      'بالمتابعة، أنت توافق على سياسة الخصوصية والإرشاد الطبي الأولي.';

  @override
  String get patientLoginTitle => 'تسجيل دخول المريض';

  @override
  String get doctorLoginTitle => 'تسجيل دخول الطبيب';

  @override
  String get patientLoginWelcome => 'مرحباً بك في حكيم';

  @override
  String get doctorLoginWelcome => 'مرحباً بك في بوابة الطبيب';

  @override
  String get loginDescription =>
      'سجّل الدخول للوصول إلى حسابك واستعادة جلستك بأمان.';

  @override
  String get usernameLabel => 'اسم المستخدم';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get orLabel => 'أو';

  @override
  String get continueWithGoogle => 'المتابعة باستخدام Google';

  @override
  String get loginRequiredFields => 'أدخل اسم المستخدم وكلمة المرور.';

  @override
  String get loginServerError =>
      'تعذر تسجيل الدخول. تأكد من تشغيل الخادم والاتصال بالشبكة.';

  @override
  String get googleLoginCanceled => 'تم إلغاء تسجيل الدخول باستخدام Google.';

  @override
  String get googleClientConfigurationError =>
      'إعداد Google غير صحيح. تحقق من package name وSHA-1 وWeb Client ID.';

  @override
  String get googleProviderConfigurationError =>
      'خدمة Google Sign-In غير متاحة أو غير مضبوطة على الجهاز.';

  @override
  String get googleUiUnavailable => 'تعذر عرض نافذة اختيار حساب Google.';

  @override
  String get googleLoginFailed => 'فشل تسجيل الدخول باستخدام Google.';

  @override
  String get googleLoginServerError =>
      'تعذر تسجيل الدخول باستخدام Google. تحقق من الاتصال وإعدادات الخادم.';
}
