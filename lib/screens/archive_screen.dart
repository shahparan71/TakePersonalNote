import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/note_provider.dart';
import '../models/note.dart';
import 'note_edit_screen.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: Consumer<NoteProvider>(
        builder: (context, provider, child) {
          if (provider.archivedNotes.isEmpty) {
            return const Center(child: Text('No archived notes'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.archivedNotes.length,
            itemBuilder: (context, index) {
              final note = provider.archivedNotes[index];
              return Card(
                child: ListTile(
                  title: Text(note.title),
                  subtitle: Text(note.content, maxLines: 1),
                  trailing: IconButton(
                    icon: const Icon(Icons.unarchive),
                    onPressed: () => provider.unarchiveNote(note),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
