import 'dart:convert';
import '../models/note.dart';
import '../models/task.dart';
import 'database_service.dart';

class BackupService {
  final DatabaseService _db = DatabaseService();

  Map<String, dynamic> buildBackupPayload(List<Note> notes, List<Task> tasks, {List<String>? folders}) {
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'notes': notes.map((n) => n.toMap()).toList(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      if (folders != null) 'folders': folders,
    };
  }

  String encodeBackup(List<Note> notes, List<Task> tasks, {List<String>? folders}) {
    return jsonEncode(buildBackupPayload(notes, tasks, folders: folders));
  }

  Future<BackupImportResult> importFromJson(String jsonString, {bool merge = true}) async {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final noteMaps = (decoded['notes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final taskMaps = (decoded['tasks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    await _db.importBackupData(notes: noteMaps, tasks: taskMaps, merge: merge);
    return BackupImportResult(
      notesCount: noteMaps.length,
      tasksCount: taskMaps.length,
      folders: (decoded['folders'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Future<String> exportAllToJson({List<String>? folders}) async {
    final notes = await _db.getAllNotes();
    final tasks = await _db.getAllTasks();
    return encodeBackup(notes, tasks, folders: folders);
  }
}

class BackupImportResult {
  final int notesCount;
  final int tasksCount;
  final List<String> folders;

  BackupImportResult({required this.notesCount, required this.tasksCount, this.folders = const []});
}
