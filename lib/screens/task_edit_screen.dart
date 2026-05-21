import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:take_personal_note/models/recurring_interval.dart';
import '../models/task.dart';
import '../services/task_provider.dart';
import '../services/notification_service.dart';
import '../utils/date_utils.dart';
import '../theme/app_colors.dart';
import '../widgets/design_widgets.dart';
import 'package:google_fonts/google_fonts.dart';

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
    if (_isRecurring && _recurringInterval == RecurringInterval.none) {
      _recurringInterval = RecurringInterval.daily;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  int? get _notificationId => widget.task?.id != null ? widget.task!.id! + 10000 : null;

  Future<void> _scheduleOrCancelNotification(int? taskId, String title) async {
    if (taskId == null) return;
    final notifId = taskId + 10000;
    if (_reminderTime == null) {
      await NotificationService().cancelNotification(notifId);
      return;
    }
    final success = await NotificationService().scheduleNotification(
      id: notifId,
      title: 'Task Reminder',
      body: title,
      scheduledDate: _reminderTime!,
      payload: 'task_$taskId',
      recurrence: _isRecurring ? _recurringInterval : RecurringInterval.none,
    );
    if (mounted) _showSchedulingFeedback(success);
  }

  void _saveTask() {
    if (_descController.text.trim().isEmpty) return;

    final provider = Provider.of<TaskProvider>(context, listen: false);
    final now = DateTime.now();

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
      recurringInterval: _reminderTime == null
          ? RecurringInterval.none
          : (_isRecurring ? _recurringInterval : RecurringInterval.none),
      updatedAt: now,
    );

    if (widget.task == null) {
      provider.addTask(task).then((id) => _scheduleOrCancelNotification(id, generatedTitle));
    } else {
      provider.updateTask(task).then((_) => _scheduleOrCancelNotification(widget.task!.id, generatedTitle));
    }
    Navigator.pop(context);
  }

  void _showSchedulingFeedback(bool success) {
    String message;
    if (success) {
      message = 'Reminder scheduled for ${DateFormat('MMM d, h:mm a').format(_reminderTime!)}';
      if (_isRecurring && _recurringInterval != RecurringInterval.none) {
        message += ' (${_recurringInterval.name})';
      }
    } else if (_reminderTime!.isBefore(DateTime.now()) && !_isRecurring) {
      message = 'Reminder skipped: time is in the past';
    } else {
      message = 'Failed to schedule reminder';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setRecurrenceInterval(RecurringInterval interval) {
    setState(() {
      _isRecurring = true;
      _recurringInterval = interval;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        title: Text(
          widget.task == null ? 'New Task' : 'Edit Task',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _reminderTime == null ? Icons.notifications_none_outlined : Icons.notifications_active,
              color: _reminderTime == null ? AppColors.textSecondary : AppColors.fabDark,
            ),
            onPressed: () {
              if (_reminderTime == null) {
                _selectReminder(context);
              } else {
                setState(() {
                  _reminderTime = null;
                  _isRecurring = false;
                  _recurringInterval = RecurringInterval.none;
                });
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleActionButton(
              icon: Icons.check,
              color: AppColors.actionSave,
              size: 40,
              onPressed: _saveTask,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_reminderTime != null) ...[
            _buildReminderCard(),
            const SizedBox(height: 16),
            _buildRecurrenceSection(),
            if (_isRecurring) ...[
              const SizedBox(height: 8),
              _buildNextReminderInfo(),
            ],
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _descController,
            autofocus: widget.task == null,
            decoration: InputDecoration(
              hintText: 'What needs to be done?',
              filled: true,
              fillColor: AppColors.cardWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              hintStyle: GoogleFonts.outfit(fontSize: 18, color: AppColors.textSecondary),
            ),
            style: GoogleFonts.outfit(fontSize: 20, height: 1.4),
            maxLines: null,
          ),
          const SizedBox(height: 32),
          _buildPrioritySelector(),
        ],
      ),
    );
  }

  Widget _buildReminderCard() {
    return Material(
      color: Colors.blue.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _selectReminder(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.alarm_rounded, color: Colors.blue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppDateUtils.formatReminder(_reminderTime!),
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              const Icon(Icons.edit_calendar, size: 18, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.repeat_rounded, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            const Text('Repeat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            Switch.adaptive(
              value: _isRecurring,
              onChanged: (val) => setState(() {
                _isRecurring = val;
                if (val && _recurringInterval == RecurringInterval.none) {
                  _recurringInterval = RecurringInterval.daily;
                }
              }),
            ),
          ],
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 12),
          _buildRecurrenceIntervalSelector(),
        ],
      ],
    );
  }

  Widget _buildRecurrenceIntervalSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<RecurringInterval>(
        segments: const [
          ButtonSegment(value: RecurringInterval.daily, label: Text('Daily')),
          ButtonSegment(value: RecurringInterval.weekly, label: Text('Weekly')),
          ButtonSegment(value: RecurringInterval.monthly, label: Text('Monthly')),
        ],
        selected: {
          _recurringInterval == RecurringInterval.none
              ? RecurringInterval.daily
              : _recurringInterval,
        },
        onSelectionChanged: (s) => _setRecurrenceInterval(s.first),
      ),
    );
  }

  Widget _buildNextReminderInfo() {
    final nextDate = AppDateUtils.calculateNextOccurrence(_reminderTime, _recurringInterval);
    if (nextDate == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(Icons.update_rounded, size: 14, color: Colors.indigo.withOpacity(0.8)),
        const SizedBox(width: 6),
        Text(
          'Next: ${AppDateUtils.formatReminder(nextDate)}',
          style: TextStyle(fontSize: 12, color: Colors.indigo.withOpacity(0.9)),
        ),
      ],
    );
  }

  Future<void> _selectReminder(BuildContext context) async {
    final now = DateTime.now();
    DateTime initialDate = _reminderTime ?? now;
    if (initialDate.isBefore(now)) initialDate = now;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2030),
    );
    if (date != null && context.mounted) {
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
        Text(
          'Priority',
          style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Row(
          children: TaskPriority.values.map((p) {
            final isSelected = _priority == p;
            final color = _priorityColor(p);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: p != TaskPriority.high ? 8 : 0),
                child: InkWell(
                  onTap: () => setState(() => _priority = p),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.withOpacity(0.25),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.name[0].toUpperCase() + p.name.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? color : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
    }
  }
}
