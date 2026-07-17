import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton manager that controls the app's ThemeMode.
/// Follows the same pattern as AppLanguage.
class AppThemeManager extends ChangeNotifier {
  AppThemeManager._();

  static final AppThemeManager instance = AppThemeManager._();

  static const _preferenceKey = 'finflow_theme_mode';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  Future<void> init() async {
    try {
      final saved = await _preferences.getString(_preferenceKey);
      _mode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      _mode = ThemeMode.light;
    }
  }

  void setMode(ThemeMode mode) {
    if (mode == ThemeMode.system) return;
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    unawaited(
      _preferences.setString(
        _preferenceKey,
        mode == ThemeMode.dark ? 'dark' : 'light',
      ),
    );
  }

  void toggle() =>
      setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  bool get isDark {
    return _mode == ThemeMode.dark;
  }
}
