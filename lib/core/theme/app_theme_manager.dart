import 'package:flutter/material.dart';

/// Singleton manager that controls the app's ThemeMode.
/// Follows the same pattern as AppLanguage.
class AppThemeManager extends ChangeNotifier {
  AppThemeManager._();

  static final AppThemeManager instance = AppThemeManager._();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggle() {
    switch (_mode) {
      case ThemeMode.system:
        _mode = ThemeMode.dark;
      case ThemeMode.light:
        _mode = ThemeMode.system;
      case ThemeMode.dark:
        _mode = ThemeMode.light;
    }
    notifyListeners();
  }

  bool get isDark {
    // This returns the *intended* state, not the actual system brightness.
    // Widgets should use Theme.of(context).brightness instead.
    return _mode == ThemeMode.dark;
  }
}
