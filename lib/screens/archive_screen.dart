import 'package:take_personal_note/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/note_provider.dart';
import '../models/note.dart';
import '../theme/app_colors.dart';
import '../utils/note_utils.dart';
import '../routes/app_routes.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.scaffoldBg,
        title: Text(AppLocalizations.of(context)!.archive, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: colors.textPrimary)),
      ),
      body: Consumer<NoteProvider>(
        builder: (context, provider, child) {
          if (provider.archivedNotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.noArchivedNotes, style: GoogleFonts.outfit(color: colors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.archiveInstruction,
                    style: GoogleFonts.outfit(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.archivedNotes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final note = provider.archivedNotes[index];
              return _ArchiveCard(
                note: note,
                onUnarchive: () => provider.unarchiveNote(note),
                onTap: () => Navigator.pushNamed(context, AppRoutes.noteEdit, arguments: {'note': note}),
              );
            },
          );
        },
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  final MyNote note;
  final VoidCallback onUnarchive;
  final VoidCallback onTap;

  const _ArchiveCard({required this.note, required this.onUnarchive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(note.color),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.title.isEmpty ? AppLocalizations.of(context)!.untitled : note.title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      NoteUtils.getPlainText(note.content),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(note.updatedAt),
                      style: TextStyle(fontSize: 10, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.unarchive_outlined, color: colors.fabDark),
                tooltip: AppLocalizations.of(context)!.restore,
                onPressed: onUnarchive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
