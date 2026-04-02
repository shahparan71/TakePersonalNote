import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_provider.dart';
import '../services/notification_service.dart';

class TaskEditScreen extends StatefulWidget {
  final Task? task;
  const TaskEditScreen({super.key, this.task});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  TaskPriority _priority = TaskPriority.low;
  DateTime? _startTime;
  DateTime? _expiryTime;
  DateTime? _reminderTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descController = TextEditingController(text: widget.task?.description ?? '');
    _priority = widget.task?.priority ?? TaskPriority.low;
    _startTime = widget.task?.startTime;
    _expiryTime = widget.task?.expiryTime;
    // Note: Task model currently doesn't have a specific reminderTime field separate from startTime
    // but the FRD mentions reminders as a feature of tasks. I'll use startTime as reminder time for now
    // or add a separate field if needed. For now, I'll use a local state.
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _saveTask() {
    if (_titleController.text.isEmpty) return;

    final provider = Provider.of<TaskProvider>(context, listen: false);
    final now = DateTime.now();

    final task = (widget.task ?? Task(
      title: _titleController.text,
      createdAt: now,
      updatedAt: now,
    )).copyWith(
      title: _titleController.text,
      description: _descController.text,
      priority: _priority,
      startTime: _startTime,
      expiryTime: _expiryTime,
      updatedAt: now,
    );

    if (widget.task == null) {
      provider.addTask(task).then((id) {
        if (_reminderTime != null) {
          NotificationService().scheduleNotification(
            id: (id ?? 0) + 10000, // Offset to avoid conflict with note IDs
            title: 'Task Reminder',
            body: _titleController.text,
            scheduledDate: _reminderTime!,
          );
        }
      });
    } else {
      provider.updateTask(task).then((_) {
        if (_reminderTime != null) {
          NotificationService().scheduleNotification(
            id: widget.task!.id! + 10000,
            title: 'Task Reminder',
            body: _titleController.text,
            scheduledDate: _reminderTime!,
          );
        }
      });
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'New Task' : 'Edit Task'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveTask),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildPrioritySelector(),
          const SizedBox(height: 16),
          _buildDateTimePicker('Start Time', _startTime, (val) => setState(() => _startTime = val)),
          _buildDateTimePicker('Expiry Time', _expiryTime, (val) => setState(() => _expiryTime = val)),
          _buildDateTimePicker('Reminder Time', _reminderTime, (val) => setState(() => _reminderTime = val)),
        ],
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Priority'),
        Row(
          children: TaskPriority.values.map((p) {
            return Expanded(
              child: RadioListTile<TaskPriority>(
                title: Text(p.name, style: const TextStyle(fontSize: 12)),
                value: p,
                groupValue: _priority,
                onChanged: (val) => setState(() => _priority = val!),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateTimePicker(String label, DateTime? value, Function(DateTime) onSelected) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value != null ? DateFormat('MMM d, h:mm a').format(value) : 'Not set'),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
          );
          if (time != null) {
            onSelected(DateTime(date.year, date.month, date.day, time.hour, time.minute));
          }
        }
      },
    );
  }
}
