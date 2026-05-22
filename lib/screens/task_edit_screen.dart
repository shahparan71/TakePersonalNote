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
  DateTime? _reminderTime;
  bool _isRecurring = false;
  RecurringInterval _recurringInterval = RecurringInterval.none;
  int? _customIntervalValue;
  CustomIntervalUnit? _customIntervalUnit;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.task?.description ?? widget.initialText ?? '');
    _reminderTime = widget.task?.reminderTime;
    _isRecurring = widget.task?.isRecurring ?? false;
    _recurringInterval = widget.task?.recurringInterval ?? RecurringInterval.none;
    _customIntervalValue = widget.task?.customIntervalValue;
    _customIntervalUnit = widget.task?.customIntervalUnit;
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
      priority: widget.task?.priority ?? TaskPriority.low,
      reminderTime: _reminderTime,
      isRecurring: _reminderTime == null ? false : _isRecurring,
      recurringInterval: _reminderTime == null
          ? RecurringInterval.none
          : (_isRecurring ? _recurringInterval : RecurringInterval.none),
      customIntervalValue: _customIntervalValue,
      customIntervalUnit: _customIntervalUnit,
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
        if (_recurringInterval == RecurringInterval.custom) {
          message += ' (Every $_customIntervalValue ${_customIntervalUnit?.name})';
        } else {
          message += ' (${_recurringInterval.name})';
        }
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
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.scaffoldBg,
        title: Text(
          widget.task == null ? 'New Task' : 'Edit Task',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: colors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _reminderTime == null ? Icons.notifications_none_outlined : Icons.notifications_active,
              color: _reminderTime == null ? colors.textSecondary : colors.fabDark,
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
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _descController,
            autofocus: widget.task == null,
            decoration: InputDecoration(
              hintText: 'What needs to be done?',
              filled: true,
              fillColor: colors.cardSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.border)),
              hintStyle: GoogleFonts.outfit(fontSize: 18, color: colors.textSecondary),
            ),
            style: GoogleFonts.outfit(fontSize: 20, height: 1.4, color: colors.textPrimary),
            maxLines: null,
          ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppDateUtils.formatReminder(_reminderTime!),
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          //Icon(Icons.update_rounded, size: 14, color: Colors.indigo.withOpacity(0.8)),
                          const SizedBox(width: 2),
                          Text(
                            'Next: ${AppDateUtils.formatReminder(AppDateUtils.calculateNextOccurrence(_reminderTime, _recurringInterval, customValue: _customIntervalValue, customUnit: _customIntervalUnit) ?? _reminderTime!, showYear: true)}',
                            style: TextStyle(fontSize: 12, color: Colors.indigo.withOpacity(0.9)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.repeat_rounded, size: 20, color: Colors.blue),
                onPressed: _showRecurrenceDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRecurrenceDialog() async {
    final result = await showDialog<RecurringInterval>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Repeat'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, RecurringInterval.daily),
            child: const Text('Daily'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, RecurringInterval.weekly),
            child: const Text('Weekly'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, RecurringInterval.monthly),
            child: const Text('Monthly'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, RecurringInterval.custom),
            child: const Text('Custom'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, RecurringInterval.none),
            child: const Text('None'),
          ),
        ],
      ),
    );

    if (result == RecurringInterval.custom) {
      await _showCustomIntervalDialog();
      return;
    }

    if (result != null) {
      setState(() {
        _recurringInterval = result;
        _isRecurring = result != RecurringInterval.none;
      });
    }
  }

  Future<void> _showCustomIntervalDialog() async {
    int tempVal = _customIntervalValue ?? 1;
    CustomIntervalUnit tempUnit = _customIntervalUnit ?? CustomIntervalUnit.days;
    final controller = TextEditingController(text: tempVal.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: const Text('Custom Repeat'),
            content: Row(
              children: [
                const Text('Every '),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true),
                    controller: controller,
                    onChanged: (val) {
                      tempVal = int.tryParse(val) ?? 1;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<CustomIntervalUnit>(
                  value: tempUnit,
                  items: const [
                    DropdownMenuItem(value: CustomIntervalUnit.days, child: Text('Days')),
                    DropdownMenuItem(value: CustomIntervalUnit.weeks, child: Text('Weeks')),
                    DropdownMenuItem(value: CustomIntervalUnit.months, child: Text('Months')),
                  ],
                  onChanged: (val) {
                    if (val != null) setStateSB(() => tempUnit = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      setState(() {
        _customIntervalValue = tempVal;
        _customIntervalUnit = tempUnit;
        _recurringInterval = RecurringInterval.custom;
        _isRecurring = true;
      });
    }
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


}
