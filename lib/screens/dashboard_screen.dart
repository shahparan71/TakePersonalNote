import 'package:take_personal_note/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:take_personal_note/models/task.dart';
import 'package:take_personal_note/services/note_provider.dart';
import 'package:take_personal_note/services/google_drive_sync_service.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:take_personal_note/services/tab_provider.dart';
import 'package:take_personal_note/utils/date_utils.dart';
import 'package:take_personal_note/theme/app_colors.dart';
import 'package:take_personal_note/widgets/design_widgets.dart';
import 'package:take_personal_note/utils/drive_sync_utils.dart';
import 'package:take_personal_note/services/preference_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/task_provider.dart';
import 'archive_screen.dart';
import 'trash_screen.dart';
import 'settings_screen.dart';
import 'task_edit_screen.dart';
import '../routes/app_routes.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isFetching = false;
  bool _isSyncingToDrive = false;

  @override
  void initState() {
    super.initState();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppLocalizations.of(context)!.goodMorning;
    if (hour < 17) return AppLocalizations.of(context)!.goodAfternoon;
    return AppLocalizations.of(context)!.goodEvening;
  }

  Future<void> _fetchFromGoogleDrive() async {
    setState(() => _isFetching = true);
    final result = await GoogleDriveSyncService().fetchFromDrive(merge: true);
    if (!mounted) return;
    setState(() => _isFetching = false);

    await applyDriveSyncResult(context, result);
    if (!mounted) return;
    showDriveSyncSnackBar(context, result);
  }

  Future<void> _syncLocalDataToGoogleDrive() async {
    setState(() => _isSyncingToDrive = true);
    final result = await GoogleDriveSyncService().syncToDrive();
    if (!mounted) return;
    setState(() => _isSyncingToDrive = false);

    await applyDriveSyncResult(context, result);
    if (!mounted) return;
    showDriveSyncSnackBar(context, result);
  }

  void _onFetchFromGoogleDrivePressed() {
    confirmFetchFromDrive(
      context,
      onConfirm: _fetchFromGoogleDrive,
    );
  }

  List<Task> _upcomingTasks(List<Task> tasks) {
    final now = DateTime.now();
    final upcoming = <Task>[];
    for (final t in tasks) {
      if (t.status == TaskStatus.completed || t.reminderTime == null) continue;
      DateTime? sortTime = t.reminderTime;
      if (t.isRecurring && t.reminderTime!.isBefore(now)) {
        sortTime = AppDateUtils.calculateNextOccurrence(t.reminderTime, t.recurringInterval);
      }
      if (sortTime != null && sortTime.isAfter(now)) {
        upcoming.add(t);
      }
    }
    upcoming.sort((a, b) {
      final aTime = _displayTime(a, now)!;
      final bTime = _displayTime(b, now)!;
      return aTime.compareTo(bTime);
    });
    return upcoming;
  }

  DateTime? _displayTime(Task task, DateTime now) {
    if (task.reminderTime == null) return null;
    if (task.isRecurring && task.reminderTime!.isBefore(now)) {
      return AppDateUtils.calculateNextOccurrence(task.reminderTime, task.recurringInterval);
    }
    return task.reminderTime;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 168,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: colors.scaffoldBg,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_getGreeting(), style: GoogleFonts.outfit(fontSize: 12, color: colors.textSecondary)),
                      Text(
                        AppLocalizations.of(context)!.takeNotes,
                        style: GoogleFonts.caveat(fontSize: 28, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ],
                  ),
                  background: Padding(
                    padding: const EdgeInsets.only(left: 20, top: 65),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        DateFormat('EEEE, MMMM d').format(now),
                        style: GoogleFonts.outfit(fontSize: 18, color: colors.textSecondary),
                      ),
                    ),
                  ),
                ),
                actions: [
                  Consumer<GoogleDriveSyncService>(
                    builder: (context, syncService, child) {
                      if (syncService.isSyncing) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.only(right: 8.0, left: 8.0),
                            child: _SyncingIcon(),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.archive_outlined, color: colors.textPrimary),
                    tooltip: AppLocalizations.of(context)!.archive,
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.archive),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colors.textPrimary),
                    tooltip: AppLocalizations.of(context)!.trash,
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.trash),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: colors.textPrimary),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.settings_screen),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    DesignSectionTitle(title: AppLocalizations.of(context)!.overview),
                    const SizedBox(height: 10),
                    _buildStatsGrid(context),
                    const SizedBox(height: 24),
                    DesignSectionTitle(
                      title: AppLocalizations.of(context)!.upcomingTasks,
                      trailing: AppLocalizations.of(context)!.seeAll,
                      onTrailingTap: () => Provider.of<TabProvider>(context, listen: false).setIndex(2),
                    ),
                    const SizedBox(height: 10),
                    _buildUpcomingTasks(context),
                    _buildEmptyRestoreBanner(context),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRestoreBanner(BuildContext context) {
    final colors = context.appColors;
    const googleDriveColor = Color(0xFF1A73E8);

    return Consumer2<NoteProvider, TaskProvider>(
      builder: (context, noteProvider, taskProvider, _) {
        final isEmpty = noteProvider.notes.isEmpty && taskProvider.tasks.isEmpty;

        if (isEmpty) {
          return Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.cardSurface,
                  googleDriveColor.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: googleDriveColor.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.cardSurface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(FontAwesomeIcons.googleDrive, size: 36, color: googleDriveColor),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.noNotesOrTasksYet,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: colors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.emptyWorkspaceRestore,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 14, color: colors.fabDark, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isFetching ? null : _onFetchFromGoogleDrivePressed,
                    icon: _isFetching
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(FontAwesomeIcons.googleDrive, size: 18),
                    label: Text(
                      _isFetching ? AppLocalizations.of(context)!.fetching : AppLocalizations.of(context)!.fetchFromGoogleDrive,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: googleDriveColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<bool>(
          future: _shouldShowLocalBackupBanner(noteCount: noteProvider.notes.length, taskCount: taskProvider.tasks.length),
          builder: (context, snapshot) {
            final shouldShow = snapshot.data ?? false;
            if (!shouldShow) {
              return Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: googleDriveColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: googleDriveColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: googleDriveColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(FontAwesomeIcons.googleDrive, size: 24, color: googleDriveColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.driveSyncActive,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: colors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context)!.driveSyncActiveDesc,
                            style: GoogleFonts.outfit(fontSize: 13, color: colors.textSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.cardSurface,
                    googleDriveColor.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: googleDriveColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.cardSurface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(FontAwesomeIcons.googleDrive, size: 36, color: googleDriveColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.localDataReady,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.saveLocalNotesDesc,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 14, color: colors.fabDark, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSyncingToDrive ? null : _syncLocalDataToGoogleDrive,
                      icon: _isSyncingToDrive
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(FontAwesomeIcons.googleDrive, size: 18),
                      label: Text(
                        _isSyncingToDrive ? AppLocalizations.of(context)!.uploading : AppLocalizations.of(context)!.saveToGoogleDrive,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: googleDriveColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _shouldShowLocalBackupBanner({required int noteCount, required int taskCount}) async {
    final prefs = PreferenceService();
    final notesPendingSync = await prefs.isNotesPendingDriveSync();
    final tasksPendingSync = await prefs.isTasksPendingDriveSync();
    
    if (GoogleDriveSyncService().isSignedIn) {
      return false;
    }

    return shouldShowLocalBackupBanner(
      noteCount: noteCount,
      taskCount: taskCount,
      notesPendingSync: notesPendingSync,
      tasksPendingSync: tasksPendingSync,
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Consumer3<NoteProvider, TaskProvider, TabProvider>(
      builder: (context, noteProvider, taskProvider, tabProvider, child) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _StatTile(
              label: AppLocalizations.of(context)!.notesTitle,
              value: noteProvider.notes.length.toString(),
              tint: context.appColors.statTileTint(2),
              icon: Icons.description_outlined,
              onTap: () => tabProvider.setIndex(1),
            ),
            _StatTile(
              label: AppLocalizations.of(context)!.pending,
              value: taskProvider.getTasksByStatus(TaskStatus.pending).length.toString(),
              tint: context.appColors.statTileTint(4),
              icon: Icons.assignment_outlined,
              onTap: () => tabProvider.setIndex(2),
            ),
            _StatTile(
              label: AppLocalizations.of(context)!.pinned,
              value: noteProvider.notes.where((n) => n.isPinned).length.toString(),
              tint: context.appColors.statTileTint(1),
              icon: Icons.push_pin_outlined,
              onTap: () => tabProvider.setIndex(1),
            ),
            _StatTile(
              label: AppLocalizations.of(context)!.done,
              value: taskProvider.getTasksByStatus(TaskStatus.completed).length.toString(),
              tint: context.appColors.statTileTint(3),
              icon: Icons.task_alt_outlined,
              onTap: () => tabProvider.setIndex(2),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingTasks(BuildContext context) {
    final now = DateTime.now();
    final colors = context.appColors;
    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        final upcoming = _upcomingTasks(provider.tasks);

        if (upcoming.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Center(
              child: Text(AppLocalizations.of(context)!.noUpcomingReminders, style: GoogleFonts.outfit(color: colors.textSecondary)),
            ),
          );
        }

        return Column(
          children: upcoming.take(5).map((task) {
            final displayTime = _displayTime(task, now);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.accentTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.alarm, color: colors.fabDark, size: 20),
                ),
                title: Text(task.title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15, color: colors.textPrimary)),
                subtitle: Text(
                  displayTime != null ? AppDateUtils.formatReminder(displayTime) : '',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                trailing: task.isRecurring
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppPalette.accentGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.recurringInterval.name,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      )
                    : Icon(Icons.chevron_right, size: 20, color: colors.textSecondary),
                onTap: () => Navigator.pushNamed(context, AppRoutes.taskEdit, arguments: {'task': task}),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color tint;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatTile({
    required this.label,
    required this.value,
    required this.tint,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.textPrimary.withValues(alpha: 0.7), size: 22),
              const Spacer(),
              Text(value, style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: colors.textPrimary)),
              Text(label, style: GoogleFonts.outfit(fontSize: 12, color: colors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncingIcon extends StatefulWidget {
  const _SyncingIcon();

  @override
  State<_SyncingIcon> createState() => _SyncingIconState();
}

class _SyncingIconState extends State<_SyncingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(Icons.sync, color: Colors.green, size: 24),
    );
  }
}
