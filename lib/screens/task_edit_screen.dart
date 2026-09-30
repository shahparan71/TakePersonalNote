import 'package:take_personal_note/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:take_personal_note/models/recurring_interval.dart';
import '../models/task.dart';
import '../services/task_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/design_widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/date_utils.dart';
import '../services/google_drive_sync_service.dart';
import '../utils/url_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Extracts the first URL that overlaps with the current text [selection] in [text].
String? _urlInSelection(String text, TextSelection selection) {
  if (selection.isCollapsed) return null;
  final urlRegex = RegExp(r'(https?://[^\s]+)|(www\.[^\s]+)', caseSensitive: false);
  for (final match in urlRegex.allMatches(text)) {
    // Check overlap
    if (match.start < selection.end && match.end > selection.start) {
      return match.group(0);
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class TaskEditScreen extends StatefulWidget {
  final Task? task;
  final String? initialText;
  const TaskEditScreen({super.key, this.task, this.initialText});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late TextEditingController _descController;
  final FocusNode _descFocusNode = FocusNode();
  DateTime? _reminderTime;
  bool _isRecurring = false;
  RecurringInterval _recurringInterval = RecurringInterval.none;
  int? _customIntervalValue;
  CustomIntervalUnit? _customIntervalUnit;
  bool _isSaving = false;

  /// The URL currently detected in the text selection (null = none).
  String? _selectedUrl;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(
      text: widget.task?.description ?? widget.initialText ?? '',
    );
    _reminderTime = widget.task?.reminderTime;
    _isRecurring = widget.task?.isRecurring ?? false;
    _recurringInterval =
        widget.task?.recurringInterval ?? RecurringInterval.none;
    _customIntervalValue = widget.task?.customIntervalValue;
    _customIntervalUnit = widget.task?.customIntervalUnit;
    if (_isRecurring && _recurringInterval == RecurringInterval.none) {
      _recurringInterval = RecurringInterval.daily;
    }

    _descController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _descController.removeListener(_onTextChanged);
    _descController.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // URL detection
  // -------------------------------------------------------------------------

  void _onTextChanged() {
    _checkUrlInSelection();
  }

  void _checkUrlInSelection() {
    final sel = _descController.selection;
    final url = _urlInSelection(_descController.text, sel);
    if (url != _selectedUrl) {
      setState(() => _selectedUrl = url);
    }
  }

  // -------------------------------------------------------------------------
  // Battery / notifications
  // -------------------------------------------------------------------------



  Future<void> _scheduleOrCancelNotification(
      int? taskId, String title) async {
    if (taskId == null) return;
    final notifId = taskId + 10000;
    if (_reminderTime == null) {
      await NotificationService().cancelNotification(notifId);
      return;
    }
    final success =
        await NotificationService().scheduleNotificationWithCustomInterval(
      id: notifId,
      title: AppLocalizations.of(context)!.taskReminder,
      body: title,
      scheduledDate: _reminderTime!,
      payload: 'task_$taskId',
      recurrence:
          _isRecurring ? _recurringInterval : RecurringInterval.none,
      customIntervalValue: _customIntervalValue,
      customIntervalUnit: _customIntervalUnit,
    );
    if (mounted) _showSchedulingFeedback(success);
  }

  /// Saves the task without navigating away. Returns true if saved.
  Future<bool> _saveTaskOnly() async {
    if (_descController.text.trim().isEmpty) return false;
    if (_isSaving) return false;
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

    final task = (widget.task ??
            Task(
              title: generatedTitle,
              createdAt: now,
              updatedAt: now,
            ))
        .copyWith(
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
        await _scheduleOrCancelNotification(
            widget.task!.id, generatedTitle);
      }

      if (GoogleDriveSyncService().isSignedIn) {
        GoogleDriveSyncService().syncToDrive();
      }
      return true;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  void _showSchedulingFeedback(bool success) {
    String message;
    if (success) {
      message =
          'Reminder scheduled for ${DateFormat('MMM d, h:mm a').format(_reminderTime!)}';
      if (_isRecurring &&
          _recurringInterval != RecurringInterval.none) {
        if (_recurringInterval == RecurringInterval.custom) {
          message +=
              ' (Every $_customIntervalValue ${_customIntervalUnit?.name})';
        } else {
          message += ' (${_recurringInterval.name})';
        }
      }
    } else if (_reminderTime!.isBefore(DateTime.now()) && !_isRecurring) {
      message = 'Reminder skipped: time is in the past';
    } else {
      message = 'Failed to schedule reminder';
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final charCount = _descController.text.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveTaskOnly();
        if (mounted) Navigator.pop(context, result);
      },
      child: Scaffold(
        backgroundColor: colors.scaffoldBg,
        appBar: _buildAppBar(colors),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  if (_reminderTime != null) ...[
                    _buildReminderCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildTextInputCard(colors),
                  const SizedBox(height: 8),
                  // Character counter row
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$charCount characters',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: colors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // URL action bar — shown when a URL is selected
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
              child: _selectedUrl != null
                  ? _buildUrlActionBar(colors, _selectedUrl!)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(AppPalette colors) {
    return AppBar(
      backgroundColor: colors.scaffoldBg,
      elevation: 0,
      title: Text(
        widget.task == null
            ? AppLocalizations.of(context)!.newTask
            : AppLocalizations.of(context)!.editTask,
        style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600, color: colors.textPrimary),
      ),
      actions: [
        // Reminder toggle
        IconButton(
          tooltip: _reminderTime == null ? 'Set reminder' : 'Clear reminder',
          icon: Icon(
            _reminderTime == null
                ? Icons.notifications_none_outlined
                : Icons.notifications_active,
            color: _reminderTime == null
                ? colors.textSecondary
                : colors.fabDark,
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
        // Save button
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _isSaving
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.actionSave),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)),
                  ),
                )
              : CircleActionButton(
                  icon: Icons.check,
                  color: AppColors.actionSave,
                  size: 40,
                  onPressed: () => Navigator.maybePop(context),
                ),
        ),
      ],
    );
  }

  Widget _buildTextInputCard(AppPalette colors) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _descFocusNode.hasFocus
              ? colors.fabDark.withValues(alpha: 0.5)
              : colors.border,
          width: _descFocusNode.hasFocus ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (_descFocusNode.hasFocus)
            BoxShadow(
              color: colors.fabDark.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toolbar row ──
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded,
                    size: 18, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Task description',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                // Clear button
                if (_descController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _descController.clear();
                      setState(() => _selectedUrl = null);
                    },
                    child: Icon(Icons.close_rounded,
                        size: 16,
                        color:
                            colors.textSecondary.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          // ── Text field ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: TextField(
              controller: _descController,
              focusNode: _descFocusNode,
              autofocus: widget.task == null,
              decoration: InputDecoration(
                hintText:
                    AppLocalizations.of(context)!.whatNeedsToBeDone,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintStyle: GoogleFonts.outfit(
                    fontSize: 17, color: colors.textSecondary),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  height: 1.55,
                  color: colors.textPrimary),
              maxLines: null,
              minLines: 5,
              onChanged: (_) {
                setState(() {}); // rebuild to update char counter & clear btn
                _checkUrlInSelection();
              },
              onTap: _checkUrlInSelection,
              // Detect selection changes for URL action bar
              onTapAlwaysCalled: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlActionBar(AppPalette colors, String url) {
    final normalizedUrl = url.startsWith('http') ? url : 'https://$url';
    final platform = UrlUtils.identifyPlatform(normalizedUrl);
    
    Color bgColor = colors.fabDark.withValues(alpha: 0.08);
    Color borderColor = colors.fabDark.withValues(alpha: 0.2);
    Color fgColor = colors.fabDark;
    IconData iconData = Icons.open_in_browser_rounded;
    String label = 'Open in browser';
    
    switch (platform) {
      case SocialPlatform.facebook:
        fgColor = const Color(0xFF1877F2);
        iconData = FontAwesomeIcons.facebook;
        label = 'Open in Facebook app';
        break;
      case SocialPlatform.youtube:
        fgColor = const Color(0xFFFF0000);
        iconData = FontAwesomeIcons.youtube;
        label = 'Open in YouTube app';
        break;
      case SocialPlatform.instagram:
        fgColor = const Color(0xFFE1306C);
        iconData = FontAwesomeIcons.instagram;
        label = 'Open in Instagram app';
        break;
      case SocialPlatform.whatsapp:
        fgColor = const Color(0xFF25D366);
        iconData = FontAwesomeIcons.whatsapp;
        label = 'Open in WhatsApp';
        break;
      case SocialPlatform.tiktok:
        fgColor = const Color(0xFF000000); // Or white in dark mode
        iconData = FontAwesomeIcons.tiktok;
        label = 'Open in TikTok app';
        break;
      case SocialPlatform.telegram:
        fgColor = const Color(0xFF0088CC);
        iconData = FontAwesomeIcons.telegram;
        label = 'Open in Telegram';
        break;
      case SocialPlatform.messenger:
        fgColor = const Color(0xFF0084FF);
        iconData = FontAwesomeIcons.facebookMessenger;
        label = 'Open in Messenger';
        break;
      case SocialPlatform.wechat:
        fgColor = const Color(0xFF07C160);
        iconData = FontAwesomeIcons.weixin;
        label = 'Open in WeChat';
        break;
      case SocialPlatform.other:
        break;
    }
    
    if (platform != SocialPlatform.other) {
      bgColor = fgColor.withValues(alpha: 0.10);
      borderColor = fgColor.withValues(alpha: 0.25);
      
      if (fgColor == const Color(0xFF000000) && colors.scaffoldBg.computeLuminance() < 0.2) {
        fgColor = Colors.white;
      }
    }

    return Container(
      key: const ValueKey('url_bar'),
      color: colors.scaffoldBg,
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 20),
      child: SafeArea(
        top: false,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // Icon
              if (platform != SocialPlatform.other)
                FaIcon(iconData, size: 20, color: fgColor)
              else
                Icon(iconData, size: 20, color: fgColor),
              const SizedBox(width: 10),
              // Label + URL preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fgColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      url.length > 48 ? '${url.substring(0, 45)}…' : url,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Copy button
              IconButton(
                tooltip: 'Copy URL',
                icon: Icon(Icons.copy_rounded,
                    size: 18, color: colors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('URL copied'),
                        duration: Duration(seconds: 1)),
                  );
                },
              ),
              const SizedBox(width: 8),
              // Open button
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: fgColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.arrow_outward_rounded, size: 15),
                label: Text('Open',
                    style: GoogleFonts.outfit(fontSize: 13, color: fgColor == Colors.white ? Colors.black : Colors.white)),
                onPressed: () => UrlUtils.openUrl(url),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard() {
    return Material(
      color: Colors.blue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _selectReminder(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.alarm_rounded,
                    color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppDateUtils.formatReminder(_reminderTime!),
                      style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Next: ${AppDateUtils.formatReminder(AppDateUtils.calculateNextOccurrence(_reminderTime, _recurringInterval, customValue: _customIntervalValue, customUnit: _customIntervalUnit) ?? _reminderTime!, showYear: true)}',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Colors.indigo.withValues(alpha: 0.9)),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.repeat_rounded,
                    size: 20, color: Colors.blue),
                onPressed: _showRecurrenceDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Recurrence dialogs
  // -------------------------------------------------------------------------

  Future<void> _showRecurrenceDialog() async {
    final result = await showDialog<RecurringInterval>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.repeat),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, RecurringInterval.daily),
            child: Text(AppLocalizations.of(context)!.daily),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, RecurringInterval.weekly),
            child: Text(AppLocalizations.of(context)!.weekly),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, RecurringInterval.monthly),
            child: Text(AppLocalizations.of(context)!.monthly),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, RecurringInterval.custom),
            child: Text(AppLocalizations.of(context)!.custom),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, RecurringInterval.none),
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
    CustomIntervalUnit tempUnit =
        _customIntervalUnit ?? CustomIntervalUnit.days;
    final controller =
        TextEditingController(text: tempVal.toString());

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
                    decoration:
                        const InputDecoration(isDense: true),
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
                    DropdownMenuItem(
                        value: CustomIntervalUnit.days,
                        child: Text(
                            AppLocalizations.of(context)!.days)),
                    DropdownMenuItem(
                        value: CustomIntervalUnit.weeks,
                        child: Text(
                            AppLocalizations.of(context)!.weeks)),
                    DropdownMenuItem(
                        value: CustomIntervalUnit.months,
                        child: Text(
                            AppLocalizations.of(context)!.months)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setStateSB(() => tempUnit = val);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () =>
                      Navigator.pop(context, false),
                  child:
                      Text(AppLocalizations.of(context)!.cancel)),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save')),
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

  // -------------------------------------------------------------------------
  // Date / time picker
  // -------------------------------------------------------------------------

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
        initialTime:
            TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now()),
      );
      if (time != null) {
        setState(() {
          _reminderTime = DateTime(
              date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }
}
