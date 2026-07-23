import 'package:take_personal_note/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
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
import '../utils/drive_sync_utils.dart';
import '../services/battery_optimization_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _driveBusy = false;
  String? _driveUser;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _refreshDriveUser();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'Version ${packageInfo.version}.${packageInfo.buildNumber}';
      });
    }
  }

  void _refreshDriveUser() {
    _driveUser = GoogleDriveSyncService().currentUser?.email;
  }

  Future<void> _runDriveAction(Future<GoogleDriveSyncResult> Function() action) async {
    setState(() => _driveBusy = true);
    final result = await action();
    if (!mounted) return;
    setState(() {
      _driveBusy = false;
      _refreshDriveUser();
    });
    await applyDriveSyncResult(context, result);
    if (!mounted) return;
    showDriveSyncSnackBar(context, result);
  }

  void _openDriveBackupSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final colors = ctx.appColors;
        return SheetSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppLocalizations.of(context)!.googleDriveBackup, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                _driveUser ?? 'Not signed in — you will be asked to sign in when syncing',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _driveBusy
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        final folders = Provider.of<FolderProvider>(context, listen: false).folders;
                        _runDriveAction(() => GoogleDriveSyncService().syncToDrive(folders: folders));
                      },
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(AppLocalizations.of(context)!.syncToDrive),
                style: FilledButton.styleFrom(backgroundColor: colors.fabDark, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _driveBusy
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        confirmFetchFromDrive(
                          context,
                          onConfirm: () => _runDriveAction(
                            () => GoogleDriveSyncService().fetchFromDrive(merge: true),
                          ),
                        );
                      },
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Fetch from Drive'),
              ),
              if (_driveUser != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    await GoogleDriveSyncService().signOut();
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() => _driveUser = null);
                  },
                  child: Text(AppLocalizations.of(context)!.signOut),
                ),
              ],
            ],
          ),
        ),
      );
      },
    );
  }

  void _showExportOptions() {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final exportService = ExportService();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.exportData),
        content: Text(AppLocalizations.of(context)!.chooseExportFormat),
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
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.scaffoldBg,
        title: Text(AppLocalizations.of(context)!.settings, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: colors.textPrimary)),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            children: [
              _SettingsSection(title: AppLocalizations.of(context)!.general),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(AppLocalizations.of(context)!.appLanguage),
                trailing: DropdownButton<String>(
                  value: settings.locale.languageCode,
                  onChanged: (val) {
                    if (val != null) settings.setLocale(val);
                  },
                  items: [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'fr', child: Text('Français')),
                  ],
                ),
              ),
              const Divider(height: 1),
              _SettingsSection(title: AppLocalizations.of(context)!.appearance),
              ListTile(
                leading: const Icon(Icons.brightness_4),
                title: Text(AppLocalizations.of(context)!.themeMode),
                trailing: DropdownButton<String>(
                  value: settings.themeModeString,
                  onChanged: (val) => settings.setThemeMode(val!),
                  items: [
                    DropdownMenuItem(value: 'system', child: Text(AppLocalizations.of(context)!.system)),
                    DropdownMenuItem(value: 'light', child: Text(AppLocalizations.of(context)!.light)),
                    DropdownMenuItem(value: 'dark', child: Text(AppLocalizations.of(context)!.dark)),
                    const DropdownMenuItem(value: 'eye_warming', child: Text('Eye Warming')),
                  ],
                ),
              ),
              /*if (kDebugMode)
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
                ),*/
              const Divider(height: 1),
              _SettingsSection(title: AppLocalizations.of(context)!.security),
              SwitchListTile(
                secondary: const Icon(Icons.security),
                title: Text(AppLocalizations.of(context)!.appLock),
                subtitle: Text(AppLocalizations.of(context)!.appLockDesc),
                value: settings.isAppLockEnabled,
                onChanged: settings.toggleAppLock,
              ),
              ListTile(
                leading: const Icon(Icons.battery_alert),
                title: Text(AppLocalizations.of(context)!.batteryOptimization),
                subtitle: Text(AppLocalizations.of(context)!.batteryOptimizationDesc),
                onTap: () async {
                  await BatteryOptimizationService.openBatteryOptimizationSettings();
                },
              ),
              const Divider(height: 1),
              _SettingsSection(title: AppLocalizations.of(context)!.storageBackup),
              ListTile(
                leading: Icon(Icons.cloud, color: colors.fabDark),
                title: Text(AppLocalizations.of(context)!.syncDrive),
                subtitle: Text(
                  _driveBusy
                      ? AppLocalizations.of(context)!.working
                      : (_driveUser ?? AppLocalizations.of(context)!.tapToBackup),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: _driveBusy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
                onTap: _driveBusy ? null : _openDriveBackupSheet,
              ),
              /*SwitchListTile(
                secondary: Icon(Icons.sync, color: colors.fabDark),
                title: Text(AppLocalizations.of(context)!.autoSyncDrive),
                subtitle: Text(
                  AppLocalizations.of(context)!.autoSyncDriveDesc,
                ),
                value: settings.isDriveAutoSyncEnabled,
                onChanged: settings.toggleDriveAutoSync,
              ),*/
              ListTile(
                leading: const Icon(Icons.file_download),
                title: Text(AppLocalizations.of(context)!.exportData),
                onTap: _showExportOptions,
              ),
              const SizedBox(height: 16),
              if (_appVersion.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32.0),
                    child: Text(
                      _appVersion,
                      style: GoogleFonts.outfit(color: colors.textSecondary, fontSize: 13),
                    ),
                  ),
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
        style: GoogleFonts.outfit(color: context.appColors.fabDark, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
