import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:take_personal_note/services/note_provider.dart';
import 'package:take_personal_note/services/notification_service.dart';
import 'package:take_personal_note/services/settings_provider.dart';
import 'package:take_personal_note/services/task_provider.dart';
import 'package:take_personal_note/theme/app_theme.dart';

import 'screens/lock_screen.dart';
import 'screens/home_screen.dart';
import 'services/preference_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoteProvider()..fetchNotes()),
        ChangeNotifierProvider(create: (_) => TaskProvider()..fetchTasks()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..loadSettings()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Personal Notes & Tasks',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            home: settings.isAppLockEnabled ? const LockScreen() : const HomeScreen(),
          );
        },
      ),
    );
  }
}
