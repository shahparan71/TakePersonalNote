import 'package:googleapis/batch/v1.dart' hide Task, Container;
import 'package:take_personal_note/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:take_personal_note/models/recurring_interval.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:take_personal_note/models/task.dart';
import 'package:take_personal_note/services/battery_optimization_service.dart';
import 'package:take_personal_note/services/notification_service.dart';
import 'package:take_personal_note/services/reminder_permission_service.dart';
import 'package:take_personal_note/services/settings_provider.dart';
import 'package:take_personal_note/services/task_provider.dart';
import 'package:take_personal_note/theme/app_colors.dart';
import 'package:take_personal_note/utils/date_utils.dart';
import 'package:take_personal_note/widgets/design_widgets.dart';

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
  bool _isSaving = false;

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


  Future<void> _checkBatteryOptimization() async {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.isBatteryPromptShown) {
      final isIgnoring = await BatteryOptimizationService.isIgnoringBatteryOptimizations();
      if (!isIgnoring && mounted) {
        settings.setBatteryPromptShown(true);
        _showBatteryOptimizationDialog();
      }
    }
  }

  void _showBatteryOptimizationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.reliableReminders),
        content: Text(
            AppLocalizations.of(context)!.reliableRemindersDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.later),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              BatteryOptimizationService.requestIgnoreBatteryOptimizations();
            },
            child: Text(AppLocalizations.of(context)!.openSettings),
          ),
        ],
      ),
    );
  }

  Future<void> _scheduleOrCancelNotification(int? taskId, String title) async {
    if (taskId == null) return;
    final notifId = taskId + 10000;
    if (_reminderTime == null) {
      await NotificationService().cancelNotification(notifId);
      return;
    }
    await _checkBatteryOptimization();
    final success = await NotificationService().scheduleNotificationWithCustomInterval(
      id: notifId,
      title: AppLocalizations.of(context)!.taskReminder,
      body: title,
      scheduledDate: _reminderTime!,
      payload: 'task_$taskId',
      recurrence: _isRecurring ? _recurringInterval : RecurringInterval.none,
      customIntervalValue: _customIntervalValue,
      customIntervalUnit: _customIntervalUnit,
    );
    if (mounted) _showSchedulingFeedback(success);
  }

  Future<void> _saveTask() async {
    if (_descController.text.trim().isEmpty) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);

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

    try {
      if (widget.task == null) {
        final id = await provider.addTask(task);
        await _scheduleOrCancelNotification(id, generatedTitle);
      } else {
        await provider.updateTask(task);
        await _scheduleOrCancelNotification(widget.task!.id, generatedTitle);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.scaffoldBg,
        title: Text(
          widget.task == null ? AppLocalizations.of(context)!.newTask : AppLocalizations.of(context)!.editTask,
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
            child: _isSaving
                ? Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.actionSave),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    ),
                  )
                : CircleActionButton(
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
              hintText: AppLocalizations.of(context)!.whatNeedsToBeDone,
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
      color: Colors.blue.withValues(alpha: 0.08),
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
                          //Icon(Icons.update_rounded, size: 14, color: Colors.indigo.withValues(alpha: 0.8)),
                          const SizedBox(width: 2),
                          Text(
                            'Next: ${AppDateUtils.formatReminder(AppDateUtils.calculateNextOccurrence(_reminderTime, _recurringInterval, customValue: _customIntervalValue, customUnit: _customIntervalUnit) ?? _reminderTime!, showYear: true)}',
                            style: TextStyle(fontSize: 12, color: Colors.indigo.withValues(alpha: 0.9)),
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
        title: Text(AppLocalizations.of(context)!.repeat),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, RecurringInterval.daily),
            child: Text(AppLocalizations.of(context)!.daily),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, RecurringInterval.weekly),
            child: Text(AppLocalizations.of(context)!.weekly),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, RecurringInterval.monthly),
            child: Text(AppLocalizations.of(context)!.monthly),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, RecurringInterval.custom),
            child: Text(AppLocalizations.of(context)!.custom),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, RecurringInterval.none),
            child: Text(AppLocalizations.of(context)!.none),
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
            title: Text(AppLocalizations.of(context)!.customRepeat),
            content: Row(
              children: [
                Text(AppLocalizations.of(context)!.every),
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
                  items: [
                    DropdownMenuItem(value: CustomIntervalUnit.days, child: Text(AppLocalizations.of(context)!.days)),
                    DropdownMenuItem(value: CustomIntervalUnit.weeks, child: Text(AppLocalizations.of(context)!.weeks)),
                    DropdownMenuItem(value: CustomIntervalUnit.months, child: Text(AppLocalizations.of(context)!.months)),
                  ],
                  onChanged: (val) {
                    if (val != null) setStateSB(() => tempUnit = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.cancel)),
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
    await ReminderPermissionService.instance.showReminderPermissionDialog(
      context: context,
      hasExistingReminders: await ReminderPermissionService.instance.hasScheduledTaskReminders(),
    );

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
