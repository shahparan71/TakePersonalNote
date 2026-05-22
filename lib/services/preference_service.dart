import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static const String _appLockEnabledKey = 'app_lock_enabled';
  static const String _themeModeKey = 'theme_mode';
  static const String _notesViewModeKey = 'notes_view_mode';
  static const String _driveAutoSyncEnabledKey = 'drive_auto_sync_enabled';
  static const String _driveLastAutoSyncMsKey = 'drive_last_auto_sync_ms';

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

  Future<void> setDriveAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_driveAutoSyncEnabledKey, enabled);
  }

  Future<bool> isDriveAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_driveAutoSyncEnabledKey) ?? false;
  }

  Future<int> getDriveLastAutoSyncMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_driveLastAutoSyncMsKey) ?? 0;
  }

  Future<void> setDriveLastAutoSyncMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_driveLastAutoSyncMsKey, ms);
  }
}
