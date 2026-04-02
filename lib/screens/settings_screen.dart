import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../services/note_provider.dart';
import '../services/task_provider.dart';
import '../services/settings_provider.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
      appBar: AppBar(title: const Text('Settings')),
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
              const Divider(),
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
              const Divider(),
              const _SettingsSection(title: 'Security'),
              SwitchListTile(
                secondary: const Icon(Icons.security),
                title: const Text('App Lock'),
                subtitle: const Text('Require authentication to open app'),
                value: settings.isAppLockEnabled,
                onChanged: settings.toggleAppLock,
              ),
              const Divider(),
              const _SettingsSection(title: 'Storage & Backup'),
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('Sync with Google Drive Backup'),
                onTap: () {},
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
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
