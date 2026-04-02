import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:take_personal_note/models/recurring_interval.dart';
import '../models/task.dart';
import '../services/task_provider.dart';
import '../services/notification_service.dart';
import '../utils/date_utils.dart';

class TaskEditScreen extends StatefulWidget {
  final Task? task;
  final String? initialText;
  const TaskEditScreen({super.key, this.task, this.initialText});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late TextEditingController _descController;
  TaskPriority _priority = TaskPriority.low;
  DateTime? _reminderTime;
  bool _isRecurring = false;
  RecurringInterval _recurringInterval = RecurringInterval.none;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.task?.description ?? widget.initialText ?? '');
    _priority = widget.task?.priority ?? TaskPriority.low;
    _reminderTime = widget.task?.reminderTime;
    _isRecurring = widget.task?.isRecurring ?? false;
    _recurringInterval = widget.task?.recurringInterval ?? RecurringInterval.none;
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _saveTask() {
    if (_descController.text.trim().isEmpty) return;

    final provider = Provider.of<TaskProvider>(context, listen: false);
    final now = DateTime.now();

    // Generate title from description
    String generatedTitle = _descController.text.trim();
    if (generatedTitle.contains('\n')) {
      generatedTitle = generatedTitle.split('\n').first;
    }
    if (generatedTitle.length > 50) {
      generatedTitle = '${generatedTitle.substring(0, 47)}...';
    }

    final task = (widget.task ?? Task(
      title: generatedTitle,
      createdAt: now,
      updatedAt: now,
    )).copyWith(
      title: generatedTitle,
      description: _descController.text,
      priority: _priority,
      reminderTime: _reminderTime,
      isRecurring: _reminderTime == null ? false : _isRecurring,
      recurringInterval: _reminderTime == null ? RecurringInterval.none : _recurringInterval,
      updatedAt: now,
    );

    if (widget.task == null) {
      provider.addTask(task).then((id) async {
        if (_reminderTime != null) {
          final success = await NotificationService().scheduleNotification(
            id: (id ?? 0) + 10000,
            title: 'Task Reminder',
            body: generatedTitle,
            scheduledDate: _reminderTime!,
            payload: 'task_$id',
            recurrence: _isRecurring ? _recurringInterval : RecurringInterval.none,
          );
          if (mounted) {
            _showSchedulingFeedback(success);
          }
        }
      });
    } else {
      provider.updateTask(task).then((_) async {
        if (_reminderTime != null) {
          final success = await NotificationService().scheduleNotification(
            id: widget.task!.id! + 10000,
            title: 'Task Reminder',
            body: generatedTitle,
            scheduledDate: _reminderTime!,
            payload: 'task_${widget.task!.id!}',
            recurrence: _isRecurring ? _recurringInterval : RecurringInterval.none,
          );
          if (mounted) {
            _showSchedulingFeedback(success);
          }
        }
      });
    }
    Navigator.pop(context);
  }

  void _showSchedulingFeedback(bool success) {
    String message;
    if (success) {
      message = '✅ Reminder scheduled for ${DateFormat('MMM d, h:mm a').format(_reminderTime!)}';
    } else {
      if (_reminderTime!.isBefore(DateTime.now())) {
        message = '⚠️ Reminder skipped: Time is in the past';
      } else {
        message = '❌ Failed to schedule reminder (Timezone error)';
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Task' : 'Edit Task'),
        actions: [
          IconButton(
            icon: Icon(_reminderTime == null ? Icons.notifications_none : Icons.notifications_active, color: _reminderTime == null ? null : Colors.blue),
            onPressed: () => _selectReminder(context),
            tooltip: 'Set Reminder',
          ),
          IconButton(icon: const Icon(Icons.check), onPressed: _saveTask),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_reminderTime != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.alarm, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _selectReminder(context),
                    child: Text(
                      AppDateUtils.formatReminder(_reminderTime!),
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: () => setState(() {
                      _reminderTime = null;
                      _isRecurring = false;
                    }),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _descController,
                  autofocus: widget.task == null,
                  decoration: const InputDecoration(
                    hintText: 'What needs to be done?',
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 18),
                  ),
                  style: const TextStyle(fontSize: 18),
                  maxLines: null,
                ),
              ),
              if (_reminderTime != null) ...[
                const SizedBox(width: 8),
                _buildRecurrenceRow(),
              ],
            ],
          ),
          if (_reminderTime != null && _isRecurring)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: _buildNextReminderInfo(),
            ),
          const Divider(),
          const SizedBox(height: 16),
          _buildPrioritySelector(),
        ],
      ),
    );
  }

  Widget _buildRecurrenceRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRecurrenceToggle(),
        if (_isRecurring) ...[
          const SizedBox(width: 12),
          _buildRecurrenceIntervalSelector(),
        ],
      ],
    );
  }

  Widget _buildNextReminderInfo() {
    final nextDate = AppDateUtils.calculateNextOccurrence(_reminderTime, _recurringInterval);
    if (nextDate == null) return const SizedBox.shrink();
    
    return Row(
      children: [
        const Icon(Icons.update, size: 14, color: Colors.indigo),
        const SizedBox(width: 6),
        Text(
          'Next occurrence: ${AppDateUtils.formatReminder(nextDate)}',
          style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildRecurrenceToggle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Repeat', style: TextStyle(fontSize: 10, color: Colors.grey)),
        SizedBox(
          height: 32,
          child: Switch.adaptive(
            value: _isRecurring,
            onChanged: (val) => setState(() => _isRecurring = val),
          ),
        ),
      ],
    );
  }

  Widget _buildRecurrenceIntervalSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RecurringInterval>(
          value: _recurringInterval == RecurringInterval.none ? RecurringInterval.daily : _recurringInterval,
          items: RecurringInterval.values
              .where((v) => v != RecurringInterval.none)
              .map((v) => DropdownMenuItem(value: v, child: Text(v.name.toUpperCase(), style: const TextStyle(fontSize: 12))))
              .toList(),
          onChanged: (val) => setState(() => _recurringInterval = val!),
        ),
      ),
    );
  }

  Future<void> _selectReminder(BuildContext context) async {
    final now = DateTime.now();
    // Use the existing reminder time if available, otherwise now.
    // Ensure initialDate is not before firstDate.
    DateTime initialDate = _reminderTime ?? now;
    if (initialDate.isBefore(now)) {
      initialDate = now;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _reminderTime != null && _reminderTime!.isBefore(now) ? _reminderTime! : now,
      lastDate: DateTime(2030),
    );
    if (date != null) {
      if (!context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now()),
      );
      if (time != null) {
        setState(() {
          _reminderTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: TaskPriority.values.map((p) {
            final isSelected = _priority == p;
            Color color;
            switch (p) {
              case TaskPriority.low: color = Colors.green; break;
              case TaskPriority.medium: color = Colors.orange; break;
              case TaskPriority.high: color = Colors.red; break;
            }
            return ChoiceChip(
              label: Text(p.name.toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : color, fontSize: 12)),
              selected: isSelected,
              selectedColor: color,
              onSelected: (val) => setState(() => _priority = p),
            );
          }).toList(),
        ),
      ],
    );
  }
}
