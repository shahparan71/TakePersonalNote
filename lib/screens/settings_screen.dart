import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/note_provider.dart';
import '../services/task_provider.dart';
import '../services/folder_provider.dart';
import '../services/settings_provider.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../services/google_drive_sync_service.dart';
import '../theme/app_colors.dart';
import '../widgets/sheet_safe_area.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _driveBusy = false;
  String? _driveUser;

  @override
  void initState() {
    super.initState();
    _driveUser = GoogleDriveSyncService().currentUser?.email;
  }

  Future<void> _runDriveAction(Future<GoogleDriveSyncResult> Function() action) async {
    setState(() => _driveBusy = true);
    final result = await action();
    if (!mounted) return;
    setState(() {
      _driveBusy = false;
      _driveUser = GoogleDriveSyncService().currentUser?.email;
    });
    if (result.success) {
      await Provider.of<NoteProvider>(context, listen: false).refreshAll();
      await Provider.of<TaskProvider>(context, listen: false).refreshAll();
      for (final f in result.folders) {
        await Provider.of<FolderProvider>(context, listen: false).addFolder(f);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  void _openDriveBackupSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SheetSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text('Google Drive Backup', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _driveUser ?? 'Not signed in',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (_driveUser == null)
              FilledButton.icon(
                onPressed: _driveBusy
                    ? null
                    : () async {
                        setState(() => _driveBusy = true);
                        await GoogleDriveSyncService().signIn();
                        if (!mounted) return;
                        setState(() {
                          _driveBusy = false;
                          _driveUser = GoogleDriveSyncService().currentUser?.email;
                        });
                        final err = GoogleDriveSyncService().lastAuthError;
                        if (_driveUser == null && err != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.fabDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            if (_driveUser == null) const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _driveBusy
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      final folders = Provider.of<FolderProvider>(context, listen: false).folders;
                      _runDriveAction(() => GoogleDriveSyncService().syncToDrive(folders: folders));
                    },
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Sync to Drive'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.fabDark, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _driveBusy
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _showFetchConfirm(merge: true);
                    },
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Fetch from Drive (merge)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _driveBusy
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _showFetchConfirm(merge: false);
                    },
              icon: const Icon(Icons.restore),
              label: const Text('Fetch from Drive (replace)'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.actionDelete),
            ),
            if (_driveUser != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  await GoogleDriveSyncService().signOut();
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() => _driveUser = null);
                },
                child: const Text('Sign out'),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  void _showFetchConfirm({required bool merge}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(merge ? 'Merge backup?' : 'Replace all data?'),
        content: Text(
          merge
              ? 'Notes and tasks from Drive will be added to your existing data.'
              : 'This will replace all local notes and tasks with the Drive backup.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runDriveAction(() => GoogleDriveSyncService().fetchFromDrive(merge: merge));
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showExportOptions() {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final exportService = ExportService();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Choose your preferred export format:'),
        actions: [
          TextButton(
            child: const Text('JSON'),
            onPressed: () {
              Navigator.pop(context);
              exportService.exportToJSON(noteProvider.notes, taskProvider.tasks);
            },
          ),
          TextButton(
            child: const Text('TEXT'),
            onPressed: () {
              Navigator.pop(context);
              exportService.exportToText(noteProvider.notes, taskProvider.tasks);
            },
          ),
          TextButton(
            child: const Text('PDF'),
            onPressed: () {
              Navigator.pop(context);
              exportService.exportToPDF(noteProvider.notes, taskProvider.tasks);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        title: Text('Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            children: [
              const _SettingsSection(title: 'General'),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('App Language'),
                trailing: const Text('English'),
                onTap: () {},
              ),
              const Divider(height: 1),
              const _SettingsSection(title: 'Appearance'),
              ListTile(
                leading: const Icon(Icons.brightness_4),
                title: const Text('Theme Mode'),
                trailing: DropdownButton<String>(
                  value: settings.themeModeString,
                  onChanged: (val) => settings.setThemeMode(val!),
                  items: const [
                    DropdownMenuItem(value: 'system', child: Text('System')),
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Test Notification'),
                subtitle: const Text('Check if reminders are working'),
                onTap: () async {
                  await NotificationService().showTestNotification(
                    title: 'Test Reminder',
                    body: 'If you see this, notifications are correctly configured!',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test notification sent!')),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              const _SettingsSection(title: 'Security'),
              SwitchListTile(
                secondary: const Icon(Icons.security),
                title: const Text('App Lock'),
                subtitle: const Text('Require authentication to open app'),
                value: settings.isAppLockEnabled,
                onChanged: settings.toggleAppLock,
              ),
              const Divider(height: 1),
              const _SettingsSection(title: 'Storage & Backup'),
              ListTile(
                leading: Icon(Icons.cloud, color: AppColors.fabDark),
                title: const Text('Sync with Google Drive Backup'),
                subtitle: Text(
                  _driveBusy
                      ? 'Working...'
                      : (_driveUser ?? 'Sign in to backup or restore'),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: _driveBusy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
                onTap: _driveBusy ? null : _openDriveBackupSheet,
              ),
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Export Data'),
                onTap: _showExportOptions,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  const _SettingsSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(color: AppColors.fabDark, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
