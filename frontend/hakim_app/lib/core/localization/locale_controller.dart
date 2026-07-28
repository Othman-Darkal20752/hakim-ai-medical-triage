import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController {
  LocaleController._();

  static const String _storageKey = 'app_locale';

  static final LocaleController instance = LocaleController._();

  final ValueNotifier<Locale> locale = ValueNotifier<Locale>(
    const Locale('ar'),
  );

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedLanguageCode = preferences.getString(_storageKey);

      if (storedLanguageCode == 'en') {
        locale.value = const Locale('en');
      } else {
        locale.value = const Locale('ar');
      }
    } catch (_) {
      locale.value = const Locale('ar');
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    final languageCode = newLocale.languageCode;

    if (languageCode != 'ar' && languageCode != 'en') {
      return;
    }

    if (locale.value.languageCode == languageCode) {
      return;
    }

    locale.value = Locale(languageCode);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, languageCode);
  }

  Future<void> toggleLocale() {
    final nextLocale = locale.value.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');

    return setLocale(nextLocale);
  }
}
