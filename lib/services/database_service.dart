import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/note.dart';
import '../models/task.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'personal_notes_tasks.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE notes ADD COLUMN isHidden INTEGER DEFAULT 0');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        type INTEGER,
        category TEXT,
        color INTEGER,
        isPinned INTEGER,
        isArchived INTEGER,
        isTrashed INTEGER,
        isHidden INTEGER DEFAULT 0,
        reminderTime TEXT,
        isRecurring INTEGER,
        recurringInterval INTEGER,
        createdAt TEXT,
        updatedAt TEXT,
        deletedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        description TEXT,
        startTime TEXT,
        expiryTime TEXT,
        reminderTime TEXT,
        priority INTEGER,
        status INTEGER,
        isRecurring INTEGER,
        recurringInterval INTEGER,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');
  }

  // Note CRUD
  Future<int> insertNote(Note note) async {
    final db = await database;
    return await db.insert('notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Note>> getNotes({String? query, String? category, int? color, String? orderBy}) async {
    final db = await database;
    String where = 'isTrashed = 0 AND isArchived = 0 AND isHidden = 0';
    List<dynamic> whereArgs = [];

    if (query != null && query.isNotEmpty) {
      where += ' AND (title LIKE ? OR content LIKE ?)';
      whereArgs.addAll(['%$query%', '%$query%']);
    }
    if (category != null) {
      where += ' AND category = ?';
      whereArgs.add(category);
    }
    if (color != null) {
      where += ' AND color = ?';
      whereArgs.add(color);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy ?? 'isPinned DESC, updatedAt DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<List<Note>> getHiddenNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'isHidden = 1 AND isTrashed = 0 AND isArchived = 0',
      orderBy: 'updatedAt DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<List<Note>> getArchivedNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notes', where: 'isArchived = 1 AND isTrashed = 0');
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<List<Note>> getTrashedNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notes', where: 'isTrashed = 1');
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNotePermanent(int id) async {
    final db = await database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<String>> getNoteCategories() async {
    final db = await database;
    final maps = await db.rawQuery(
      "SELECT DISTINCT category FROM notes WHERE isTrashed = 0 AND isArchived = 0 AND category IS NOT NULL AND category != ''",
    );
    return maps.map((m) => m['category'] as String).toList();
  }

  Future<void> clearCategoryFromNotes(String category) async {
    final db = await database;
    await db.update(
      'notes',
      {'category': null},
      where: 'category = ?',
      whereArgs: [category],
    );
  }

  Future<Note?> getNoteById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Note.fromMap(maps.first);
    return null;
  }

  // Task CRUD
  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Task>> getTasks({String? query, TaskPriority? priority, TaskStatus? status, String? orderBy}) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (query != null && query.isNotEmpty) {
      where += ' AND (title LIKE ? OR description LIKE ?)';
      whereArgs.addAll(['%$query%', '%$query%']);
    }
    if (priority != null) {
      where += ' AND priority = ?';
      whereArgs.add(priority.index);
    }
    if (status != null) {
      where += ' AND status = ?';
      whereArgs.add(status.index);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy ?? 'priority DESC, updatedAt DESC',
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Task?> getTaskById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Task.fromMap(maps.first);
    return null;
  }

  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final maps = await db.query('notes', orderBy: 'updatedAt DESC');
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final maps = await db.query('tasks', orderBy: 'updatedAt DESC');
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<void> importBackupData({
    required List<Map<String, dynamic>> notes,
    required List<Map<String, dynamic>> tasks,
    bool merge = true,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      if (!merge) {
        await txn.delete('notes');
        await txn.delete('tasks');
      }
      for (final map in notes) {
        final data = Map<String, dynamic>.from(map);
        data.remove('id');
        await txn.insert('notes', data, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final map in tasks) {
        final data = Map<String, dynamic>.from(map);
        data.remove('id');
        await txn.insert('tasks', data, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
