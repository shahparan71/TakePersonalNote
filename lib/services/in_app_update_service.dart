import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:take_personal_note/services/preference_service.dart';

/// Service that handles Google Play in-app update logic.
///
/// Uses the Play Core library (via `in_app_update` package) to show
/// the native Play Store update dialog. The user can dismiss the
/// flexible update dialog up to 2 times. On the 3rd encounter,
/// an immediate (mandatory) update is triggered.
class InAppUpdateService {
  static final InAppUpdateService _instance = InAppUpdateService._();
  factory InAppUpdateService() => _instance;
  InAppUpdateService._();

  final PreferenceService _prefs = PreferenceService();

  /// Maximum number of times the user can dismiss the flexible update dialog
  /// before the update becomes mandatory (immediate).
  static const int _maxDismissals = 2;

  /// Checks for available updates and prompts the user accordingly.
  ///
  /// Call this from [HomeScreen.initState] or on app resume.
  /// - If dismiss count < [_maxDismissals] → flexible update (dismissible).
  /// - If dismiss count >= [_maxDismissals] → immediate update (mandatory).
  Future<void> checkAndPromptUpdate(BuildContext context) async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      // No update available — nothing to do.
      if (updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      final dismissCount = await _prefs.getUpdateDismissCount();

      if (dismissCount >= _maxDismissals) {
        // User has dismissed twice already — force immediate update.
        await _startImmediateUpdate();
      } else {
        // Show flexible (dismissible) update dialog.
        await _startFlexibleUpdate(context, dismissCount);
      }
    } catch (e) {
      // Silently ignore errors (e.g. Play Store not available, emulator, debug build).
      debugPrint('InAppUpdateService: $e');
    }
  }

  /// Starts an immediate (full-screen, mandatory) update.
  /// The user cannot dismiss this — the app blocks until the update completes.
  Future<void> _startImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
      // After immediate update completes, reset the dismiss counter.
      await _prefs.setUpdateDismissCount(0);
    } catch (e) {
      debugPrint('InAppUpdateService immediate update error: $e');
    }
  }

  /// Starts a flexible (background) update.
  /// Shows the native Play Store bottom-sheet dialog. If the user dismisses
  /// it, the dismiss counter is incremented. If the download completes,
  /// a SnackBar prompts the user to restart.
  Future<void> _startFlexibleUpdate(BuildContext context, int currentDismissCount) async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();

      if (result == AppUpdateResult.success) {
        // Download completed — prompt user to install.
        if (context.mounted) {
          _showUpdateReadySnackBar(context);
        }
      } else {
        // User dismissed or update failed — increment dismiss count.
        await _prefs.setUpdateDismissCount(currentDismissCount + 1);
      }
    } catch (e) {
      // User dismissed the dialog (throws on cancel).
      await _prefs.setUpdateDismissCount(currentDismissCount + 1);
      debugPrint('InAppUpdateService flexible update error: $e');
    }
  }

  /// Shows a SnackBar informing the user that the update has been downloaded
  /// and offering a "Restart" action to complete the installation.
  void _showUpdateReadySnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('An update has been downloaded.'),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'RESTART',
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
              // Reset dismiss count after successful install.
              await _prefs.setUpdateDismissCount(0);
            } catch (e) {
              debugPrint('InAppUpdateService completeFlexibleUpdate error: $e');
            }
          },
        ),
      ),
    );
  }
}
