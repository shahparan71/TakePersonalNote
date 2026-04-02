import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:take_personal_note/models/task.dart';
import 'package:take_personal_note/services/note_provider.dart';

import '../services/task_provider.dart';
import 'archive_screen.dart';
import 'trash_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Dashboard', 
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800)),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              background: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.withOpacity(0.05), Colors.white],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(Icons.dashboard_rounded, size: 120, color: Colors.blue.withOpacity(0.03)),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.black),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text(
                  'Your Overview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildStatsGrid(context),
                const SizedBox(height: 32),
                const Text(
                  'Quick Access',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                _buildQuickLinks(context),
                const SizedBox(height: 32),
                const Text(
                  'Upcoming Tasks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
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
    return Consumer2<NoteProvider, TaskProvider>(
      builder: (context, noteProvider, taskProvider, child) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: [
            _buildStatCard('Total Notes', noteProvider.notes.length.toString(), Colors.blue),
            _buildStatCard('Pending Tasks', taskProvider.getTasksByStatus(TaskStatus.pending).length.toString(), Colors.orange),
            _buildStatCard('Pinned Notes', noteProvider.notes.where((n) => n.isPinned).length.toString(), Colors.purple),
            _buildStatCard('Due Today', '0', Colors.red),
          ],
        );
      },
    );
  }

  Widget _buildQuickLinks(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Archive'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArchiveScreen()),
            ),
          ),
        ),
        Expanded(
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Trash'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTasks(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        final upcoming = provider.tasks
            .where((t) => t.status != TaskStatus.completed && t.reminderTime != null)
            .toList()
          ..sort((a, b) => a.reminderTime!.compareTo(b.reminderTime!));

        if (upcoming.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No upcoming reminders', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return Column(
          children: upcoming.take(3).map((task) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(task.reminderTime != null 
                ? 'Remind at ${task.reminderTime!.hour}:${task.reminderTime!.minute.toString().padLeft(2, '0')}' 
                : ''),
              trailing: Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.analytics_outlined, color: color, size: 20),
          ),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color, letterSpacing: -1)),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
