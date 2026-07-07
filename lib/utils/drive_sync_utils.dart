import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/folder_provider.dart';
import '../services/google_drive_sync_service.dart';
import '../services/note_provider.dart';
import '../services/preference_service.dart';
import '../services/task_provider.dart';

bool shouldShowLocalBackupBanner({
  required int noteCount,
  required int taskCount,
  required bool notesPendingSync,
  required bool tasksPendingSync,
}) {
  return (noteCount > 0 || taskCount > 0) && (notesPendingSync || tasksPendingSync);
}

Future<void> applyDriveSyncResult(BuildContext context, GoogleDriveSyncResult result) async {
  if (!result.success) return;
  await Provider.of<NoteProvider>(context, listen: false).refreshAll();
  await Provider.of<TaskProvider>(context, listen: false).refreshAll();
  for (final folder in result.folders) {
    await Provider.of<FolderProvider>(context, listen: false).addFolder(folder);
  }
}

void showDriveSyncSnackBar(BuildContext context, GoogleDriveSyncResult result) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
}

Future<void> confirmFetchFromDrive(BuildContext context, {required VoidCallback onConfirm}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Fetch from Drive?'),
      content: const Text(
        'Notes and tasks from your Google Drive backup will be merged with your existing data.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}
