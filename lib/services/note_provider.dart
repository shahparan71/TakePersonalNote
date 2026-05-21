import 'package:flutter/material.dart';
import '../models/note.dart';
import 'database_service.dart';

class NoteProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  List<Note> _notes = [];
  List<Note> _archivedNotes = [];
  List<Note> _trashedNotes = [];

  List<Note> get notes => _notes;
  List<Note> get archivedNotes => _archivedNotes;
  List<Note> get trashedNotes => _trashedNotes;

  Future<void> fetchNotes({String? query, String? category, int? color, String? orderBy}) async {
    _notes = await _dbService.getNotes(query: query, category: category, color: color, orderBy: orderBy);
    _archivedNotes = await _dbService.getArchivedNotes();
    _trashedNotes = await _dbService.getTrashedNotes();
    notifyListeners();
  }

  Future<int?> addNote(Note note) async {
    final id = await _dbService.insertNote(note);
    await fetchNotes();
    return id;
  }

  Future<void> updateNote(Note note) async {
    await _dbService.updateNote(note);
    await fetchNotes();
  }

  Future<void> archiveNote(Note note) async {
    final archivedNote = note.copyWith(isArchived: true, isPinned: false);
    await _dbService.updateNote(archivedNote);
    await fetchNotes();
  }

  Future<void> unarchiveNote(Note note) async {
    final unarchivedNote = note.copyWith(isArchived: false);
    await _dbService.updateNote(unarchivedNote);
    await fetchNotes();
  }

  Future<void> trashNote(Note note) async {
    final trashedNote = note.copyWith(
      isTrashed: true,
      isPinned: false,
      isArchived: false,
      deletedAt: DateTime.now(),
    );
    await _dbService.updateNote(trashedNote);
    await fetchNotes();
  }

  Future<void> restoreNote(Note note) async {
    final restoredNote = note.copyWith(isTrashed: false, deletedAt: null);
    await _dbService.updateNote(restoredNote);
    await fetchNotes();
  }

  Future<void> deleteNotePermanent(int id) async {
    await _dbService.deleteNotePermanent(id);
    await fetchNotes();
  }

  Future<List<String>> getCategories() async {
    return _dbService.getNoteCategories();
  }

  Future<void> hideNote(Note note) async {
    await updateNote(note.copyWith(isHidden: true, isPinned: false));
  }

  Future<void> unhideNote(Note note) async {
    await updateNote(note.copyWith(isHidden: false));
  }

  Future<void> refreshAll() async {
    await fetchNotes();
  }

  Future<void> cleanOldTrash() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    _trashedNotes.where((n) => n.deletedAt != null && n.deletedAt!.isBefore(thirtyDaysAgo)).forEach((n) async {
      await _dbService.deleteNotePermanent(n.id!);
    });
    await fetchNotes();
  }
}
