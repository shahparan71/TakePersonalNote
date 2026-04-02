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
      version: 1,
      onCreate: _onCreate,
    );
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
    String where = 'isTrashed = 0 AND isArchived = 0';
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

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
