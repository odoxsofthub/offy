import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const String _languageKey = 'selected_language_code';

  Locale _currentLocale = const Locale('en', 'US');

  LanguageProvider(this._prefs) {
    _loadSavedLanguage();
  }

  Locale get currentLocale => _currentLocale;

  void _loadSavedLanguage() {
    final String? savedCode = _prefs.getString(_languageKey);
    if (savedCode != null && savedCode.isNotEmpty) {
      _currentLocale = _localeFromCode(savedCode);
      notifyListeners();
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    final newLocale = _localeFromCode(languageCode);
    if (_currentLocale != newLocale) {
      _currentLocale = newLocale;
      await _prefs.setString(_languageKey, languageCode);
      notifyListeners();
    }
  }

  Locale _localeFromCode(String code) {
    // E.g. 'en_US', 'en_UK', 'es', 'ar'
    final parts = code.split('_');
    if (parts.length == 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }
}
