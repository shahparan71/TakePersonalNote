import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static const String _appLockEnabledKey = 'app_lock_enabled';
  static const String _themeModeKey = 'theme_mode';
  static const String _notesViewModeKey = 'notes_view_mode';

  Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockEnabledKey, enabled);
  }

  Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appLockEnabledKey) ?? false;
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
  }

  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? 'system';
  }

  Future<void> setNotesViewMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notesViewModeKey, mode);
  }

  Future<String> getNotesViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_notesViewModeKey) ?? 'card';
  }
}
