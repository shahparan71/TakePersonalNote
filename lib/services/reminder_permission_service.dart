import 'package:flutter/material.dart';
import 'package:take_personal_note/services/database_service.dart';
import 'package:take_personal_note/services/preference_service.dart';
import 'package:take_personal_note/services/notification_service.dart';

class ReminderPermissionService {
  ReminderPermissionService._();

  static final ReminderPermissionService instance = ReminderPermissionService._();

  final DatabaseService _databaseService = DatabaseService();
  final PreferenceService _preferenceService = PreferenceService();

  Future<bool> hasScheduledTaskReminders() async {
    final tasks = await _databaseService.getAllTasks();
    return tasks.any((task) => task.reminderTime != null);
  }

  Future<bool> shouldShowStartupReminderPrompt() async {
    if (await _preferenceService.isReminderPermissionPromptSeen()) {
      return false;
    }
    return hasScheduledTaskReminders();
  }

  Future<void> markStartupReminderPromptSeen() async {
    await _preferenceService.setReminderPermissionPromptSeen(true);
  }

  Future<bool> showReminderPermissionDialog({
    required BuildContext context,
    required bool hasExistingReminders,
    bool markAsSeen = false,
  }) async {
    final hasPermission = await NotificationService().hasExactAlarmsPermission();
    if (hasPermission) return true;

    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Enable reminders'),
          content: Text(
            hasExistingReminders
                ? 'You already have task reminders scheduled. To keep them working, allow “Allow setting alarm” in your device settings.'
                : 'Reminders need permission to show on time. Allow “Allow setting alarm” in your device settings to use this feature.',
          ),
          actions: [
            /*TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),*/
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open settings'),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return false;

    if (markAsSeen) {
      await markStartupReminderPromptSeen();
    }

    if (shouldOpenSettings == true) {
      if (!context.mounted) return false;
      await NotificationService().requestExactAlarmsPermission();
      return true;
    }

    return false;
  }
}
