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

  @override
  String get noAccountQuestion => 'ليس لديك حساب؟';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get alreadyHaveAccountQuestion => 'لديك حساب بالفعل؟';

  @override
  String get signInInstead => 'تسجيل الدخول';

  @override
  String get patientRegisterTitle => 'إنشاء حساب مريض';

  @override
  String get doctorRegisterTitle => 'إنشاء حساب طبيب';

  @override
  String get patientRegisterWelcome => 'ابدأ رحلتك مع حكيم';

  @override
  String get doctorRegisterWelcome => 'انضم إلى منصة حكيم';

  @override
  String get registerDescription =>
      'أنشئ حسابك الآن. يمكنك استكمال بياناتك الأخرى لاحقًا.';

  @override
  String get emailOptionalLabel => 'البريد الإلكتروني (اختياري)';

  @override
  String get passwordConfirmLabel => 'تأكيد كلمة المرور';

  @override
  String get registerButton => 'إنشاء الحساب';

  @override
  String get usernameRequired => 'أدخل اسم المستخدم.';

  @override
  String get usernameTooLong => 'يجب ألا يتجاوز اسم المستخدم 150 محرفًا.';

  @override
  String get emailInvalid =>
      'أدخل بريدًا إلكترونيًا صحيحًا أو اترك الحقل فارغًا.';

  @override
  String get passwordRequired => 'أدخل كلمة المرور.';

  @override
  String get passwordTooShort =>
      'يجب أن تتكون كلمة المرور من 8 محارف على الأقل.';

  @override
  String get passwordConfirmRequired => 'أعد إدخال كلمة المرور.';

  @override
  String get passwordMismatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get registerServerError =>
      'تعذر إنشاء الحساب. تحقق من تشغيل الخادم والاتصال بالشبكة.';

  @override
  String get doctorProfileSetupTitle => 'استكمال ملف الطبيب';

  @override
  String get doctorProfileSetupDescription =>
      'أدخل بياناتك المهنية الأساسية. ستراجع الإدارة الملف قبل ظهوره للمرضى.';

  @override
  String get displayNameLabel => 'الاسم المهني';

  @override
  String get specialtyLabel => 'الاختصاص الطبي';

  @override
  String get medicalLicenseNumberLabel => 'رقم الترخيص الطبي';

  @override
  String get phoneNumberLabel => 'رقم الهاتف';

  @override
  String get whatsappNumberOptionalLabel => 'رقم واتساب (اختياري)';

  @override
  String get cityLabel => 'المدينة';

  @override
  String get addressLabel => 'العنوان';

  @override
  String get bioOptionalLabel => 'نبذة مهنية (اختياري)';

  @override
  String get yearsOfExperienceOptionalLabel => 'سنوات الخبرة (اختياري)';

  @override
  String get workingHoursOptionalLabel => 'ساعات العمل (اختياري)';

  @override
  String get saveDoctorProfileButton => 'حفظ الملف';

  @override
  String get requiredField => 'هذا الحقل مطلوب.';

  @override
  String get specialtyRequired => 'اختر الاختصاص الطبي.';

  @override
  String get yearsOfExperienceInvalid => 'أدخل عددًا صحيحًا غير سالب.';

  @override
  String get specialtiesLoadError => 'تعذر تحميل الاختصاصات الطبية.';

  @override
  String get specialtiesEmpty => 'لا توجد اختصاصات متاحة حاليًا.';

  @override
  String get retryButton => 'إعادة المحاولة';

  @override
  String get doctorProfileSaveError =>
      'تعذر حفظ ملف الطبيب. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get logoutButton => 'تسجيل الخروج';

  @override
  String get logoutError => 'تعذر تسجيل الخروج. حاول مرة أخرى.';

  @override
  String get patientHealthProfileTitle => 'ملفي الصحي';

  @override
  String get patientHealthProfileDescription =>
      'حدّث معلوماتك الصحية الأساسية حتى يستخدم حكيم الحد الأدنى الضروري منها أثناء الإرشاد الطبي الأولي.';

  @override
  String get patientHealthProfilePrivacyNote =>
      'هذه المعلومات صحية وحساسة، ولا يجب عرضها إلا ضمن حسابك أو استخدامها خارج الغرض الطبي المصرح به.';

  @override
  String get medicalHistorySectionTitle => 'التاريخ الصحي';

  @override
  String get lifestyleSectionTitle => 'معلومات صحية إضافية';

  @override
  String get chronicConditionsLabel => 'الأمراض المزمنة';

  @override
  String get allergiesLabel => 'الحساسيات';

  @override
  String get currentMedicationsLabel => 'الأدوية الحالية';

  @override
  String get previousSurgeriesLabel => 'العمليات السابقة';

  @override
  String get oneItemPerLineHint => 'اكتب كل معلومة في سطر مستقل.';

  @override
  String get smokingStatusLabel => 'حالة التدخين';

  @override
  String get alcoholUseLabel => 'استخدام الكحول';

  @override
  String get pregnancyStatusLabel => 'حالة الحمل';

  @override
  String get statusUnknown => 'غير معروف';

  @override
  String get statusNever => 'أبدًا';

  @override
  String get statusFormer => 'سابقًا';

  @override
  String get statusCurrent => 'حاليًا';

  @override
  String get pregnancyNotApplicable => 'لا ينطبق';

  @override
  String get pregnancyNotPregnant => 'غير حامل';

  @override
  String get pregnancyPregnant => 'حامل';

  @override
  String get saveHealthProfileButton => 'حفظ الملف الصحي';

  @override
  String get healthProfileLoadError =>
      'تعذر تحميل الملف الصحي. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get healthProfileSaveError =>
      'تعذر حفظ الملف الصحي. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get healthProfileSaved => 'تم حفظ الملف الصحي بنجاح.';

  @override
  String get healthProfileListTooMany => 'الحد الأقصى المسموح هو 50 عنصرًا.';

  @override
  String get healthProfileItemTooLong => 'يجب ألا يتجاوز كل عنصر 200 محرف.';

  @override
  String get healthProfileLastReviewed => 'آخر مراجعة للمعلومات';

  @override
  String get healthProfileNeverReviewed => 'لم تتم مراجعة المعلومات بعد';
}
