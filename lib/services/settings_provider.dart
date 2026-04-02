import 'package:flutter/material.dart';
import '../services/preference_service.dart';

class SettingsProvider extends ChangeNotifier {
  final PreferenceService _service = PreferenceService();
  
  bool _isAppLockEnabled = false;
  ThemeMode _themeMode = ThemeMode.system;

  bool get isAppLockEnabled => _isAppLockEnabled;
  ThemeMode get themeMode => _themeMode;

  Future<void> loadSettings() async {
    _isAppLockEnabled = await _service.isAppLockEnabled();
    final themeStr = await _service.getThemeMode();
    _themeMode = _parseThemeMode(themeStr);
    notifyListeners();
  }

  Future<void> toggleAppLock(bool value) async {
    await _service.setAppLockEnabled(value);
    _isAppLockEnabled = value;
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    await _service.setThemeMode(mode);
    _themeMode = _parseThemeMode(mode);
    notifyListeners();
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  String get themeModeString {
    if (_themeMode == ThemeMode.light) return 'light';
    if (_themeMode == ThemeMode.dark) return 'dark';
    return 'system';
  }
}
