import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../domain/usecases/change_theme.dart';
import '../../../domain/usecases/get_saved_theme.dart';

class ThemeProvider extends ChangeNotifier {
  final GetSavedTheme getSavedTheme;
  final ChangeTheme changeTheme;

  late ThemeData _themeData;
  late bool _isDarkMode;

  ThemeProvider({
    required this.getSavedTheme,
    required this.changeTheme,
  }) {
    _isDarkMode = getSavedTheme() ??
        (PlatformDispatcher.instance.platformBrightness == Brightness.dark);
    _themeData = _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;
  }

  ThemeData get themeData => _themeData;
  bool get isDarkMode => _isDarkMode;

  void loadTheme() {
    _isDarkMode = getSavedTheme() ??
        (PlatformDispatcher.instance.platformBrightness == Brightness.dark);
    _themeData = _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await changeTheme(_isDarkMode);
    _themeData = _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;
    notifyListeners();
  }
}

