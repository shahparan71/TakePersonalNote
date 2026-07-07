import 'package:flutter/material.dart';
import '../models/task.dart';
import 'database_service.dart';
import 'google_drive_sync_service.dart';
import 'notification_service.dart';
import 'preference_service.dart';

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
    await PreferenceService().setTasksPendingDriveSync(true);
    await fetchTasks();
    await _syncDriveIfSignedIn();
    return id;
  }

  Future<void> updateTask(Task task) async {
    await _dbService.updateTask(task);
    await PreferenceService().setTasksPendingDriveSync(true);
    await fetchTasks();
    await _syncDriveIfSignedIn();
  }

  Future<void> deleteTask(int id) async {
    // Cancel any scheduled notification for this task (notifications
    // for tasks use id + 10000 as the notification id).
    try {
      await NotificationService().cancelNotification(id + 10000);
    } catch (_) {}
    await _dbService.deleteTask(id);
    await PreferenceService().setTasksPendingDriveSync(true);
    await fetchTasks();
    await _syncDriveIfSignedIn();
  }

  Future<void> deleteTasks(List<int> ids) async {
    for (final id in ids) {
      try {
        await NotificationService().cancelNotification(id + 10000);
      } catch (_) {}
      await _dbService.deleteTask(id);
    }
    await PreferenceService().setTasksPendingDriveSync(true);
    await fetchTasks();
    await _syncDriveIfSignedIn();
  }

  List<Task> getTasksByStatus(TaskStatus status) {
    return _tasks.where((task) => task.status == status).toList();
  }

  List<Task> getTasksByPriority(TaskPriority priority) {
    return _tasks.where((task) => task.priority == priority).toList();
  }

  Future<void> refreshAll() async {
    await fetchTasks();
  }

  Future<void> _syncDriveIfSignedIn() async {
    if (GoogleDriveSyncService().isSignedIn) {
      await GoogleDriveSyncService().syncToDrive();
    }
  }
}
