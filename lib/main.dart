import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:take_personal_note/firebase_options.dart';
import 'package:take_personal_note/services/note_provider.dart';
import 'package:take_personal_note/services/notification_service.dart';
import 'package:take_personal_note/services/settings_provider.dart';
import 'package:take_personal_note/services/task_provider.dart';
import 'package:take_personal_note/services/tab_provider.dart';
import 'package:take_personal_note/services/folder_provider.dart';
import 'package:take_personal_note/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'screens/lock_screen.dart';
import 'screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().init();
  await NotificationService().rescheduleAllReminders();

  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  runApp(MyApp(settingsProvider: settingsProvider));
}

class MyApp extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const MyApp({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoteProvider()..fetchNotes()),
        ChangeNotifierProvider(create: (_) => TaskProvider()..fetchTasks()),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => TabProvider()),
        ChangeNotifierProvider(create: (_) => FolderProvider()..loadFolders()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Take Notes',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
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
