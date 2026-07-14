import 'package:flutter/material.dart';
import '../services/preference_service.dart';

class SettingsProvider extends ChangeNotifier {
  final PreferenceService _service = PreferenceService();
  
  bool _isAppLockEnabled = false;
  bool _isDriveAutoSyncEnabled = false;
  bool _isBatteryPromptShown = false;
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');

  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isDriveAutoSyncEnabled => _isDriveAutoSyncEnabled;
  bool get isBatteryPromptShown => _isBatteryPromptShown;
  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  Future<void> loadSettings() async {
    _isAppLockEnabled = await _service.isAppLockEnabled();
    _isDriveAutoSyncEnabled = await _service.isDriveAutoSyncEnabled();
    _isBatteryPromptShown = await _service.isBatteryPromptShown();
    final themeStr = await _service.getThemeMode();
    _themeMode = _parseThemeMode(themeStr);
    final langStr = await _service.getAppLanguage();
    _locale = Locale(langStr);
    notifyListeners();
  }

  Future<void> toggleAppLock(bool value) async {
    await _service.setAppLockEnabled(value);
    _isAppLockEnabled = value;
    notifyListeners();
  }

  Future<void> toggleDriveAutoSync(bool value) async {
    await _service.setDriveAutoSyncEnabled(value);
    _isDriveAutoSyncEnabled = value;
    notifyListeners();
  }

  Future<void> setBatteryPromptShown(bool value) async {
    await _service.setBatteryPromptShown(value);
    _isBatteryPromptShown = value;
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    await _service.setThemeMode(mode);
    _themeMode = _parseThemeMode(mode);
    notifyListeners();
  }

  Future<void> setLocale(String languageCode) async {
    await _service.setAppLanguage(languageCode);
    _locale = Locale(languageCode);
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
