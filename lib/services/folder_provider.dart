import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FolderProvider with ChangeNotifier {
  static const String _foldersKey = 'note_folders';
  List<String> _folders = [];

  List<String> get folders => List.unmodifiable(_folders);

  Future<void> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    _folders = prefs.getStringList(_foldersKey) ?? [];
    notifyListeners();
  }

  Future<void> addFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _folders.contains(trimmed)) return;
    _folders = [..._folders, trimmed];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_foldersKey, _folders);
    notifyListeners();
  }

  Future<void> renameFolder(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    final index = _folders.indexOf(oldName);
    if (index == -1) return;
    _folders = List.from(_folders)..[index] = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_foldersKey, _folders);
    notifyListeners();
  }

  Future<void> deleteFolder(String name) async {
    _folders = _folders.where((f) => f != name).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_foldersKey, _folders);
    notifyListeners();
  }
}
