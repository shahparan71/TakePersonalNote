import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          decoration: const InputDecoration(hintText: 'Search tasks...', border: InputBorder.none),
          onChanged: (val) {
            Provider.of<TaskProvider>(context, listen: false).fetchTasks(query: val);
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
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
        title: Text(task.title),
        subtitle: Text(task.description, maxLines: 1, overflow: TextOverflow.ellipsis),
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
      case TaskPriority.low: color = Colors.green; break;
      case TaskPriority.medium: color = Colors.orange; break;
      case TaskPriority.high: color = Colors.red; break;
    }
    return Chip(
      label: Text(priority.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }
}
