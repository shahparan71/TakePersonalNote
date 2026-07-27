import 'package:take_personal_note/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:take_personal_note/services/note_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import 'package:take_personal_note/services/tab_provider.dart';
import 'package:take_personal_note/services/settings_provider.dart';
import 'package:take_personal_note/services/folder_provider.dart';
import 'package:take_personal_note/services/google_drive_sync_service.dart';
import 'package:take_personal_note/services/in_app_update_service.dart';
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
      _checkForAppUpdate();
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

  void _checkForAppUpdate() {
    if (!mounted) return;
    InAppUpdateService().checkAndPromptUpdate(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      Provider.of<NoteProvider>(context, listen: false).cleanOldTrash();
      _triggerDriveAutoSync();
      _checkForAppUpdate();
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
        title: Text(AppLocalizations.of(context)!.newShareReceived),
        content: Text(AppLocalizations.of(context)!.saveTextAsNoteOrTask),
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
            child: Text(AppLocalizations.of(context)!.asNote),
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
            child: Text(AppLocalizations.of(context)!.asTask),
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
    final theme = Theme.of(context);

    final navTabs = [
      GButton(
        icon: Icons.dashboard_outlined,
        text: AppLocalizations.of(context)!.dashboard,
        iconColor: theme.colorScheme.onSurfaceVariant,
        iconActiveColor: theme.colorScheme.primary,
        textColor: theme.colorScheme.primary,
      ),
      GButton(
        icon: Icons.note_alt_outlined,
        text: AppLocalizations.of(context)!.notesTitle,
        iconColor: theme.colorScheme.onSurfaceVariant,
        iconActiveColor: theme.colorScheme.primary,
        textColor: theme.colorScheme.primary,
      ),
      GButton(
        icon: Icons.checklist_outlined,
        text: AppLocalizations.of(context)!.tasks,
        iconColor: theme.colorScheme.onSurfaceVariant,
        iconActiveColor: theme.colorScheme.primary,
        textColor: theme.colorScheme.primary,
      ),
      GButton(
        icon: Icons.calendar_month_outlined,
        text: AppLocalizations.of(context)!.calendar,
        iconColor: theme.colorScheme.onSurfaceVariant,
        iconActiveColor: theme.colorScheme.primary,
        textColor: theme.colorScheme.primary,
      ),
    ];

    return Scaffold(
      backgroundColor: context.appColors.scaffoldBg,
      body: IndexedStack(
        index: tabProvider.selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: GNav(
              selectedIndex: tabProvider.selectedIndex,
              onTabChange: tabProvider.setIndex,
              backgroundColor: theme.colorScheme.surface,
              color: theme.colorScheme.onSurfaceVariant,
              activeColor: theme.colorScheme.primary,
              tabBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              gap: 8,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              tabBorderRadius: 18,
              iconSize: 24,
              tabs: navTabs,
            ),
          ),
        ),
      ),
    );
  }
}
