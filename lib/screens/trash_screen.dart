import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/note_provider.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trash')),
      body: Consumer<NoteProvider>(
        builder: (context, provider, child) {
          if (provider.trashedNotes.isEmpty) {
            return const Center(child: Text('Trash is empty'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.trashedNotes.length,
            itemBuilder: (context, index) {
              final note = provider.trashedNotes[index];
              return Card(
                child: ListTile(
                  title: Text(note.title),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore),
                        onPressed: () => provider.restoreNote(note),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () => provider.deleteNotePermanent(note.id!),
                      ),
                    ],
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
