import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:take_personal_note/services/task_provider.dart';
import 'package:take_personal_note/utils/date_utils.dart';
import 'package:take_personal_note/widgets/sheet_safe_area.dart';
import 'package:take_personal_note/widgets/design_widgets.dart';
import 'package:take_personal_note/theme/app_colors.dart';

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
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.scaffoldBg,
        title: Text('Tasks', style: GoogleFonts.caveat(fontWeight: FontWeight.w600, fontSize: 32)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                filled: true,
                fillColor: colors.cardSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.border)),
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                Provider.of<TaskProvider>(context, listen: false).fetchTasks(query: val);
              },
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showFilterDialog(context),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          if (provider.tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No tasks yet', style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }

          final active = provider.tasks.where((t) => t.status != TaskStatus.completed).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final completed = provider.tasks.where((t) => t.status == TaskStatus.completed).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            children: [
              ...active.map((t) => _buildTaskTile(context, t)),
              if (completed.isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Completed',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                ...completed.map((t) => _buildTaskTile(context, t, isCompletedSection: true)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: DesignFab(
        heroTag: 'tasks_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskEditScreen()),
        ),
      ),
    );
  }

  Widget _buildTaskTile(BuildContext context, Task task, {bool isCompletedSection = false}) {
    final isCompleted = task.status == TaskStatus.completed;
    final priorityColor = _priorityColor(task.priority);
    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TaskEditScreen(task: task)),
          ),
          onLongPress: () => _showQuickActions(context, task),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: isCompleted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    final updated = task.copyWith(
                      status: val == true ? TaskStatus.completed : TaskStatus.pending,
                      updatedAt: DateTime.now(),
                    );
                    Provider.of<TaskProvider>(context, listen: false).updateTask(updated);
                  },
                ),
                Container(width: 3, height: 40, decoration: BoxDecoration(color: priorityColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? Colors.grey : Colors.black87,
                        ),
                      ),
                      if (task.description.isNotEmpty)
                        Text(
                          task.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      if (task.reminderTime != null) _buildReminderRow(task),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReminderRow(Task task) {
    final bool isExpired = task.reminderTime != null &&
        task.reminderTime!.isBefore(DateTime.now()) &&
        !task.isRecurring;
    DateTime? displayTime = task.reminderTime;
    if (task.reminderTime != null && task.isRecurring && task.reminderTime!.isBefore(DateTime.now())) {
      displayTime = AppDateUtils.calculateNextOccurrence(task.reminderTime, task.recurringInterval) ??
          task.reminderTime;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.alarm, size: 12, color: isExpired ? Colors.red : Colors.blue),
          const SizedBox(width: 4),
          Text(
            isExpired ? 'Expired' : AppDateUtils.formatReminder(displayTime!),
            style: TextStyle(fontSize: 11, color: isExpired ? Colors.red : Colors.blue),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
    }
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SheetSafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const ListTile(title: Text('Filter by Priority', style: TextStyle(fontWeight: FontWeight.bold))),
              ...TaskPriority.values.map(
                (p) => ListTile(
                  title: Text(p.name[0].toUpperCase() + p.name.substring(1)),
                  onTap: () {
                    Provider.of<TaskProvider>(context, listen: false).fetchTasks(priority: p);
                    Navigator.pop(context);
                  },
                ),
              ),
              const Divider(),
              const ListTile(title: Text('Filter by Status', style: TextStyle(fontWeight: FontWeight.bold))),
              ...TaskStatus.values.map(
                (s) => ListTile(
                  title: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                  onTap: () {
                    Provider.of<TaskProvider>(context, listen: false).fetchTasks(status: s);
                    Navigator.pop(context);
                  },
                ),
              ),
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
      ),
    );
  }

  void _showQuickActions(BuildContext context, Task task) {
    final provider = Provider.of<TaskProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SheetSafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12, top: 8),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              ),
              title: const Text('Delete Task', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () {
                provider.deleteTask(task.id!);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
