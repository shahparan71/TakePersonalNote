import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:take_personal_note/models/note.dart';
import 'package:take_personal_note/services/note_provider.dart';
import 'package:take_personal_note/services/notification_service.dart';
import 'package:intl/intl.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? note;
  const NoteEditScreen({super.key, this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  int _selectedColor = 0xFFFFFFFF;
  bool _isPinned = false;
  DateTime? _reminderTime;
  NoteType _type = NoteType.text;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _selectedColor = widget.note?.color ?? 0xFFFFFFFF;
    _isPinned = widget.note?.isPinned ?? false;
    _reminderTime = widget.note?.reminderTime;
    _type = widget.note?.type ?? NoteType.text;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    if (_titleController.text.isEmpty && _contentController.text.isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);
    final now = DateTime.now();

    if (widget.note == null) {
      final newNote = Note(
        title: _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
        content: _contentController.text,
        color: _selectedColor,
        isPinned: _isPinned,
        type: _type,
        createdAt: now,
        updatedAt: now,
      );
      provider.addNote(newNote).then((id) {
        if (_reminderTime != null) {
          NotificationService().scheduleNotification(
            id: id ?? DateTime.now().millisecond,
            title: 'Note Reminder',
            body: _titleController.text,
            scheduledDate: _reminderTime!,
          );
        }
      });
    } else {
      final updatedNote = widget.note!.copyWith(
        title: _titleController.text,
        content: _contentController.text,
        color: _selectedColor,
        isPinned: _isPinned,
        type: _type,
        reminderTime: _reminderTime,
        updatedAt: now,
      );
      provider.updateNote(updatedNote).then((_) {
        if (_reminderTime != null) {
          NotificationService().scheduleNotification(
            id: widget.note!.id!,
            title: 'Note Reminder',
            body: _titleController.text,
            scheduledDate: _reminderTime!,
          );
        } else if (widget.note!.reminderTime != null) {
          NotificationService().cancelNotification(widget.note!.id!);
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
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now()),
      );
      if (pickedTime != null) {
        setState(() {
          _reminderTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: _showColorPicker,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              _saveNote();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const Divider(),
            IconButton(
              icon: Icon(_reminderTime == null ? Icons.notifications_none : Icons.notifications_active),
              onPressed: _selectReminder,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _reminderTime != null
                  ? Text(
                      'Reminder: ${DateFormat('MMM d, h:mm a').format(_reminderTime!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    )
                  : const SizedBox(),
            ),
            Checkbox(
              value: _isPinned,
              onChanged: (val) => setState(() => _isPinned = val!),
            ),
            const Text('Pin'),
            IconButton(
              icon: Icon(_type == NoteType.checklist ? Icons.checklist : Icons.text_fields),
              onPressed: () => setState(() => _type = _type == NoteType.text ? NoteType.checklist : NoteType.text),
            ),
            const Text('Type'),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: _type == NoteType.text ? 'Start typing...' : '- [ ] New item',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    final colors = [
      0xFFFFFFFF, // white
      0xFFFFCDD2, // red
      0xFFF8BBD0, // pink
      0xFFE1BEE7, // purple
      0xFFC5CAE9, // indigo
      0xFFBBDEFB, // blue
      0xFFB2EBF2, // cyan
      0xFFC8E6C9, // green
      0xFFDCEDC8, // light green
      0xFFF0F4C3, // lime
      0xFFFFF9C4, // yellow
      0xFFFFE0B2, // orange
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 200,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
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
        );
      },
    );
  }
}
