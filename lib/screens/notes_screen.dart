import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/note_provider.dart';
import '../services/folder_provider.dart';
import '../services/preference_service.dart';
import '../models/note.dart';
import '../widgets/sheet_safe_area.dart';
import '../widgets/design_widgets.dart';
import '../theme/app_colors.dart';
import 'note_edit_screen.dart';
import 'hidden_notes_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFolder;
  bool _isListView = false;
  bool _selectionMode = false;
  final Set<int> _selectedNoteIds = {};

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final mode = await PreferenceService().getNotesViewMode();
    if (mounted) setState(() => _isListView = mode == 'list');
  }

  Future<void> _toggleViewMode() async {
    setState(() => _isListView = !_isListView);
    await PreferenceService().setNotesViewMode(_isListView ? 'list' : 'card');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedNoteIds.clear();
    });
  }

  void _enterSelectionMode(Note note) {
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

  List<Note> _filteredNotes(List<Note> notes) {
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

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.scaffoldBg,
        leading: _selectionMode ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode) : null,
        title: _selectionMode
            ? Text('${_selectedNoteIds.length} selected', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))
            : Text('Notes', style: GoogleFonts.caveat(fontWeight: FontWeight.w600, fontSize: 32)),
        actions: [
          if (!_selectionMode) ...[
            Consumer<NoteProvider>(
              builder: (context, provider, _) {
                final count = provider.hiddenNotes.length;
                return IconButton(
                  icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.visibility_off_outlined)),
                  tooltip: 'Hidden notes',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HiddenNotesScreen())).then((_) => _refreshNotes()),
                );
              },
            ),
            IconButton(
              icon: Icon(_isListView ? Icons.grid_view : Icons.view_list),
              onPressed: _toggleViewMode,
              tooltip: _isListView ? 'Card view' : 'List view',
            ),
            IconButton(icon: const Icon(Icons.swap_vert), onPressed: () => _showSortDialog(context), tooltip: 'Sort'),
          ],
        ],
        bottom: _selectionMode
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(108),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search notes...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (val) {
                          Provider.of<NoteProvider>(context, listen: false).fetchNotes(query: val.isEmpty ? null : val, category: _selectedFolder);
                        },
                      ),
                    ),
                    _buildFolderBar(),
                  ],
                ),
              ),
      ),
      body: Stack(
        children: [
          Consumer<NoteProvider>(
            builder: (context, provider, child) {
              final notes = _filteredNotes(provider.notes);
              if (notes.isEmpty) {
                return Center(
                  child: Text(
                    _selectedFolder == null ? 'No notes yet. Add one!' : 'No notes in this folder',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.only(bottom: bottomBarHeight + 72),
                child: _isListView ? _buildListView(notes) : _buildGridView(notes),
              );
            },
          ),
          if (_selectionMode) _buildSelectionActionBar(),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : DesignFab(
              heroTag: 'notes_fab',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteEditScreen())).then((_) => _refreshNotes()),
            ),
    );
  }

  Widget _buildFolderBar() {
    return Consumer<FolderProvider>(
      builder: (context, folderProvider, _) {
        final folders = folderProvider.folders;
        return SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _folderChip('All', null),
              ...folders.map((f) => _folderChip(f, f)),
              ActionChip(
                avatar: const Icon(Icons.create_new_folder_outlined, size: 16),
                label: const Text('New', style: TextStyle(fontSize: 12)),
                onPressed: _showCreateFolderDialog,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _folderChip(String label, String? folder) {
    final selected = _selectedFolder == folder;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : null)),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedFolder = folder);
          _refreshNotes();
        },
        visualDensity: VisualDensity.compact,
        showCheckmark: false,
      ),
    );
  }

  Widget _buildGridView(List<Note> notes) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) => _buildNoteCard(notes[index]),
    );
  }

  Widget _buildListView(List<Note> notes) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildNoteListTile(notes[index]),
    );
  }

  Widget _buildNoteCard(Note note) {
    return _buildNoteItem(
      note,
      isCard: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNoteHeader(note),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                note.content,
                style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.3),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildNoteFooter(note),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteListTile(Note note) {
    return _buildNoteItem(
      note,
      isCard: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(color: Color(note.color), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNoteHeader(note),
                  const SizedBox(height: 4),
                  Text(
                    note.content,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _buildNoteFooter(note),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(Note note, {required bool isCard, required Widget child}) {
    final isSelected = note.id != null && _selectedNoteIds.contains(note.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.noteCardTint(note.color),
        borderRadius: BorderRadius.circular(isCard ? 20 : 14),
        border: isSelected ? Border.all(color: AppColors.fabDark, width: 2) : Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isCard ? 16 : 12),
          onTap: () {
            if (_selectionMode && note.id != null) {
              _toggleNoteSelection(note.id!);
            } else if (!_selectionMode) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditScreen(note: note))).then((_) => _refreshNotes());
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
                      color: Color(note.color),
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
    );
  }

  Widget _buildNoteHeader(Note note) {
    return Row(
      children: [
        Expanded(
          child: Text(
            note.title.isEmpty ? 'Untitled' : note.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (note.isPinned) const Icon(Icons.push_pin, size: 14, color: Colors.blue),
      ],
    );
  }

  Widget _buildNoteFooter(Note note) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(DateFormat('MMM d, yyyy').format(note.updatedAt), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          if (note.category != null && note.category!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Icon(Icons.folder_outlined, size: 11, color: Colors.grey[400]),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                note.category!,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionActionBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        elevation: 12,
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _actionButton(Icons.drive_file_move_outline, 'Move', _moveToFolder),
                _actionButton(Icons.archive_outlined, 'Archive', _archiveSelected),
                _actionButton(Icons.push_pin_outlined, 'Pin', _pinSelected),
                _actionButton(Icons.visibility_off_outlined, 'Hide', _hideSelected),
                _actionButton(Icons.delete_outline, 'Delete', _deleteSelected, color: Colors.red),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color ?? Colors.black87),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color ?? Colors.black87)),
          ],
        ),
      ),
    );
  }

  List<Note> _getSelectedNotes(NoteProvider provider) {
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Move to folder', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Remove from folder'),
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
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HiddenNotesScreen())).then((_) => _refreshNotes()),
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete notes?'),
        content: Text('Move ${_selectedNoteIds.length} note(s) to trash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await Provider.of<FolderProvider>(context, listen: false).addFolder(controller.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
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
            ListTile(title: const Text('Sort by Date'), onTap: () => _sort('updatedAt DESC')),
            ListTile(title: const Text('Sort by Title'), onTap: () => _sort('title ASC')),
            ListTile(title: const Text('Sort by Color'), onTap: () => _sort('color ASC')),
          ],
        ),
      ),
    );
  }

  void _sort(String criteria) {
    Provider.of<NoteProvider>(context, listen: false).fetchNotes(orderBy: criteria, category: _selectedFolder);
    Navigator.pop(context);
  }
}
