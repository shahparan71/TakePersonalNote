import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:take_personal_note/services/note_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import 'package:take_personal_note/services/tab_provider.dart';
import 'package:take_personal_note/services/settings_provider.dart';
import 'package:take_personal_note/services/folder_provider.dart';
import 'package:take_personal_note/services/google_drive_sync_service.dart';
import 'dashboard_screen.dart';
import 'notes_screen.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'note_edit_screen.dart';
import 'task_edit_screen.dart';
import 'package:take_personal_note/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late StreamSubscription _intentDataStreamSubscription;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerDriveAutoSync();
    }
  }

  void _triggerDriveAutoSync() {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final folders = Provider.of<FolderProvider>(context, listen: false).folders;
    GoogleDriveSyncService().runAutoSyncIfEnabled(
      enabled: settings.isDriveAutoSyncEnabled,
      folders: folders,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      Provider.of<NoteProvider>(context, listen: false).cleanOldTrash();
      _triggerDriveAutoSync();
    });

    // For sharing or opening app from timeout..
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _handleSharedText(value.first.path);
      }
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleSharedText(value.first.path);
      }
    });
  }

  void _handleSharedText(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Share Received'),
        content: const Text('Would you like to save this text as a Note or a Task?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NoteEditScreen(initialText: text),
                ),
              );
            },
            child: const Text('AS NOTE'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskEditScreen(initialText: text),
                ),
              );
            },
            child: const Text('AS TASK'),
          ),
        ],
      ),
    );
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const NotesScreen(),
    const TasksScreen(),
    const CalendarScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final tabProvider = Provider.of<TabProvider>(context);

    return Scaffold(
      backgroundColor: context.appColors.scaffoldBg,
      body: IndexedStack(
        index: tabProvider.selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabProvider.selectedIndex,
        onDestinationSelected: (index) {
          tabProvider.setIndex(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}
