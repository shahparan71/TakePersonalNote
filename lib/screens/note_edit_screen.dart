import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:take_personal_note/l10n/app_localizations.dart';
import 'package:take_personal_note/models/note.dart';
import 'package:take_personal_note/models/recurring_interval.dart';
import 'package:take_personal_note/services/google_drive_sync_service.dart';
import 'package:take_personal_note/services/note_provider.dart';
import 'package:take_personal_note/services/notification_service.dart';
import 'package:take_personal_note/theme/app_colors.dart';
import 'package:take_personal_note/utils/date_utils.dart';
import 'package:take_personal_note/widgets/design_widgets.dart';
import 'package:take_personal_note/widgets/sheet_safe_area.dart';
import 'package:url_launcher/url_launcher.dart';

class NoteEditScreen extends StatefulWidget {
  final MyNote? note;
  final String? initialText;

  const NoteEditScreen({super.key, this.note, this.initialText});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _titleController;
  late quill.QuillController _contentController;
  late ScrollController _scrollController;
  int _selectedColor = 0xFFFFFFFF;
  bool _isPinned = false;
  DateTime? _reminderTime;
  bool _isRecurring = false;
  RecurringInterval _recurringInterval = RecurringInterval.none;
  final FocusNode _contentFocusNode = FocusNode();
  final RegExp _phoneNumberRegex = RegExp(r'\b\d{10,}\b');
  final RegExp _emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
  final RegExp _urlRegex = RegExp(r'(https?:\/\/[^\s]+)|(www\.[^\s]+)');
  final Set<int> _phoneNumberRanges = <int>{};
  final Set<int> _emailRanges = <int>{};
  final Set<int> _urlRanges = <int>{};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
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

    _contentController.addListener(_refreshPhoneNumberStyles);
    _contentFocusNode.addListener(() {
      setState(() {});
    });

    if (widget.note == null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _contentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
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
      final newNote = MyNote(
        title: _titleController.text.isEmpty ? "" : _titleController.text,
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
            title: AppLocalizations.of(context)!.noteReminder,
            body: _titleController.text.isEmpty ? AppLocalizations.of(context)!.untitled : _titleController.text,
            scheduledDate: _reminderTime!,
            payload: 'note_$id',
            recurrence: _isRecurring ? _recurringInterval : RecurringInterval.none,
          );
        }
        if (GoogleDriveSyncService().isSignedIn) {
          GoogleDriveSyncService().syncToDrive();
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
            title: AppLocalizations.of(context)!.noteReminder,
            body: _titleController.text,
            scheduledDate: _reminderTime!,
            payload: 'note_$noteId',
            recurrence: _isRecurring ? _recurringInterval : RecurringInterval.none,
          );
        } else if (widget.note!.reminderTime != null) {
          await NotificationService().cancelNotification(noteId);
        }
        if (GoogleDriveSyncService().isSignedIn) {
          GoogleDriveSyncService().syncToDrive();
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
      final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now()));
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

  void _refreshPhoneNumberStyles() {
    if (!mounted) return;
    final text = _contentController.document.toPlainText();
    final phoneMatches = _phoneNumberRegex.allMatches(text);
    final emailMatches = _emailRegex.allMatches(text);
    final urlMatches = _urlRegex.allMatches(text);

    final nextPhoneRanges = <int>{};
    for (final match in phoneMatches) {
      for (var index = match.start; index < match.end; index++) {
        nextPhoneRanges.add(index);
      }
    }

    final nextEmailRanges = <int>{};
    for (final match in emailMatches) {
      for (var index = match.start; index < match.end; index++) {
        nextEmailRanges.add(index);
      }
    }

    final nextUrlRanges = <int>{};
    for (final match in urlMatches) {
      // Avoid overlapping with emails
      bool overlapsEmail = false;
      for (var index = match.start; index < match.end; index++) {
        if (nextEmailRanges.contains(index)) {
          overlapsEmail = true;
          break;
        }
      }
      if (!overlapsEmail) {
        for (var index = match.start; index < match.end; index++) {
          nextUrlRanges.add(index);
        }
      }
    }

    // Check for character typing to clear formatting if the user breaks the link
    if (_contentController.selection.isCollapsed) {
      final offset = _contentController.selection.baseOffset;
      if (offset > 0 && offset <= text.length) {
        // Look at previous character to detect a break
        final prevChar = text.substring(offset - 1, offset);
        if (prevChar == ' ' || prevChar == '\n') {
          // If the char before the space was part of a link/phone/email, clear that specific space's formatting
          if (offset > 1 && (nextPhoneRanges.contains(offset - 2) || nextEmailRanges.contains(offset - 2) || nextUrlRanges.contains(offset - 2))) {
            _contentController.removeListener(_refreshPhoneNumberStyles);
            _contentController.formatText(offset - 1, 1, quill.ColorAttribute(null));
            _contentController.formatText(offset - 1, 1, quill.Attribute.clone(quill.Attribute.underline, null));
            _contentController.formatText(offset - 1, 1, quill.LinkAttribute(null));
            _contentController.formatSelection(quill.ColorAttribute(null));
            _contentController.formatSelection(quill.Attribute.clone(quill.Attribute.underline, null));
            _contentController.formatSelection(quill.LinkAttribute(null));
            _contentController.addListener(_refreshPhoneNumberStyles);
          }
        }
      }
    }

    bool rangesChanged =
        !setEquals(_phoneNumberRanges, nextPhoneRanges) || !setEquals(_emailRanges, nextEmailRanges) || !setEquals(_urlRanges, nextUrlRanges);

    if (rangesChanged) {
      final oldPhoneRanges = _phoneNumberRanges.toSet();
      final oldEmailRanges = _emailRanges.toSet();
      final oldUrlRanges = _urlRanges.toSet();

      setState(() {
        _phoneNumberRanges.clear();
        _phoneNumberRanges.addAll(nextPhoneRanges);
        _emailRanges.clear();
        _emailRanges.addAll(nextEmailRanges);
        _urlRanges.clear();
        _urlRanges.addAll(nextUrlRanges);
      });

      _contentController.removeListener(_refreshPhoneNumberStyles);

      final oldRanges = oldPhoneRanges.union(oldEmailRanges).union(oldUrlRanges);
      final newRanges = nextPhoneRanges.union(nextEmailRanges).union(nextUrlRanges);

      final toRemove = oldRanges.difference(newRanges);
      final toAdd = newRanges.difference(oldRanges);

      _applyFormatToIndices(toRemove, false);
      _applyFormatToIndices(toAdd, true);

      _contentController.addListener(_refreshPhoneNumberStyles);
    }

    // --- Auto-Selection Logic ---
    final selection = _contentController.selection;
    if (!selection.isCollapsed) {
      final start = selection.start;
      final end = selection.end;

      Set<int> targetRanges = const {};
      if (nextPhoneRanges.contains(start) || nextPhoneRanges.contains(end - 1)) {
        targetRanges = nextPhoneRanges;
      } else if (nextEmailRanges.contains(start) || nextEmailRanges.contains(end - 1)) {
        targetRanges = nextEmailRanges;
      } else if (nextUrlRanges.contains(start) || nextUrlRanges.contains(end - 1)) {
        targetRanges = nextUrlRanges;
      }

      if (targetRanges.isNotEmpty) {
        int matchedIndex = targetRanges.contains(start) ? start : end - 1;

        int tokenStart = _findTokenStart(text, matchedIndex) ?? matchedIndex;
        int tokenEnd = _findTokenEnd(text, matchedIndex) ?? matchedIndex;

        final newStart = math.min(selection.start, tokenStart);
        final newEnd = math.max(selection.end, tokenEnd);

        if (newStart != selection.start || newEnd != selection.end) {
          _contentController.removeListener(_refreshPhoneNumberStyles);
          _contentController.updateSelection(TextSelection(baseOffset: newStart, extentOffset: newEnd), quill.ChangeSource.local);
          _contentController.addListener(_refreshPhoneNumberStyles);
        }
      }
    }
  }

  void _applyFormatToIndices(Set<int> indices, bool apply) {
    if (indices.isEmpty) return;
    final sorted = indices.toList()..sort();
    int start = sorted.first;
    int length = 1;

    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == sorted[i - 1] + 1) {
        length++;
      } else {
        _formatRange(start, length, apply);
        start = sorted[i];
        length = 1;
      }
    }
    _formatRange(start, length, apply);
  }

  void _formatRange(int start, int length, bool apply) {
    if (apply) {
      _contentController.formatText(start, length, quill.ColorAttribute('#FFA500'));
      // Using flutter_quill's standard attribute for underline
      _contentController.formatText(start, length, quill.Attribute.underline);
    } else {
      _contentController.formatText(start, length, quill.ColorAttribute(null));
      // Passing null clears the boolean attribute in flutter_quill
      _contentController.formatText(start, length, quill.Attribute.clone(quill.Attribute.underline, null));
    }
  }

  void _handlePhoneNumberTap(String value) async {
    final cleaned = value.replaceAll(RegExp(r'[^+\d]'), '');
    if (cleaned.length < 10) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleEmailTap(String value) async {
    final uri = Uri(scheme: 'mailto', path: value);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleUrlTap(String value) async {
    final uri = Uri.parse(value.startsWith('http') ? value : 'https://$value');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    _refreshPhoneNumberStyles();
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
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_contentFocusNode.hasFocus) {
                    _contentFocusNode.requestFocus();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.addTitle,
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
                        const SizedBox(height: 12),
                        Theme(
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
                              placeholder: AppLocalizations.of(context)!.startTypingNote,
                              scrollable: false,
                              expands: false,
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
                              onLaunchUrl: (String url) {
                                if (!_contentFocusNode.hasFocus) {
                                  _contentFocusNode.requestFocus();
                                }
                              },
                              contextMenuBuilder: (context, rawEditorState) {
                                final defaultItems = rawEditorState.contextMenuButtonItems;
                                final selection = rawEditorState.textEditingValue.selection;

                                if (selection.isCollapsed) {
                                  return AdaptiveTextSelectionToolbar.buttonItems(
                                    anchors: rawEditorState.contextMenuAnchors,
                                    buttonItems: defaultItems,
                                  );
                                }

                                final text = rawEditorState.textEditingValue.text;
                                final selectedText = selection.textInside(text).trim();

                                final isPhone = _phoneNumberRegex.hasMatch(selectedText);
                                final isEmail = _emailRegex.hasMatch(selectedText);
                                final isUrl = _urlRegex.hasMatch(selectedText);

                                if (isPhone || isEmail || isUrl) {
                                  final customItems = <ContextMenuButtonItem>[];

                                  if (isPhone) {
                                    customItems.add(
                                      ContextMenuButtonItem(
                                        onPressed: () {
                                          _handlePhoneNumberTap(selectedText);
                                          rawEditorState.hideToolbar();
                                        },
                                        type: ContextMenuButtonType.custom,
                                        label: 'Call',
                                      ),
                                    );
                                  }

                                  if (isEmail) {
                                    customItems.add(
                                      ContextMenuButtonItem(
                                        onPressed: () {
                                          _handleEmailTap(selectedText);
                                          rawEditorState.hideToolbar();
                                        },
                                        type: ContextMenuButtonType.custom,
                                        label: 'Email',
                                      ),
                                    );
                                  }
                                  if (isUrl) {
                                    customItems.add(
                                      ContextMenuButtonItem(
                                        onPressed: () {
                                          _handleUrlTap(selectedText);
                                          rawEditorState.hideToolbar();
                                        },
                                        type: ContextMenuButtonType.custom,
                                        label: 'Open Link',
                                      ),
                                    );
                                  }

                                  return AdaptiveTextSelectionToolbar.buttonItems(
                                    anchors: rawEditorState.contextMenuAnchors,
                                    buttonItems: [...customItems, ...defaultItems],
                                  );
                                }

                                return AdaptiveTextSelectionToolbar.buttonItems(
                                  anchors: rawEditorState.contextMenuAnchors,
                                  buttonItems: defaultItems,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            !_contentFocusNode.hasFocus
                ? SafeArea(top: false, child: const SizedBox.shrink())
                : Container(
                    color: colors.cardSurface,
                    child: SafeArea(
                      top: false,
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
                          showFontFamily: true,
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
                  )
          ],
        ),
      ),
    );
  }

  int? _findTokenStart(String text, int index) {
    for (var i = index; i >= 0; i--) {
      final char = text[i];
      if (char.contains(RegExp(r'\s')) || char == '\n') {
        return i + 1;
      }
    }
    return 0;
  }

  int? _findTokenEnd(String text, int index) {
    for (var i = index; i < text.length; i++) {
      final char = text[i];
      if (char.contains(RegExp(r'\s')) || char == '\n') {
        return i;
      }
    }
    return text.length;
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
              Text(AppLocalizations.of(context)!.repeat, style: TextStyle(fontWeight: FontWeight.w500, color: colors.textPrimary)),
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
        _recurrenceChip(AppLocalizations.of(context)!.daily, RecurringInterval.daily),
        const SizedBox(width: 8),
        _recurrenceChip(AppLocalizations.of(context)!.weekly, RecurringInterval.weekly),
        const SizedBox(width: 8),
        _recurrenceChip(AppLocalizations.of(context)!.monthly, RecurringInterval.monthly),
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
                    child: isThemeDefault ? Icon(Icons.brightness_auto, size: 18, color: sheetColors.textSecondary) : null,
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
