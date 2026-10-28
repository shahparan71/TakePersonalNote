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
import 'package:take_personal_note/widgets/sheet_safe_area.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:take_personal_note/utils/url_utils.dart';

class NoteEditScreen extends StatefulWidget {
  final MyNote? note;
  final String? initialText;
  final String? initialCategory;

  const NoteEditScreen({super.key, this.note, this.initialText, this.initialCategory});

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

    final l10n = AppLocalizations.of(context)!;
    final noteReminderTitle = l10n.noteReminder;
    final untitledTitle = l10n.untitled;

    if (widget.note == null) {
      final newNote = MyNote(
        title: _titleController.text.isEmpty ? "" : _titleController.text,
        content: _currentContent,
        type: NoteType.text,
        // Always text now
        color: _selectedColor,
        isPinned: _isPinned,
        category: widget.initialCategory,
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
            title: noteReminderTitle,
            body: _titleController.text.isEmpty ? untitledTitle : _titleController.text,
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
            title: noteReminderTitle,
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
    final now = DateTime.now();
    DateTime initialDate = _reminderTime ?? now;
    if (initialDate.isBefore(now)) initialDate = now;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2030),
    );
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now()),
      );
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
    await UrlUtils.openUrl(value);
  }

  @override
  Widget build(BuildContext context) {
    _refreshPhoneNumberStyles();
    final colors = context.appColors;
    final scaffoldColor = colors.noteEditorBackground(_selectedColor);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _saveNote();
        if (mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 54,
          leading: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Center(
              child: _EditorActionButton(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),
          actions: [
            _EditorActionButton(
              icon: _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              tooltip: _isPinned ? 'Unpin' : 'Pin',
              isActive: _isPinned,
              activeColor: AppColors.actionPin,
              activeIconColor: AppColors.actionPin,
              onPressed: () => setState(() => _isPinned = !_isPinned),
            ),
            const SizedBox(width: 8),
            _EditorActionButton(
              icon: _reminderTime == null ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
              tooltip: _reminderTime == null ? 'Set reminder' : 'Clear reminder',
              isActive: _reminderTime != null,
              activeColor: Colors.amber.shade700,
              activeIconColor: Colors.amber.shade800,
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
            ),
            const SizedBox(width: 8),
            _EditorActionButton(
              icon: Icons.palette_outlined,
              tooltip: 'Note color',
              isActive: _selectedColor != AppPalette.themeDefaultNoteColor,
              activeColor: Color(_selectedColor),
              customIcon: _selectedColor != AppPalette.themeDefaultNoteColor
                  ? Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Color(_selectedColor),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.textPrimary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                    )
                  : null,
              onPressed: _showColorPicker,
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: _EditorPrimaryButton(
                  icon: Icons.check_rounded,
                  tooltip: 'Save',
                  onPressed: () => Navigator.maybePop(context),
                ),
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
                      padding: const EdgeInsets.only(left: 18, right: 18, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _titleController,
                            textAlign: TextAlign.start,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.addTitle,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                              hintStyle: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: colors.textSecondary.withValues(alpha: 0.38),
                              ),
                            ),
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          _buildMetadataRow(),
                          const Divider(height: 16, thickness: 0.5),
                          if (_reminderTime != null) _buildReminderCard(colors),
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
                                    GoogleFonts.outfit(fontSize: 16, color: colors.textPrimary, height: 1.6),
                                    const quill.HorizontalSpacing(0, 0),
                                    const quill.VerticalSpacing(0, 0),
                                    const quill.VerticalSpacing(0, 0),
                                    null,
                                  ),
                                  placeHolder: quill.DefaultTextBlockStyle(
                                    GoogleFonts.outfit(fontSize: 16, color: colors.textSecondary.withValues(alpha: 0.45), height: 1.6),
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
                    decoration: BoxDecoration(
                      color: colors.cardSurface,
                      border: Border(
                        top: BorderSide(color: colors.border.withValues(alpha: 0.7), width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
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
    final category = widget.note?.category ?? widget.initialCategory;
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(widget.note?.updatedAt ?? DateTime.now());
    final charCount = _contentController.document.toPlainText().trim().length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 13,
            color: colors.textSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 5),
          Text(
            dateStr,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: colors.textSecondary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '•',
            style: TextStyle(
              color: colors.textSecondary.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$charCount characters',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: colors.textSecondary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (category != null && category.trim().isNotEmpty) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 12,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    category,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderCard(AppPalette colors) {
    if (_reminderTime == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.shade700.withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main reminder info row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.amber.shade800,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _selectReminder,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                AppDateUtils.formatReminder(_reminderTime!),
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.edit_rounded,
                                size: 13,
                                color: colors.textSecondary.withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                          if (_isRecurring && _recurringInterval != RecurringInterval.none) ...[
                            const SizedBox(height: 2),
                            _buildNextOccurrenceDisplay(colors),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Remove button
                IconButton(
                  tooltip: 'Remove reminder',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.textSecondary.withValues(alpha: 0.8),
                  ),
                  splashRadius: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      _reminderTime = null;
                      _isRecurring = false;
                      _recurringInterval = RecurringInterval.none;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          // Recurrence row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.repeat_rounded, size: 17, color: colors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      l10n.repeat,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Transform.scale(
                      scale: 0.82,
                      child: Switch.adaptive(
                        activeTrackColor: colors.fabDark,
                        value: _isRecurring,
                        onChanged: (val) => setState(() {
                          _isRecurring = val;
                          if (val && _recurringInterval == RecurringInterval.none) {
                            _recurringInterval = RecurringInterval.daily;
                          }
                        }),
                      ),
                    ),
                  ],
                ),
                if (_isRecurring) ...[
                  const SizedBox(height: 6),
                  _buildRecurrenceChips(colors),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurrenceChips(AppPalette colors) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _recurrenceChip(l10n.daily, RecurringInterval.daily, colors),
          const SizedBox(width: 8),
          _recurrenceChip(l10n.weekly, RecurringInterval.weekly, colors),
          const SizedBox(width: 8),
          _recurrenceChip(l10n.monthly, RecurringInterval.monthly, colors),
        ],
      ),
    );
  }

  Widget _recurrenceChip(String label, RecurringInterval interval, AppPalette colors) {
    final selected = _recurringInterval == interval;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? Colors.white : colors.textPrimary,
        ),
      ),
      selected: selected,
      selectedColor: colors.fabDark,
      backgroundColor: colors.scaffoldBg,
      side: BorderSide(
        color: selected ? Colors.transparent : colors.border,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (_) => _setRecurrenceInterval(interval),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildNextOccurrenceDisplay(AppPalette colors) {
    final nextDate = AppDateUtils.calculateNextOccurrence(_reminderTime, _recurringInterval);
    if (nextDate == null) return const SizedBox.shrink();
    return Text(
      'Next: ${AppDateUtils.formatReminder(nextDate)}',
      style: GoogleFonts.outfit(
        fontSize: 11,
        color: colors.textSecondary,
        fontWeight: FontWeight.w400,
      ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SheetSafeArea(
          includeNavBar: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: sheetColors.textSecondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Note Color',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: sheetColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: swatchColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? sheetColors.fabDark : sheetColors.border,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: sheetColors.fabDark.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isThemeDefault
                              ? Icon(
                                  Icons.brightness_auto,
                                  size: 16,
                                  color: sheetColors.textSecondary,
                                )
                              : (isSelected
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: ThemeData.estimateBrightnessForColor(Color(colors[index])) == Brightness.dark
                                          ? Colors.white
                                          : Colors.black87,
                                    )
                                  : null),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EditorActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isActive;
  final Color? activeColor;
  final Color? activeIconColor;
  final Widget? customIcon;

  const _EditorActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isActive = false,
    this.activeColor,
    this.activeIconColor,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final Color bgColor;
    final Color borderColor;
    final Color iconColor;

    if (isActive) {
      final base = activeColor ?? colors.fabDark;
      bgColor = base.withValues(alpha: 0.16);
      borderColor = base.withValues(alpha: 0.38);
      iconColor = activeIconColor ?? base;
    } else {
      bgColor = colors.textSecondary.withValues(alpha: 0.08);
      borderColor = colors.border.withValues(alpha: 0.6);
      iconColor = colors.textSecondary;
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            alignment: Alignment.center,
            child: customIcon ?? Icon(icon, size: 19, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _EditorPrimaryButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _EditorPrimaryButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.actionSave,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.actionSave.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
