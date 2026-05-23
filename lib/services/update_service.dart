import 'package:in_app_update/in_app_update.dart';
import 'package:flutter/foundation.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  AppUpdateInfo? _updateInfo;

  /// Checks if an update is available on the Play Store.
  /// Returns true if an update is available.
  Future<bool> checkForUpdate() async {
    try {
      _updateInfo = await InAppUpdate.checkForUpdate();
      return _updateInfo?.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (e) {
      debugPrint('Update check failed: $e');
      return false;
    }
  }

  /// Starts a flexible update flow (download in background).
  /// Returns true if the update was started successfully.
  Future<bool> startFlexibleUpdate() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      return result == AppUpdateResult.success;
    } catch (e) {
      debugPrint('Flexible update failed: $e');
      return false;
    }
  }

  /// Completes the flexible update (installs the downloaded update).
  Future<void> completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('Complete update failed: $e');
    }
  }

  /// Starts an immediate update flow (blocking full-screen).
  Future<bool> startImmediateUpdate() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      return result == AppUpdateResult.success;
    } catch (e) {
      debugPrint('Immediate update failed: $e');
      return false;
    }
  }
}
