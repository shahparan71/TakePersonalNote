import 'dart:io';

void main() {
  final dir = Directory('lib/screens');
  final files = dir.listSync(recursive: true).whereType<File>();
  
  final replacements = {
    "'Archive'": "AppLocalizations.of(context)!.archive",
    "'No archived notes'": "AppLocalizations.of(context)!.noArchivedNotes",
    "'Long-press a note and archive it from Notes'": "AppLocalizations.of(context)!.archiveInstruction",
    "'Untitled'": "AppLocalizations.of(context)!.untitled",
    "'Restore'": "AppLocalizations.of(context)!.restore",
    "'Calendar'": "AppLocalizations.of(context)!.calendar",
    "'No tasks for this day'": "AppLocalizations.of(context)!.noTasksForThisDay",
    "'Dashboard'": "AppLocalizations.of(context)!.dashboard",
    "'Good Morning'": "AppLocalizations.of(context)!.goodMorning",
    "'Good Afternoon'": "AppLocalizations.of(context)!.goodAfternoon",
    "'Good Evening'": "AppLocalizations.of(context)!.goodEvening",
    "'Take Notes'": "AppLocalizations.of(context)!.takeNotes",
    "'Overview'": "AppLocalizations.of(context)!.overview",
    "'Notes'": "AppLocalizations.of(context)!.notesTitle",
    "'Pending'": "AppLocalizations.of(context)!.pending",
    "'Pinned'": "AppLocalizations.of(context)!.pinned",
    "'Done'": "AppLocalizations.of(context)!.done",
    "'Upcoming Tasks'": "AppLocalizations.of(context)!.upcomingTasks",
    "'See all'": "AppLocalizations.of(context)!.seeAll",
    "'No notes or tasks yet'": "AppLocalizations.of(context)!.noNotesOrTasksYet",
    "'Your workspace is empty. Restore a previous backup from Google Drive to get your notes back.'": "AppLocalizations.of(context)!.emptyWorkspaceRestore",
    "'Fetching...'": "AppLocalizations.of(context)!.fetching",
    "'Fetch from Google Drive'": "AppLocalizations.of(context)!.fetchFromGoogleDrive",
    "'Drive Sync Active'": "AppLocalizations.of(context)!.driveSyncActive",
    "'You are logged in. All data is automatically synced to Google Drive in real-time.'": "AppLocalizations.of(context)!.driveSyncActiveDesc",
    "'Local data is ready to back up'": "AppLocalizations.of(context)!.localDataReady",
    "'Save your local notes and tasks to Google Drive to keep them safe and synced across your devices.'": "AppLocalizations.of(context)!.saveLocalNotesDesc",
    "'Uploading...'": "AppLocalizations.of(context)!.uploading",
    "'Save to Google Drive'": "AppLocalizations.of(context)!.saveToGoogleDrive",
    "'No upcoming reminders'": "AppLocalizations.of(context)!.noUpcomingReminders",
    "'Hidden Notes'": "AppLocalizations.of(context)!.hiddenNotes",
    "'No hidden notes'": "AppLocalizations.of(context)!.noHiddenNotes",
    "'Notes you hide from the main list appear here. They are not deleted.'": "AppLocalizations.of(context)!.hiddenNotesDesc",
    "'Unhide'": "AppLocalizations.of(context)!.unhide",
    "'App Locked'": "AppLocalizations.of(context)!.appLocked",
    "'Please authenticate to continue'": "AppLocalizations.of(context)!.pleaseAuthenticateToContinue",
    "'Unlock'": "AppLocalizations.of(context)!.unlock",
    "'Add Title'": "AppLocalizations.of(context)!.addTitle",
    "'Start typing your note here...'": "AppLocalizations.of(context)!.startTypingNote",
    "'Note Reminder'": "AppLocalizations.of(context)!.noteReminder",
    "'Repeat'": "AppLocalizations.of(context)!.repeat",
    "'Daily'": "AppLocalizations.of(context)!.daily",
    "'Weekly'": "AppLocalizations.of(context)!.weekly",
    "'Monthly'": "AppLocalizations.of(context)!.monthly",
    "'Custom'": "AppLocalizations.of(context)!.custom",
    "'None'": "AppLocalizations.of(context)!.none",
    "'Search notes...'": "AppLocalizations.of(context)!.searchNotes",
    "'No notes yet. Add one!'": "AppLocalizations.of(context)!.noNotesYet",
    "'No notes in this folder'": "AppLocalizations.of(context)!.noNotesInFolder",
    "'Hidden notes'": "AppLocalizations.of(context)!.hiddenNotesTooltip",
    "'Card view'": "AppLocalizations.of(context)!.cardViewTooltip",
    "'List view'": "AppLocalizations.of(context)!.listViewTooltip",
    "'Sort'": "AppLocalizations.of(context)!.sortTooltip",
    "'All'": "AppLocalizations.of(context)!.all",
    "'New Folder'": "AppLocalizations.of(context)!.newFolderTitle",
    "'Folder name'": "AppLocalizations.of(context)!.folderNameHint",
    "'Create'": "AppLocalizations.of(context)!.create",
    "'Move to folder'": "AppLocalizations.of(context)!.moveToFolder",
    "'Remove from folder'": "AppLocalizations.of(context)!.removeFromFolder",
    "'Delete notes?'": "AppLocalizations.of(context)!.deleteNotesTitle",
    "'Sort by Date'": "AppLocalizations.of(context)!.sortByDate",
    "'Sort by Title'": "AppLocalizations.of(context)!.sortByTitle",
    "'Sort by Color'": "AppLocalizations.of(context)!.sortByColor",
    "'Move'": "AppLocalizations.of(context)!.move",
    "'Pin'": "AppLocalizations.of(context)!.pin",
    "'Hide'": "AppLocalizations.of(context)!.hide",
    "'Delete'": "AppLocalizations.of(context)!.delete",
    "'Cancel'": "AppLocalizations.of(context)!.cancel",
    "'Settings'": "AppLocalizations.of(context)!.settings",
    "'General'": "AppLocalizations.of(context)!.general",
    "'App Language'": "AppLocalizations.of(context)!.appLanguage",
    "'Appearance'": "AppLocalizations.of(context)!.appearance",
    "'Theme Mode'": "AppLocalizations.of(context)!.themeMode",
    "'System'": "AppLocalizations.of(context)!.system",
    "'Light'": "AppLocalizations.of(context)!.light",
    "'Dark'": "AppLocalizations.of(context)!.dark",
    "'Security'": "AppLocalizations.of(context)!.security",
    "'App Lock'": "AppLocalizations.of(context)!.appLock",
    "'Require authentication to open app'": "AppLocalizations.of(context)!.appLockDesc",
    "'Battery Optimization'": "AppLocalizations.of(context)!.batteryOptimization",
    "'Disable to ensure reliable reminders'": "AppLocalizations.of(context)!.batteryOptimizationDesc",
    "'Storage & Backup'": "AppLocalizations.of(context)!.storageBackup",
    "'Sync with Google Drive Backup'": "AppLocalizations.of(context)!.syncDrive",
    "'Working...'": "AppLocalizations.of(context)!.working",
    "'Tap to backup or restore'": "AppLocalizations.of(context)!.tapToBackup",
    "'Auto-sync to Google Drive'": "AppLocalizations.of(context)!.autoSyncDrive",
    "'Automatically backs up notes and tasks when the app opens or resumes (requires sign-in)'": "AppLocalizations.of(context)!.autoSyncDriveDesc",
    "'Export Data'": "AppLocalizations.of(context)!.exportData",
    "'Google Drive Backup'": "AppLocalizations.of(context)!.googleDriveBackup",
    "'Sync to Drive'": "AppLocalizations.of(context)!.syncToDrive",
    "'Sign out'": "AppLocalizations.of(context)!.signOut",
    "'Choose your preferred export format:'": "AppLocalizations.of(context)!.chooseExportFormat",
    "'Tasks'": "AppLocalizations.of(context)!.tasks",
    "'Search tasks...'": "AppLocalizations.of(context)!.searchTasks",
    "'Delete selected'": "AppLocalizations.of(context)!.deleteSelected",
    "'Filter'": "AppLocalizations.of(context)!.filter",
    "'No tasks yet'": "AppLocalizations.of(context)!.noTasksYet",
    "'Completed'": "AppLocalizations.of(context)!.completed",
    "'Filter by Priority'": "AppLocalizations.of(context)!.filterByPriority",
    "'Filter by Status'": "AppLocalizations.of(context)!.filterByStatus",
    "'Clear Filters'": "AppLocalizations.of(context)!.clearFilters",
    "'Delete Task'": "AppLocalizations.of(context)!.deleteTask",
    "'New Task'": "AppLocalizations.of(context)!.newTask",
    "'Edit Task'": "AppLocalizations.of(context)!.editTask",
    "'What needs to be done?'": "AppLocalizations.of(context)!.whatNeedsToBeDone",
    "'Reliable Reminders'": "AppLocalizations.of(context)!.reliableReminders",
    "'To ensure your task reminders fire on time even when the app is closed, please disable battery optimization for this app in your device settings.'": "AppLocalizations.of(context)!.reliableRemindersDesc",
    "'LATER'": "AppLocalizations.of(context)!.later",
    "'SETTINGS'": "AppLocalizations.of(context)!.openSettings",
    "'Task Reminder'": "AppLocalizations.of(context)!.taskReminder",
    "'Custom Repeat'": "AppLocalizations.of(context)!.customRepeat",
    "'Every '": "AppLocalizations.of(context)!.every",
    "'Days'": "AppLocalizations.of(context)!.days",
    "'Weeks'": "AppLocalizations.of(context)!.weeks",
    "'Months'": "AppLocalizations.of(context)!.months",
    "'Trash'": "AppLocalizations.of(context)!.trash",
    "'Trash is empty'": "AppLocalizations.of(context)!.trashIsEmpty",
    "'New Share Received'": "AppLocalizations.of(context)!.newShareReceived",
    "'Would you like to save this text as a Note or a Task?'": "AppLocalizations.of(context)!.saveTextAsNoteOrTask",
    "'AS NOTE'": "AppLocalizations.of(context)!.asNote",
    "'AS TASK'": "AppLocalizations.of(context)!.asTask"
  };
  
  for (var file in files) {
    if (file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      bool changed = false;
      
      for (var entry in replacements.entries) {
        if (content.contains(entry.key)) {
          content = content.replaceAll(entry.key, entry.value);
          changed = true;
        }
      }
      
      // Specifically replace 'New' because it's a very short string that might be part of other things, but here we just replace the exact literal "'New'"
      if (content.contains("'New'")) {
         content = content.replaceAll("'New'", "AppLocalizations.of(context)!.newFolder");
         changed = true;
      }
      
      // Handle the 'All' string exactly
      if (content.contains("'All'")) {
         content = content.replaceAll("'All'", "AppLocalizations.of(context)!.all");
         changed = true;
      }

      if (changed) {
        if (!content.contains("import 'package:flutter_gen/gen_l10n/app_localizations.dart';")) {
          content = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';\n" + content;
        }
        file.writeAsStringSync(content);
        print('Updated \${file.path}');
      }
    }
  }
}
