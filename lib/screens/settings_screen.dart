import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../services/note_provider.dart';
import '../services/task_provider.dart';
import '../services/preference_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAppLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final enabled = await PreferenceService().isAppLockEnabled();
    setState(() => _isAppLockEnabled = enabled);
  }

  Future<void> _toggleAppLock(bool value) async {
    await PreferenceService().setAppLockEnabled(value);
    setState(() => _isAppLockEnabled = value);
  }

  void _exportData() {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    final data = {
      'notes': noteProvider.notes.map((n) => n.toMap()).toList(),
      'tasks': taskProvider.tasks.map((t) => t.toMap()).toList(),
    };

    final jsonString = jsonEncode(data);
    Share.share(jsonString, subject: 'My Personal Notes & Tasks Export');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SettingsSection(title: 'General'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('App Language'),
            trailing: const Text('English'),
            onTap: () {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.flash_on),
            title: const Text('Autosave'),
            value: true,
            onChanged: (val) {},
          ),
          const Divider(),
          const _SettingsSection(title: 'Security'),
          SwitchListTile(
            secondary: const Icon(Icons.security),
            title: const Text('App Lock'),
            subtitle: const Text('Require authentication to open app'),
            value: _isAppLockEnabled,
            onChanged: _toggleAppLock,
          ),
          const Divider(),
          const _SettingsSection(title: 'Storage & Backup'),
          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: const Text('Sync with Google Drive'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Export Data'),
            onTap: _exportData,
          ),
        ],
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
