import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:take_personal_note/services/task_provider.dart';

import '../models/task.dart';
import 'task_edit_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search tasks...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, size: 20),
          ),
          onChanged: (val) {
            Provider.of<TaskProvider>(context, listen: false).fetchTasks(query: val);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
            tooltip: 'Filter Tasks',
          ),
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          if (provider.tasks.isEmpty) {
            return const Center(child: Text('No tasks yet. Create one!'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.tasks.length,
            itemBuilder: (context, index) {
              final task = provider.tasks[index];
              return _buildTaskTile(context, task);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tasks_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskEditScreen()),
        ),
        child: const Icon(Icons.add_task),
      ),
    );
  }

  Widget _buildTaskTile(BuildContext context, Task task) {
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskEditScreen(task: task)),
        ),
        onLongPress: () => _showQuickActions(context, task),
        title: Text(task.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Text(task.description, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (task.reminderTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.alarm, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'Reminder: ${DateFormat('MMM d, h:mm a').format(task.reminderTime!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: _buildPriorityChip(task.priority),
        leading: Checkbox(
          value: task.status == TaskStatus.completed,
          onChanged: (val) {
            final updatedTask = task.copyWith(
              status: val! ? TaskStatus.completed : TaskStatus.pending,
            );
            Provider.of<TaskProvider>(context, listen: false).updateTask(updatedTask);
          },
        ),
      ),
    );
  }

  Widget _buildPriorityChip(TaskPriority priority) {
    Color color;
    switch (priority) {
      case TaskPriority.low:
        color = Colors.green;
        break;
      case TaskPriority.medium:
        color = Colors.orange;
        break;
      case TaskPriority.high:
        color = Colors.red;
        break;
    }
    return Chip(
      label: Text(priority.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }
  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Filter by Priority', style: TextStyle(fontWeight: FontWeight.bold))),
            ...TaskPriority.values.map((p) => ListTile(
              title: Text(p.name.toUpperCase()),
              onTap: () {
                Provider.of<TaskProvider>(context, listen: false).fetchTasks(priority: p);
                Navigator.pop(context);
              },
            )),
            const Divider(),
            const ListTile(title: Text('Filter by Status', style: TextStyle(fontWeight: FontWeight.bold))),
            ...TaskStatus.values.map((s) => ListTile(
              title: Text(s.name.toUpperCase()),
              onTap: () {
                Provider.of<TaskProvider>(context, listen: false).fetchTasks(status: s);
                Navigator.pop(context);
              },
            )),
            ListTile(
              title: const Text('Clear Filters', style: TextStyle(color: Colors.blue)),
              onTap: () {
                Provider.of<TaskProvider>(context, listen: false).fetchTasks();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActions(BuildContext context, Task task) {
    final provider = Provider.of<TaskProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                ),
                title: const Text('Delete Task', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                subtitle: const Text('This action cannot be undone'),
                onTap: () {
                  provider.deleteTask(task.id!);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
