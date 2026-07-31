import 'package:flutter/material.dart';
import 'package:take_personal_note/models/note.dart';
import 'database_service.dart';
import 'google_drive_sync_service.dart';
import 'preference_service.dart';

class NoteProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  List<MyNote> _notes = [];
  List<MyNote> _archivedNotes = [];
  List<MyNote> _trashedNotes = [];
  List<MyNote> _hiddenNotes = [];

  List<MyNote> get notes => _notes;
  List<MyNote> get archivedNotes => _archivedNotes;
  List<MyNote> get trashedNotes => _trashedNotes;
  List<MyNote> get hiddenNotes => _hiddenNotes;

  Future<void> fetchNotes({String? query, String? category, int? color, String? orderBy}) async {
    _notes = await _dbService.getNotes(query: query, category: category, color: color, orderBy: orderBy);
    _archivedNotes = await _dbService.getArchivedNotes();
    _trashedNotes = await _dbService.getTrashedNotes();
    _hiddenNotes = await _dbService.getHiddenNotes();
    notifyListeners();
  }

  Future<int?> addNote(MyNote note) async {
    final id = await _dbService.insertNote(note);    await PreferenceService().setNotesPendingDriveSync(true);    await fetchNotes();
    _triggerSyncIfSignedIn();
    return id;
  }

  Future<void> updateNote(MyNote note) async {
    await _dbService.updateNote(note);
    await PreferenceService().setNotesPendingDriveSync(true);
    await fetchNotes();
    _triggerSyncIfSignedIn();
  }

  Future<void> archiveNote(MyNote note) async {
    final archivedNote = note.copyWith(isArchived: true, isPinned: false);
    await _dbService.updateNote(archivedNote);
    await PreferenceService().setNotesPendingDriveSync(true);
    await fetchNotes();
    _triggerSyncIfSignedIn();
  }

  Future<void> unarchiveNote(MyNote note) async {
    final unarchivedNote = note.copyWith(isArchived: false);
    await _dbService.updateNote(unarchivedNote);
    await PreferenceService().setNotesPendingDriveSync(true);
    await fetchNotes();
    _triggerSyncIfSignedIn();
  }

  Future<void> trashNote(MyNote note) async {
    final trashedNote = note.copyWith(
      isTrashed: true,
      isPinned: false,
      isArchived: false,
      deletedAt: DateTime.now(),
    );
    await _dbService.updateNote(trashedNote);
    await PreferenceService().setNotesPendingDriveSync(true);
    await fetchNotes();
    _triggerSyncIfSignedIn();
  }

  Future<void> restoreNote(MyNote note) async {
    final restoredNote = note.copyWith(isTrashed: false, deletedAt: null);
    await _dbService.updateNote(restoredNote);
    await PreferenceService().setNotesPendingDriveSync(true);
    await fetchNotes();
    _triggerSyncIfSignedIn();
  }

  Future<void> deleteNotePermanent(int id) async {
    await _dbService.deleteNotePermanent(id);
    await PreferenceService().setNotesPendingDriveSync(true);
    await fetchNotes();
    _triggerSyncIfSignedIn();
  }

  Future<List<String>> getCategories() async {
    return _dbService.getNoteCategories();
  }

  Future<void> hideNote(MyNote note) async {
    await updateNote(note.copyWith(isHidden: true, isPinned: false));
  }

  Future<void> unhideNote(MyNote note) async {
    await updateNote(note.copyWith(isHidden: false));
  }

  Future<void> refreshAll() async {
    await fetchNotes();
  }

  void _triggerSyncIfSignedIn() async {
    if (GoogleDriveSyncService().isSignedIn) {
      await GoogleDriveSyncService().syncToDrive();
    }
  }

  Future<void> cleanOldTrash() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    _trashedNotes.where((n) => n.deletedAt != null && n.deletedAt!.isBefore(thirtyDaysAgo)).forEach((n) async {
      await _dbService.deleteNotePermanent(n.id!);
    });
    await fetchNotes();
  }
}
