import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:take_personal_note/models/task.dart';
import 'package:take_personal_note/services/note_provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:take_personal_note/services/tab_provider.dart';
import 'package:take_personal_note/utils/date_utils.dart';

import '../services/task_provider.dart';
import 'archive_screen.dart';
import 'trash_screen.dart';
import 'settings_screen.dart';
import 'task_edit_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF54BF8F),
            flexibleSpace: FlexibleSpaceBar(
              expandedTitleScale: 1.0,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 20, right: 20),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getGreeting(),
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.black87),
                  ),
                  Text(
                    'Welcome back!',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE4E3D1), Color(0xFFF8F6F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: 30,
                      child: Icon(Icons.auto_awesome_mosaic_rounded, size: 160, color: Colors.white.withOpacity(0.06)),
                    ),
                    Positioned(
                      left: 20,
                      top: 56,
                      child: Text(
                        DateFormat('EEEE, MMMM d').format(now),
                        style: GoogleFonts.outfit(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.archive_outlined, color: Colors.black87, size: 22),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchiveScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.black87, size: 22),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen())),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.black87, size: 22),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text('Overview', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                _buildStatsGrid(context),
                const SizedBox(height: 28),
                Text('Upcoming Tasks', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _buildUpcomingTasks(context),
              ]),
            ),
          ),
        ],
      ),
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
          childAspectRatio: 1.15,
          children: [
            _StatTile(
              label: 'Total Notes',
              value: noteProvider.notes.length.toString(),
              color: Colors.indigo,
              icon: Icons.description_outlined,
              onTap: () => tabProvider.setIndex(1),
            ),
            _StatTile(
              label: 'Pending Tasks',
              value: taskProvider.getTasksByStatus(TaskStatus.pending).length.toString(),
              color: Colors.orange,
              icon: Icons.assignment_late_outlined,
              onTap: () => tabProvider.setIndex(2),
            ),
            _StatTile(
              label: 'Pinned Notes',
              value: noteProvider.notes.where((n) => n.isPinned).length.toString(),
              color: Colors.pink,
              icon: Icons.push_pin_outlined,
              onTap: () => tabProvider.setIndex(1),
            ),
            _StatTile(
              label: 'Completed',
              value: taskProvider.getTasksByStatus(TaskStatus.completed).length.toString(),
              color: Colors.green,
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
    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        final upcoming = provider.tasks
            .where((t) => t.status != TaskStatus.completed && t.reminderTime != null && t.reminderTime!.isAfter(now))
            .toList()
          ..sort((a, b) => a.reminderTime!.compareTo(b.reminderTime!));

        if (upcoming.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Center(
              child: Text('No upcoming reminders', style: GoogleFonts.outfit(color: Colors.grey[500])),
            ),
          );
        }

        return Column(
          children: upcoming.take(3).map((task) {
            DateTime? displayTime = task.reminderTime;
            if (task.reminderTime != null && task.isRecurring && task.reminderTime!.isBefore(DateTime.now())) {
              displayTime = AppDateUtils.calculateNextOccurrence(task.reminderTime, task.recurringInterval) ??
                  task.reminderTime;
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.alarm, color: Colors.blue, size: 20),
                ),
                title: Text(task.title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text(
                  displayTime != null ? AppDateUtils.formatReminder(displayTime) : '',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskEditScreen(task: task)),
                ),
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
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
