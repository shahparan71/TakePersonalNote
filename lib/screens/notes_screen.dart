import 'package:take_personal_note/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:take_personal_note/models/note.dart';
import 'package:take_personal_note/routes/app_routes.dart';
import 'package:take_personal_note/services/folder_provider.dart';
import 'package:take_personal_note/services/google_drive_sync_service.dart';
import 'package:take_personal_note/services/note_provider.dart';
import 'package:take_personal_note/services/preference_service.dart';
import 'package:take_personal_note/theme/app_colors.dart';
import 'package:take_personal_note/utils/date_utils.dart';
import 'package:take_personal_note/utils/note_utils.dart';
import 'package:take_personal_note/widgets/design_widgets.dart';
import 'package:take_personal_note/widgets/sheet_safe_area.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  late ScrollController _scrollController;
  String? _selectedFolder;
  bool _isListView = true;
  bool _selectionMode = false;
  final Set<int> _selectedNoteIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final mode = await PreferenceService().getNotesViewMode();
    if (mounted) setState(() => _isListView = mode != 'card');
  }

  Future<void> _toggleViewMode() async {
    setState(() => _isListView = !_isListView);
    await PreferenceService().setNotesViewMode(_isListView ? 'list' : 'card');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedNoteIds.clear();
    });
  }

  void _enterSelectionMode(MyNote note) {
    setState(() {
      _selectionMode = true;
      if (note.id != null) _selectedNoteIds.add(note.id!);
    });
  }

  void _toggleNoteSelection(int id) {
    setState(() {
      if (_selectedNoteIds.contains(id)) {
        _selectedNoteIds.remove(id);
        if (_selectedNoteIds.isEmpty) _selectionMode = false;
      } else {
        _selectedNoteIds.add(id);
      }
    });
  }

  List<MyNote> _filteredNotes(List<MyNote> notes) {
    if (_selectedFolder == null) return notes;
    return notes.where((n) => n.category == _selectedFolder).toList();
  }

  void _refreshNotes() {
    Provider.of<NoteProvider>(
      context,
      listen: false,
    ).fetchNotes(query: _searchController.text.isEmpty ? null : _searchController.text, category: _selectedFolder);
  }

  @override
  Widget build(BuildContext context) {
    final bottomBarHeight = _selectionMode ? 72.0 : 0.0;
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            elevation: 0,
            backgroundColor: colors.scaffoldBg,
            leading: _selectionMode ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode) : null,
            title: _selectionMode
                ? Text('${_selectedNoteIds.length} selected', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))
                : Consumer<NoteProvider>(
                    builder: (context, _, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSyncIcon(),
                          Text(AppLocalizations.of(context)!.notesTitle, style: GoogleFonts.caveat(fontWeight: FontWeight.w600, fontSize: 32)),
                        ],
                      );
                    },
                  ),
            actions: [
              if (!_selectionMode) ...[
                Consumer<NoteProvider>(
                  builder: (context, provider, _) {
                    final count = provider.hiddenNotes.length;
                    return IconButton(
                      icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.visibility_off_outlined)),
                      tooltip: AppLocalizations.of(context)!.hiddenNotesTooltip,
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.hiddenNotes).then((_) => _refreshNotes()),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(_isListView ? Icons.grid_view : Icons.view_list),
                  onPressed: _toggleViewMode,
                  tooltip: _isListView ? AppLocalizations.of(context)!.cardViewTooltip : AppLocalizations.of(context)!.listViewTooltip,
                ),
                IconButton(icon: const Icon(Icons.swap_vert), onPressed: () => _showSortDialog(context), tooltip: AppLocalizations.of(context)!.sortTooltip),
              ],
            ],
            floating: true,
            pinned: true,
          ),
          if (!_selectionMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchNotes,
                    filled: true,
                    fillColor: colors.cardSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) {
                    Provider.of<NoteProvider>(context, listen: false).fetchNotes(query: val.isEmpty ? null : val, category: _selectedFolder);
                  },
                ),
              ),
            ),
          if (!_selectionMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _buildFolderBar(),
              ),
            ),
          Consumer<NoteProvider>(
            builder: (context, provider, child) {
              final notes = _filteredNotes(provider.notes);
              if (notes.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      _selectedFolder == null ? AppLocalizations.of(context)!.noNotesYet : AppLocalizations.of(context)!.noNotesInFolder,
                      style: TextStyle(color: colors.textSecondary, fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              }
              return _isListView ? _buildSliverListView(notes) : _buildSliverGridView(notes);
            },
          ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : DesignFab(
              heroTag: 'notes_fab',
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.noteEdit,
                arguments: _selectedFolder != null ? {'initialCategory': _selectedFolder} : null,
              ).then((_) => _refreshNotes()),
            ),
      bottomNavigationBar: _selectionMode
          ? Container(
              height: bottomBarHeight,
              color: colors.cardSurface,
              child: _buildSelectionActionBar(),
            )
          : null,
    );
  }

  Widget _buildFolderBar() {
    final colors = context.appColors;
    return Consumer<FolderProvider>(
      builder: (context, folderProvider, _) {
        final folders = folderProvider.folders;
        return SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _folderChip(AppLocalizations.of(context)!.all, null),
              ...folders.map((f) => _folderChip(f, f)),
              _newFolderChip(colors),
            ],
          ),
        );
      },
    );
  }

  Widget _folderChip(String label, String? folder) {
    final selected = _selectedFolder == folder;
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() => _selectedFolder = folder);
          _refreshNotes();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFF6C844)
                : (Theme.of(context).brightness == Brightness.dark
                    ? colors.cardSurface
                    : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.black87 : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _newFolderChip(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _showCreateFolderDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? colors.cardSurface
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.newFolder,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverGridView(List<MyNote> notes) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childCount: notes.length,
        itemBuilder: (context, index) => _buildNoteCard(notes[index]),
      ),
    );
  }

  Widget _buildSliverListView(List<MyNote> notes) {
    final colors = context.appColors;
    return SliverPadding(
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      sliver: SliverList.separated(
        itemCount: notes.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 0.8,
          color: colors.border.withValues(alpha: 0.45),
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) => _buildNoteListItem(notes[index]),
      ),
    );
  }

  Widget _buildNoteListItem(MyNote note) {
    final isSelected = note.id != null && _selectedNoteIds.contains(note.id);
    final colors = context.appColors;
    final badgeColor = _getNoteBadgeColor(note, colors);
    final iconData = _getNoteIcon(note);
    final displayTitle = NoteUtils.getDisplayTitle(title: note.title, content: note.content);
    final snippet = NoteUtils.getPlainText(note.content);

    return Material(
      color: isSelected ? colors.fabDark.withValues(alpha: 0.1) : Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectionMode && note.id != null) {
            _toggleNoteSelection(note.id!);
          } else if (!_selectionMode) {
            Navigator.pushNamed(context, AppRoutes.noteEdit, arguments: {'note': note}).then((_) => _refreshNotes());
          }
        },
        onLongPress: () {
          if (note.id != null) _enterSelectionMode(note);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Badge container based on note's color
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              // Note title, preview snippet, created and expiration dates
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (note.isPinned) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.push_pin, size: 14, color: Colors.orange),
                        ],
                      ],
                    ),
                    if (snippet.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        snippet,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: colors.textSecondary.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    _buildNoteDatesRow(note, colors),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_selectionMode)
                Checkbox(
                  value: isSelected,
                  shape: const CircleBorder(),
                  onChanged: (_) {
                    if (note.id != null) _toggleNoteSelection(note.id!);
                  },
                )
              else
                _buildNoteTrailingMenu(note, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteDatesRow(MyNote note, AppPalette colors) {
    final secondaryStyle = GoogleFonts.outfit(
      fontSize: 11,
      color: colors.textSecondary.withValues(alpha: 0.75),
    );
    final hasReminder = note.reminderTime != null;
    final hasCategory = note.category != null && note.category!.isNotEmpty;
    final reminderPast = hasReminder && note.reminderTime!.isBefore(DateTime.now());
    final reminderColor = reminderPast ? Colors.red.shade400 : Colors.amber.shade800;

    // When expire/reminder date is NOT available:
    // Display single row with folder name to the left of created date.
    if (!hasReminder) {
      return Row(
        children: [
          if (hasCategory) ...[
            Icon(Icons.folder_outlined, size: 11, color: colors.textSecondary.withValues(alpha: 0.55)),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                note.category!,
                style: secondaryStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '•',
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            AppDateUtils.formatNoteDate(note.createdAt),
            style: secondaryStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    // When expire/reminder date IS available:
    // Row 1: created date
    // Row 2: reminder date + folder name
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppDateUtils.formatNoteDate(note.createdAt),
          style: secondaryStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 12,
              color: reminderColor,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                AppDateUtils.formatReminder(note.reminderTime!),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: reminderColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasCategory) ...[
              const SizedBox(width: 6),
              Icon(Icons.folder_outlined, size: 11, color: colors.textSecondary.withValues(alpha: 0.55)),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  note.category!,
                  style: secondaryStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildNoteTrailingMenu(MyNote note, AppPalette colors) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: colors.cardSurface,
      elevation: 4,
      onSelected: (value) async {
        final provider = Provider.of<NoteProvider>(context, listen: false);
        if (value == 'archive') {
          await provider.archiveNote(note);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Note archived'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => provider.unarchiveNote(note),
                ),
              ),
            );
          }
        } else if (value == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(AppLocalizations.of(ctx)!.deleteNotesTitle),
              content: const Text('Move note to trash?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(AppLocalizations.of(ctx)!.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    AppLocalizations.of(ctx)!.delete,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
          if (confirmed == true && mounted) {
            await provider.trashNote(note);
          }
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          value: 'archive',
          child: Row(
            children: [
              Icon(Icons.archive_outlined, size: 20, color: colors.textPrimary),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(ctx)!.archive,
                style: GoogleFonts.outfit(color: colors.textPrimary, fontSize: 14),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(ctx)!.delete,
                style: GoogleFonts.outfit(color: Colors.red, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getNoteBadgeColor(MyNote note, AppPalette colors) {
    switch (note.color) {
      case 0xFFFFCDD2:
      case 0xFFF8BBD0:
        return const Color(0xFFF87171); // Red / Coral
      case 0xFFE1BEE7:
      case 0xFFC5CAE9:
        return const Color(0xFF8B5CF6); // Purple
      case 0xFFBBDEFB:
      case 0xFFB2EBF2:
        return const Color(0xFF3B82F6); // Blue
      case 0xFFC8E6C9:
      case 0xFFDCEDC8:
        return const Color(0xFF10B981); // Green
      case 0xFFF0F4C3:
      case 0xFFFFF9C4:
      case 0xFFFFE0B2:
        return const Color(0xFFF59E0B); // Amber / Yellow
      case 0xFFFFFFFF:
      default:
        if (note.color != 0xFFFFFFFF && note.color != AppPalette.themeDefaultNoteColor) {
          return Color(note.color);
        }
        const defaultPalette = [
          Color(0xFF3B82F6), // Blue
          Color(0xFFF59E0B), // Yellow
          Color(0xFF10B981), // Green
          Color(0xFFF87171), // Red
          Color(0xFF8B5CF6), // Purple
        ];
        final id = note.id ?? 0;
        return defaultPalette[id.abs() % defaultPalette.length];
    }
  }

  IconData _getNoteIcon(MyNote note) {
    switch (note.type) {
      case NoteType.checklist:
        return Icons.checklist_rounded;
      case NoteType.image:
        return Icons.image_rounded;
      case NoteType.voice:
        return Icons.mic_rounded;
      case NoteType.text:
        return Icons.description_rounded;
    }
  }

  Widget _buildNoteCard(MyNote note) {
    final colors = context.appColors;
    return _buildNoteItem(
      note,
      isCard: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNoteHeader(note),
            const SizedBox(height: 6),
            Text(
              NoteUtils.getPlainText(note.content),
              style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.3),
              maxLines: 20,
              overflow: TextOverflow.ellipsis,
            ),
            _buildNoteFooter(note),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(MyNote note, {required bool isCard, required Widget child}) {
    final isSelected = note.id != null && _selectedNoteIds.contains(note.id);
    final colors = context.appColors;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: isCard ? 60 : 0),
      child: Container(
        decoration: BoxDecoration(
          color: colors.noteCardTint(note.color),
          borderRadius: BorderRadius.circular(isCard ? 20 : 14),
          border: isSelected ? Border.all(color: colors.fabDark, width: 2) : Border.all(color: colors.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(isCard ? 16 : 12),
            onTap: () {
              if (_selectionMode && note.id != null) {
                _toggleNoteSelection(note.id!);
              } else if (!_selectionMode) {
                Navigator.pushNamed(context, AppRoutes.noteEdit, arguments: {'note': note}).then((_) => _refreshNotes());
              }
            },
            onLongPress: () {
              if (note.id != null) _enterSelectionMode(note);
            },
            child: Stack(
              children: [
                if (isCard)
                  Positioned(
                    left: 0,
                    top: 16,
                    bottom: 16,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: note.color == AppPalette.themeDefaultNoteColor ? colors.fabDark : Color(note.color),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                      ),
                    ),
                  ),
                child,
                if (_selectionMode)
                  Positioned(
                    right: 8,
                    top: isCard ? null : 0,
                    bottom: isCard ? 12 : 0,
                    child: Center(
                      child: Checkbox(
                        value: isSelected,
                        shape: const CircleBorder(),
                        onChanged: (_) {
                          if (note.id != null) _toggleNoteSelection(note.id!);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteHeader(MyNote note) {
    final colors = context.appColors;
    final displayTitle = NoteUtils.getDisplayTitle(title: note.title, content: note.content);
    return Row(
      children: [
        Expanded(
          child: Text(
            displayTitle,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (note.isPinned) Icon(Icons.push_pin, size: 14, color: Colors.orange),
      ],
    );
  }

  Widget _buildNoteFooter(MyNote note) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(AppDateUtils.formatNoteDate(note.updatedAt), style: TextStyle(fontSize: 10, color: colors.textSecondary)),
          if (note.category != null && note.category!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Icon(Icons.folder_outlined, size: 11, color: colors.textSecondary),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                note.category!,
                style: TextStyle(fontSize: 10, color: colors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionActionBar() {
    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _actionButton(Icons.drive_file_move_outline, AppLocalizations.of(context)!.move, _moveToFolder),
              _actionButton(Icons.archive_outlined, AppLocalizations.of(context)!.archive, _archiveSelected),
              _actionButton(Icons.push_pin_outlined, AppLocalizations.of(context)!.pin, _pinSelected),
              _actionButton(Icons.visibility_off_outlined, AppLocalizations.of(context)!.hide, _hideSelected),
              _actionButton(Icons.delete_outline, AppLocalizations.of(context)!.delete, _deleteSelected, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final defaultColor = context.appColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color ?? defaultColor),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color ?? defaultColor)),
          ],
        ),
      ),
    );
  }

  List<MyNote> _getSelectedNotes(NoteProvider provider) {
    return provider.notes.where((n) => n.id != null && _selectedNoteIds.contains(n.id)).toList();
  }

  Future<void> _moveToFolder() async {
    final provider = Provider.of<NoteProvider>(context, listen: false);
    final folderProvider = Provider.of<FolderProvider>(context, listen: false);
    final folders = folderProvider.folders;
    final notes = _getSelectedNotes(provider);
    if (notes.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SheetSafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(AppLocalizations.of(context)!.moveToFolder, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: Text(AppLocalizations.of(context)!.removeFromFolder),
              onTap: () => Navigator.pop(context, ''),
            ),
            ...folders.map((f) => ListTile(leading: const Icon(Icons.folder_outlined), title: Text(f), onTap: () => Navigator.pop(context, f))),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null) return;
    for (final note in notes) {
      await provider.updateNote(note.copyWith(category: selected.isEmpty ? null : selected, updatedAt: DateTime.now()));
    }
    _exitSelectionMode();
    _refreshNotes();
  }

  Future<void> _archiveSelected() async {
    final provider = Provider.of<NoteProvider>(context, listen: false);
    for (final note in _getSelectedNotes(provider)) {
      await provider.archiveNote(note);
    }
    _exitSelectionMode();
  }

  Future<void> _pinSelected() async {
    final provider = Provider.of<NoteProvider>(context, listen: false);
    for (final note in _getSelectedNotes(provider)) {
      await provider.updateNote(note.copyWith(isPinned: !note.isPinned, updatedAt: DateTime.now()));
    }
    _exitSelectionMode();
  }

  Future<void> _hideSelected() async {
    final provider = Provider.of<NoteProvider>(context, listen: false);
    final notes = _getSelectedNotes(provider);
    if (notes.isEmpty) return;
    for (final note in notes) {
      await provider.hideNote(note);
    }
    _exitSelectionMode();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          notes.length == 1
              ? 'Note hidden. Tap the hidden icon in the app bar to view it.'
              : '${notes.length} notes hidden. Tap the hidden icon in the app bar to view them.',
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.hiddenNotes).then((_) => _refreshNotes()),
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final count = _selectedNoteIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.deleteNotesTitle),
        content: Text('Move $count note(s) to trash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx)!.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = Provider.of<NoteProvider>(context, listen: false);
    for (final note in _getSelectedNotes(provider)) {
      await provider.trashNote(note);
    }
    _exitSelectionMode();
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.newFolderTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: AppLocalizations.of(context)!.folderNameHint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
            onPressed: () async {
              await Provider.of<FolderProvider>(context, listen: false).addFolder(controller.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.create),
          ),
        ],
      ),
    );
  }

  void _showSortDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SheetSafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(title: Text(AppLocalizations.of(context)!.sortByDate), onTap: () => _sort('updatedAt DESC')),
            ListTile(title: Text(AppLocalizations.of(context)!.sortByTitle), onTap: () => _sort('title ASC')),
            ListTile(title: Text(AppLocalizations.of(context)!.sortByColor), onTap: () => _sort('color ASC')),
          ],
        ),
      ),
    );
  }

  void _sort(String criteria) {
    Provider.of<NoteProvider>(context, listen: false).fetchNotes(orderBy: criteria, category: _selectedFolder);
    Navigator.pop(context);
  }

  Widget _buildSyncIcon() {
    return Consumer<GoogleDriveSyncService>(
      builder: (context, syncService, _) {
        if (!syncService.isSignedIn) return const SizedBox.shrink();

        return FutureBuilder<bool>(
          future: PreferenceService().isNotesPendingDriveSync(),
          builder: (context, snapshot) {
            final isPending = snapshot.data ?? false;

            if (syncService.isSyncing) {
              return const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (isPending) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: () {
                    syncService.syncToDrive();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: const Icon(Icons.cloud_upload_outlined, color: Colors.orange, size: 24),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}
