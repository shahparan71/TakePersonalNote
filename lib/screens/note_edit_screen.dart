import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:take_personal_note/models/note.dart';
import 'package:take_personal_note/models/recurring_interval.dart';
import 'package:take_personal_note/services/note_provider.dart';
import 'package:take_personal_note/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:take_personal_note/utils/date_utils.dart';
import 'package:take_personal_note/utils/note_text_controller.dart';
import 'package:take_personal_note/utils/checklist_utils.dart';
import 'package:take_personal_note/widgets/sheet_safe_area.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? note;
  final String? initialText;

  const NoteEditScreen({super.key, this.note, this.initialText});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  static const double _formattingToolbarHeight = 44;

  late TextEditingController _titleController;
  late NoteTextController _contentController;
  int _selectedColor = 0xFFFFFFFF;
  bool _isPinned = false;
  bool _isHighlighterActive = false;
  double _fontSize = 18.0;
  DateTime? _reminderTime;
  bool _isRecurring = false;
  RecurringInterval _recurringInterval = RecurringInterval.none;
  NoteType _type = NoteType.text;
  List<ChecklistItem> _checklistItems = [];
  final List<TextEditingController> _checklistControllers = [];
  final FocusNode _contentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    final initialContent = widget.note?.content ?? widget.initialText ?? '';
    _contentController = NoteTextController(text: initialContent);
    _selectedColor = widget.note?.color ?? 0xFFFFFFFF;
    _isPinned = widget.note?.isPinned ?? false;
    _reminderTime = widget.note?.reminderTime;
    _isRecurring = widget.note?.isRecurring ?? false;
    _recurringInterval = widget.note?.recurringInterval ?? RecurringInterval.none;
    _type = widget.note?.type ?? NoteType.text;
    if (_type == NoteType.checklist) {
      _checklistItems = ChecklistUtils.parse(initialContent);
      _syncChecklistControllers();
    }
  }

  void _syncChecklistControllers() {
    for (final c in _checklistControllers) {
      c.dispose();
    }
    _checklistControllers.clear();
    for (final item in _checklistItems) {
      _checklistControllers.add(TextEditingController(text: item.text));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    for (final c in _checklistControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String get _currentContent {
    if (_type == NoteType.checklist) {
      for (var i = 0; i < _checklistItems.length; i++) {
        if (i < _checklistControllers.length) {
          _checklistItems[i].text = _checklistControllers[i].text;
        }
      }
      return ChecklistUtils.serialize(_checklistItems);
    }
    return _contentController.text;
  }

  void _saveNote() {
    if (_titleController.text.isEmpty && _currentContent.trim().isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);
    final now = DateTime.now();

    if (widget.note == null) {
      final newNote = Note(
        title: _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
        content: _currentContent,
        type: _type,
        color: _selectedColor,
        isPinned: _isPinned,
        reminderTime: _reminderTime,
        isRecurring: _reminderTime == null ? false : _isRecurring,
        recurringInterval: _reminderTime == null ? RecurringInterval.none : _recurringInterval,
        createdAt: now,
        updatedAt: now,
      );
      provider.addNote(newNote).then((id) async {
        if (_reminderTime != null && id != null) {
          await NotificationService().scheduleNotification(
            id: id,
            title: 'Note Reminder',
            body: _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
            scheduledDate: _reminderTime!,
            payload: 'note_$id',
            recurrence: _isRecurring ? _recurringInterval : RecurringInterval.none,
          );
        }
      });
    } else {
      final updatedNote = widget.note!.copyWith(
        title: _titleController.text,
        content: _currentContent,
        color: _selectedColor,
        isPinned: _isPinned,
        type: _type,
        category: widget.note!.category,
        reminderTime: _reminderTime,
        isRecurring: _reminderTime == null ? false : _isRecurring,
        recurringInterval: _reminderTime == null ? RecurringInterval.none : _recurringInterval,
        updatedAt: now,
      );
      provider.updateNote(updatedNote).then((_) async {
        final noteId = widget.note!.id!;
        if (_reminderTime != null) {
          await NotificationService().scheduleNotification(
            id: noteId,
            title: 'Note Reminder',
            body: _titleController.text,
            scheduledDate: _reminderTime!,
            payload: 'note_$noteId',
            recurrence: _isRecurring ? _recurringInterval : RecurringInterval.none,
          );
        } else if (widget.note!.reminderTime != null) {
          await NotificationService().cancelNotification(noteId);
        }
      });
    }
  }

  void _switchNoteType(NoteType newType) {
    if (_type == newType) return;
    setState(() {
      if (newType == NoteType.checklist) {
        _checklistItems = ChecklistUtils.parse(_contentController.text);
        if (_checklistItems.isEmpty) {
          _checklistItems = [ChecklistItem(checked: false, text: '')];
        }
        _syncChecklistControllers();
      } else {
        _contentController.text = ChecklistUtils.serialize(_checklistItems);
      }
      _type = newType;
    });
  }

  Future<void> _selectReminder() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now()));
      if (pickedTime != null) {
        setState(() {
          _reminderTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  void _formatText(String prefix, String suffix) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid) return;
    final selectedText = selection.textInside(text);
    final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length + suffix.length),
    );
  }

  void _toggleHighlighter() {
    setState(() {
      _isHighlighterActive = !_isHighlighterActive;
      _contentController.isHighlighterActive = _isHighlighterActive;
    });
  }

  void _updateFontSize(bool increase) {
    setState(() {
      _fontSize = increase ? _fontSize + 2 : (_fontSize > 10 ? _fontSize - 2 : _fontSize);
      _contentController.updateFontSize(_fontSize);
    });
  }

  void _setRecurrenceInterval(RecurringInterval interval) {
    setState(() {
      _isRecurring = true;
      _recurringInterval = interval;
    });
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom is the keyboard height from the physical bottom edge.
    // resizeToAvoidBottomInset must be false, otherwise the body is already
    // lifted and applying bottomInset again doubles the offset.
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardHeight > 0;
    final contentBottomPadding = keyboardVisible && _type == NoteType.text
        ? keyboardHeight + _formattingToolbarHeight
        : (keyboardVisible ? keyboardHeight : 0.0);

    return Scaffold(
      backgroundColor: Color(_selectedColor),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_contentController.canUndo)
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.blue),
              onPressed: () {
                _contentController.undo();
                setState(() {});
              },
              tooltip: 'Undo',
            ),
          IconButton(
            icon: Icon(
              _reminderTime == null ? Icons.notifications_none : Icons.notifications_active,
              color: _reminderTime == null ? null : Colors.blue,
            ),
            onPressed: () {
              if (_reminderTime == null) {
                _selectReminder();
              } else {
                setState(() {
                  _reminderTime = null;
                  _isRecurring = false;
                  _recurringInterval = RecurringInterval.none;
                });
              }
            },
            tooltip: _reminderTime == null ? 'Set Reminder' : 'Remove Reminder',
          ),
          IconButton(icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined), onPressed: () => setState(() => _isPinned = !_isPinned)),
          IconButton(icon: const Icon(Icons.palette_outlined), onPressed: _showColorPicker),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              _saveNote();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 16, right: 16, bottom: contentBottomPadding),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                      hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  _buildMetadataRow(),
                  _buildModeSelector(),
                  if (_reminderTime != null) ...[_buildReminderBanner(), _buildRecurrenceRow()],
                  Expanded(child: _type == NoteType.text ? _buildTextEditor() : _buildChecklistEditor(keyboardHeight)),
                ],
              ),
            ),
            if (keyboardVisible && _type == NoteType.text)
              Positioned(
                left: 0,
                right: 0,
                bottom: keyboardHeight,
                height: _formattingToolbarHeight,
                child: Material(elevation: 8, color: Theme.of(context).colorScheme.surface, child: _buildFormattingToolbar()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMMM d, yyyy h:mm a').format(widget.note?.updatedAt ?? DateTime.now()),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _contentController,
            builder: (context, value, _) {
              final count = _type == NoteType.text ? value.text.length : _currentContent.length;
              return Text('$count characters', style: const TextStyle(fontSize: 12, color: Colors.grey));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SegmentedButton<NoteType>(
        segments: const [
          ButtonSegment(value: NoteType.text, label: Text('Text'), icon: Icon(Icons.text_fields, size: 18)),
          ButtonSegment(value: NoteType.checklist, label: Text('Checklist'), icon: Icon(Icons.checklist, size: 18)),
        ],
        selected: {_type},
        onSelectionChanged: (s) => _switchNoteType(s.first),
      ),
    );
  }

  Widget _buildReminderBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _selectReminder,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            const Icon(Icons.alarm, size: 16, color: Colors.blue),
            const SizedBox(width: 6),
            Text(
              AppDateUtils.formatReminder(_reminderTime!),
              style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('Repeat', style: TextStyle(fontWeight: FontWeight.w500)),
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
          if (_isRecurring) ...[const SizedBox(height: 8), _buildRecurrenceChips(), const SizedBox(height: 4), _buildNextOccurrenceDisplay()],
        ],
      ),
    );
  }

  Widget _buildRecurrenceChips() {
    return Row(
      children: [
        _recurrenceChip('Daily', RecurringInterval.daily),
        const SizedBox(width: 8),
        _recurrenceChip('Weekly', RecurringInterval.weekly),
        const SizedBox(width: 8),
        _recurrenceChip('Monthly', RecurringInterval.monthly),
      ],
    );
  }

  Widget _recurrenceChip(String label, RecurringInterval interval) {
    final selected = _recurringInterval == interval;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
      selected: selected,
      selectedColor: Colors.blue,
      onSelected: (_) => _setRecurrenceInterval(interval),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildNextOccurrenceDisplay() {
    final nextDate = AppDateUtils.calculateNextOccurrence(_reminderTime, _recurringInterval);
    if (nextDate == null) return const SizedBox.shrink();
    return Text('Next: ${AppDateUtils.formatReminder(nextDate)}', style: const TextStyle(fontSize: 11, color: Colors.indigo));
  }

  Widget _buildTextEditor() {
    return TextField(
      controller: _contentController,
      focusNode: _contentFocusNode,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(hintText: 'Start typing...', border: InputBorder.none, contentPadding: EdgeInsets.all(4)),
      style: TextStyle(fontSize: _fontSize),
    );
  }

  Widget _buildChecklistEditor([double keyboardHeight = 0]) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: keyboardHeight + 16),
      itemCount: _checklistItems.length + 1,
      itemBuilder: (context, index) {
        if (index == _checklistItems.length) {
          return TextButton.icon(
            onPressed: () {
              setState(() {
                _checklistItems.add(ChecklistItem(checked: false, text: ''));
                _checklistControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add item'),
          );
        }
        final item = _checklistItems[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: item.checked,
                onChanged: (val) => setState(() => item.checked = val ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Expanded(
                child: TextField(
                  controller: _checklistControllers[index],
                  decoration: const InputDecoration(hintText: 'List item', border: InputBorder.none, isDense: true),
                  style: TextStyle(
                    fontSize: 16,
                    decoration: item.checked ? TextDecoration.lineThrough : null,
                    color: item.checked ? Colors.grey : null,
                  ),
                  onChanged: (val) => item.text = val,
                ),
              ),
              if (_checklistItems.length > 1)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _checklistControllers[index].dispose();
                      _checklistControllers.removeAt(index);
                      _checklistItems.removeAt(index);
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormattingToolbar() {
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.format_bold, size: 22), onPressed: () => _formatText('**', '**'), tooltip: 'Bold'),
        IconButton(icon: const Icon(Icons.format_italic, size: 22), onPressed: () => _formatText('__', '__'), tooltip: 'Italic'),
        IconButton(icon: const Icon(Icons.format_list_bulleted, size: 22), onPressed: () => _formatText('\n- ', ''), tooltip: 'Bullet'),
        IconButton(
          icon: Icon(Icons.border_color, size: 22, color: _isHighlighterActive ? Colors.blue : null),
          onPressed: _toggleHighlighter,
          tooltip: 'Highlight',
        ),
        const Spacer(),
        IconButton(icon: const Icon(Icons.text_increase, size: 22), onPressed: () => _updateFontSize(true)),
        IconButton(icon: const Icon(Icons.text_decrease, size: 22), onPressed: () => _updateFontSize(false)),
      ],
    );
  }

  void _showColorPicker() {
    final colors = [
      0xFFFFFFFF,
      0xFFFFCDD2,
      0xFFF8BBD0,
      0xFFE1BEE7,
      0xFFC5CAE9,
      0xFFBBDEFB,
      0xFFB2EBF2,
      0xFFC8E6C9,
      0xFFDCEDC8,
      0xFFF0F4C3,
      0xFFFFF9C4,
      0xFFFFE0B2,
    ];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return SheetSafeArea(
          includeNavBar: false,
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 200,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: colors.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = colors[index]);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(colors[index]),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
