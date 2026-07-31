import 'package:flutter/material.dart';
import '../models/note.dart';
import '../models/task.dart';
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/note_edit_screen.dart';
import '../screens/task_edit_screen.dart';
import '../screens/archive_screen.dart';
import '../screens/trash_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/hidden_notes_screen.dart';
import '../screens/lock_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String noteEdit = '/noteEdit';
  static const String taskEdit = '/taskEdit';
  static const String archive = '/archive';
  static const String trash = '/trash';
  static const String settings_screen = '/settings';
  static const String hiddenNotes = '/hiddenNotes';
  static const String lock = '/lock';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case noteEdit:
        final args = settings.arguments as Map<String, dynamic>?;
        final Note? note = args?['note'];
        final String? initialText = args?['initialText'];
        return MaterialPageRoute(builder: (_) => NoteEditScreen(note: note, initialText: initialText));
      case taskEdit:
        final args = settings.arguments as Map<String, dynamic>?;
        final Task? task = args?['task'];
        final String? initialText = args?['initialText'];
        return MaterialPageRoute(builder: (_) => TaskEditScreen(task: task, initialText: initialText));
      case archive:
        return MaterialPageRoute(builder: (_) => const ArchiveScreen());
      case trash:
        return MaterialPageRoute(builder: (_) => const TrashScreen());
      case settings_screen:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case hiddenNotes:
        return MaterialPageRoute(builder: (_) => const HiddenNotesScreen());
      case lock:
        return MaterialPageRoute(builder: (_) => const LockScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
