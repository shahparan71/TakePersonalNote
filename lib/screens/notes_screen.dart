import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/note_provider.dart';
import '../models/note.dart';
import '../models/recurring_interval.dart';
import 'note_edit_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search notes...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, size: 20),
          ),
          onChanged: (val) {
            Provider.of<NoteProvider>(context, listen: false).fetchNotes(query: val);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert),
            onPressed: () => _showSortDialog(context),
            tooltip: 'Sort Notes',
          ),
        ],
      ),
      body: Consumer<NoteProvider>(
        builder: (context, provider, child) {
          if (provider.notes.isEmpty) {
            return const Center(child: Text('No notes yet. Add one!'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: provider.notes.length,
            itemBuilder: (context, index) {
              final note = provider.notes[index];
              return _buildNoteCard(context, note);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'notes_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NoteEditScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)),
            ),
        onLongPress: () => _showQuickActions(context, note),
        child: Stack(
          children: [
            Positioned(
              left: 0, top: 20, bottom: 20,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: Color(note.color),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title.isEmpty ? 'Untitled' : note.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (note.isPinned)
                        const Icon(Icons.push_pin, size: 14, color: Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      note.content,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.reminderTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            'Reminder set',
                            style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showSortDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: const Text('Sort by Date'), onTap: () => _sort('updatedAt DESC')),
          ListTile(title: const Text('Sort by Title'), onTap: () => _sort('title ASC')),
          ListTile(title: const Text('Sort by Color'), onTap: () => _sort('color ASC')),
        ],
      ),
    );
  }

  void _sort(String criteria) {
    Provider.of<NoteProvider>(context, listen: false).fetchNotes(orderBy: criteria);
    Navigator.pop(context);
  }

  void _showQuickActions(BuildContext context, Note note) {
    final provider = Provider.of<NoteProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(note.isPinned ? 'Unpin' : 'Pin'),
            onTap: () {
              provider.updateNote(note.copyWith(isPinned: !note.isPinned));
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Archive'),
            onTap: () {
              provider.updateNote(note.copyWith(isArchived: true));
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              provider.updateNote(note.copyWith(isTrashed: true, deletedAt: DateTime.now()));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
