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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF54BF8F),
            flexibleSpace: FlexibleSpaceBar(
              expandedTitleScale: 1.1,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 20, right: 20),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getGreeting(),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Welcome back!',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
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
                      right: -30,
                      top: 40,
                      child: Icon(
                        Icons.auto_awesome_mosaic_rounded,
                        size: 200,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 60,
                      child: Text(
                        DateFormat('EEEE, MMMM d').format(now),
                        style: GoogleFonts.outfit(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.archive_outlined, color: Colors.black87, size: 20),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ArchiveScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.black87, size: 20),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrashScreen()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.black87, size: 20),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'Overview',
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                _buildStatsGrid(context),
                const SizedBox(height: 32),
                Text(
                  'Upcoming Tasks',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 12),
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
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: [
            InkWell(
              onTap: () => tabProvider.setIndex(1), // Notes tab
              child: _buildStatCard('Total Notes', noteProvider.notes.length.toString(), Colors.indigo, Icons.description_outlined),
            ),
            InkWell(
              onTap: () => tabProvider.setIndex(2), // Tasks tab
              child: _buildStatCard('Pending Tasks', taskProvider.getTasksByStatus(TaskStatus.pending).length.toString(), Colors.orange, Icons.assignment_late_outlined),
            ),
            _buildStatCard('Pinned Notes', noteProvider.notes.where((n) => n.isPinned).length.toString(), Colors.pink, Icons.push_pin_outlined),
            _buildStatCard('Completed', taskProvider.getTasksByStatus(TaskStatus.completed).length.toString(), Colors.green, Icons.task_alt_outlined),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: const Center(
              child: Text('No upcoming reminders', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return Column(
          children: upcoming.take(3).map((task) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.alarm, color: Colors.blue, size: 20),
              ),
              title: Text(task.title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16)),
              subtitle: Builder(
                builder: (context) {
                  DateTime? displayTime = task.reminderTime;
                  if (task.reminderTime != null && task.isRecurring && task.reminderTime!.isBefore(DateTime.now())) {
                    displayTime = AppDateUtils.calculateNextOccurrence(task.reminderTime, task.recurringInterval) ?? task.reminderTime;
                  }
                  return Text(
                    displayTime != null ? AppDateUtils.formatReminder(displayTime) : '',
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
              trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Icon(Icons.more_horiz, color: Colors.grey[300], size: 18),
            ],
          ),
          const Spacer(),
          Text(value, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -1)),
          Text(label, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
