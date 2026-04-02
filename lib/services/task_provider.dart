import 'package:flutter/material.dart';
import '../models/task.dart';
import 'database_service.dart';

class TaskProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  List<Task> _tasks = [];

  List<Task> get tasks => _tasks;

  Future<void> fetchTasks({String? query, TaskPriority? priority, TaskStatus? status, String? orderBy}) async {
    _tasks = await _dbService.getTasks(query: query, priority: priority, status: status, orderBy: orderBy);
    notifyListeners();
  }

  Future<int?> addTask(Task task) async {
    final id = await _dbService.insertTask(task);
    await fetchTasks();
    return id;
  }

  Future<void> updateTask(Task task) async {
    await _dbService.updateTask(task);
    await fetchTasks();
  }

  Future<void> deleteTask(int id) async {
    await _dbService.deleteTask(id);
    await fetchTasks();
  }

  List<Task> getTasksByStatus(TaskStatus status) {
    return _tasks.where((task) => task.status == status).toList();
  }

  List<Task> getTasksByPriority(TaskPriority priority) {
    return _tasks.where((task) => task.priority == priority).toList();
  }
}
