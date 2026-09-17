import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static final LanguageService instance = LanguageService._();
  LanguageService._();

  static const _key = 'app_locale';

  Locale _locale = const Locale('el');

  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'el';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
    notifyListeners();
  }

  void toggle() {
    setLocale(_locale.languageCode == 'el' ? const Locale('en') : const Locale('el'));
  }

  bool get isGreek => _locale.languageCode == 'el';
}
