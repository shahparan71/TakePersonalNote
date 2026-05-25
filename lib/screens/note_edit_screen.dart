import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:take_personal_note/models/note.dart';
import 'package:take_personal_note/models/recurring_interval.dart';
import 'package:take_personal_note/services/note_provider.dart';
import 'package:take_personal_note/services/notification_service.dart';
import 'package:take_personal_note/theme/app_colors.dart';
import 'package:take_personal_note/utils/date_utils.dart';
import 'package:take_personal_note/widgets/design_widgets.dart';
import 'package:take_personal_note/widgets/sheet_safe_area.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? note;
  final String? initialText;

  const NoteEditScreen({super.key, this.note, this.initialText});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _titleController;
  late quill.QuillController _contentController;
  int _selectedColor = 0xFFFFFFFF;
  bool _isPinned = false;
  DateTime? _reminderTime;
  bool _isRecurring = false;
  RecurringInterval _recurringInterval = RecurringInterval.none;
  final FocusNode _contentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');

    final initialContent = widget.note?.content ?? widget.initialText ?? '';

    quill.Document doc;
    if (initialContent.isNotEmpty) {
      try {
        final decoded = jsonDecode(initialContent);
        if (decoded is List) {
          doc = quill.Document.fromJson(decoded);
        } else {
          doc = quill.Document()..insert(0, initialContent);
        }
      } catch (e) {
        doc = quill.Document()..insert(0, initialContent);
      }
    } else {
      doc = quill.Document();
    }

    _contentController = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _selectedColor = widget.note?.color ?? 0xFFFFFFFF;
    _isPinned = widget.note?.isPinned ?? false;
    _reminderTime = widget.note?.reminderTime;
    _isRecurring = widget.note?.isRecurring ?? false;
    _recurringInterval = widget.note?.recurringInterval ?? RecurringInterval.none;

    _contentController.addListener(() {
      setState(() {});
    });
    _contentFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  String get _currentContent {
    return jsonEncode(_contentController.document.toDelta().toJson());
  }

  bool get _isEmpty {
    return _titleController.text.trim().isEmpty && _contentController.document.isEmpty();
  }

  void _saveNote() {
    if (_isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);
    final now = DateTime.now();

    if (widget.note == null) {
      final newNote = Note(
        title: _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
        content: _currentContent,
        type: NoteType.text,
        // Always text now
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
        type: NoteType.text,
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

  Future<void> _selectReminder() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime =
          await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now()));
      if (pickedTime != null) {
        setState(() {
          _reminderTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  void _setRecurrenceInterval(RecurringInterval interval) {
    setState(() {
      _isRecurring = true;
      _recurringInterval = interval;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final index = _contentController.selection.baseOffset;
      final length = _contentController.selection.extentOffset - index;
      _contentController.replaceText(
        index,
        length,
        quill.BlockEmbed.image(pickedFile.path),
        null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scaffoldColor = colors.noteEditorBackground(_selectedColor);

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: CircleActionButton(
            icon: Icons.close,
            color: colors.textSecondary,
            size: 40,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          /*if (_contentController.hasUndo)
            IconButton(
              icon: const Icon(Icons.undo, color: AppColors.actionEdit),
              onPressed: () {
                _contentController.undo();
              },
            ),*/
          CircleActionButton(
            icon: _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            color: AppColors.actionPin,
            size: 40,
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          const SizedBox(width: 6),
          CircleActionButton(
            icon: Icons.palette_outlined,
            color: AppColors.actionEdit,
            size: 40,
            onPressed: _showColorPicker,
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleActionButton(
              icon: Icons.check,
              color: AppColors.actionSave,
              size: 40,
              onPressed: () {
                _saveNote();
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Add Title',
                        filled: true,
                        fillColor: context.appColors.cardSurface.withValues(alpha: 0.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        hintStyle: GoogleFonts.outfit(fontSize: 20, color: colors.textSecondary),
                      ),
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    _buildMetadataRow(),
                    if (_reminderTime != null) ...[_buildReminderBanner(), _buildRecurrenceRow()],
                    Expanded(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          textTheme: Theme.of(context).textTheme.apply(
                                bodyColor: colors.textPrimary,
                                displayColor: colors.textPrimary,
                              ),
                        ),
                        child: quill.QuillEditor.basic(
                          controller: _contentController,
                          focusNode: _contentFocusNode,
                          config: quill.QuillEditorConfig(
                            placeholder: 'Start typing your note here...',
                            customStyles: quill.DefaultStyles(
                              paragraph: quill.DefaultTextBlockStyle(
                                GoogleFonts.outfit(fontSize: 16, color: colors.textPrimary, height: 1.5),
                                const quill.HorizontalSpacing(0, 0),
                                const quill.VerticalSpacing(0, 0),
                                const quill.VerticalSpacing(0, 0),
                                null,
                              ),
                              placeHolder: quill.DefaultTextBlockStyle(
                                GoogleFonts.outfit(fontSize: 16, color: colors.textSecondary, height: 1.5),
                                const quill.HorizontalSpacing(0, 0),
                                const quill.VerticalSpacing(0, 0),
                                const quill.VerticalSpacing(0, 0),
                                null,
                              ),
                            ),
                            embedBuilders: [
                              ...FlutterQuillEmbeds.editorBuilders(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            !_contentFocusNode.hasFocus
                ? Container()
                : Container(
                    color: colors.cardSurface,
                    child: quill.QuillSimpleToolbar(
                      controller: _contentController,
                      config: quill.QuillSimpleToolbarConfig(
                        multiRowsDisplay: false,
                        showBoldButton: true,
                        showItalicButton: true,
                        showListBullets: true,
                        showBackgroundColorButton: true,
                        showFontSize: false,
                        showUndo: true,
                        showRedo: true,
                        showFontFamily: false,
                        showStrikeThrough: false,
                        showInlineCode: false,
                        showColorButton: true,
                        showClearFormat: false,
                        showAlignmentButtons: false,
                        showLeftAlignment: false,
                        showCenterAlignment: false,
                        showRightAlignment: false,
                        showJustifyAlignment: false,
                        showHeaderStyle: false,
                        showListNumbers: true,
                        showListCheck: false,
                        showCodeBlock: false,
                        showQuote: true,
                        showIndent: false,
                        showLink: false,
                        showDirection: false,
                        showSearchButton: false,
                        showSubscript: false,
                        showSuperscript: false,
                        showClipboardCopy: false,
                        showClipboardCut: false,
                        showClipboardPaste: false,
                        /*customButtons: [
                          quill.QuillToolbarCustomButtonOptions(
                            icon: const Icon(Icons.image),
                            onPressed: _pickImage,
                            tooltip: 'Insert Image',
                          ),
                        ],*/
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow() {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMMM d, yyyy h:mm a').format(widget.note?.updatedAt ?? DateTime.now()),
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          Text(
            '${_contentController.document.toPlainText().trim().length} characters',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderBanner() {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _selectReminder,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(Icons.alarm, size: 16, color: accent),
            const SizedBox(width: 6),
            Text(
              AppDateUtils.formatReminder(_reminderTime!),
              style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceRow() {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.repeat, size: 18, color: colors.textSecondary),
              const SizedBox(width: 8),
              Text('Repeat', style: TextStyle(fontWeight: FontWeight.w500, color: colors.textPrimary)),
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
            const SizedBox(height: 8),
            _buildRecurrenceChips(),
            const SizedBox(height: 4),
            _buildNextOccurrenceDisplay()
          ],
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
    final primary = Theme.of(context).colorScheme.primary;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : context.appColors.textPrimary)),
      selected: selected,
      selectedColor: primary,
      onSelected: (_) => _setRecurrenceInterval(interval),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildNextOccurrenceDisplay() {
    final nextDate = AppDateUtils.calculateNextOccurrence(_reminderTime, _recurringInterval);
    if (nextDate == null) return const SizedBox.shrink();
    return Text(
      'Next: ${AppDateUtils.formatReminder(nextDate)}',
      style: TextStyle(fontSize: 11, color: context.appColors.textSecondary),
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

    final sheetColors = context.appColors;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: sheetColors.cardSurface,
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
                final isThemeDefault = colors[index] == AppPalette.themeDefaultNoteColor;
                final swatchColor = isThemeDefault ? sheetColors.scaffoldBg : Color(colors[index]);
                final isSelected = _selectedColor == colors[index];
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = colors[index]);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: swatchColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? sheetColors.fabDark : sheetColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: isThemeDefault
                        ? Icon(Icons.brightness_auto, size: 18, color: sheetColors.textSecondary)
                        : null,
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
