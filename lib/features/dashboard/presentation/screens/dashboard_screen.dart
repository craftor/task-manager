import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../../time_tracking/presentation/providers/time_tracking_provider.dart' show timeEntriesProvider;
import '../../../journal/journal_provider.dart';
import '../../../mood/mood_provider.dart';
import '../../../special_days/special_days_provider.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/entities/project.dart';

class DashboardScreen extends ConsumerWidget {
  final Function(int)? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Dashboard'),
            const Spacer(),
            _CompactQuickActions(onNavigate: onNavigate),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: tasksAsync.when(
        data: (tasks) => _buildDashboard(context, ref, tasks, projectsAsync),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    List<Task> tasks,
    AsyncValue<List<Project>> projectsAsync,
  ) {
    final totalTasks = tasks.length;
    final pendingTasks = tasks.where((t) => t.status != TaskStatus.completed).length;
    final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).length;
    final now = DateTime.now();
    final overdueTasks = tasks.where((t) {
      if (t.status == TaskStatus.completed) return false;
      if (t.dueDate == null) return false;
      return t.dueDate!.isBefore(now);
    }).length;
    final highPriorityTasks = tasks.where((t) {
      return t.priority == Priority.high || t.priority == Priority.urgent;
    }).length;
    final totalProjects = projectsAsync.valueOrNull?.length ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatBox(label: 'Total', value: totalTasks.toString(), color: AppColors.primary),
                  _StatBox(label: 'Pending', value: pendingTasks.toString(), color: AppColors.warning),
                  _StatBox(label: 'Done', value: completedTasks.toString(), color: AppColors.success),
                  _StatBox(label: 'Overdue', value: overdueTasks.toString(), color: AppColors.error),
                  _StatBox(label: 'High', value: highPriorityTasks.toString(), color: Colors.orange),
                  _StatBox(label: 'Projects', value: totalProjects.toString(), color: AppColors.secondary),
                ],
              ),
              const SizedBox(height: 16),

              // Priority + Weekly
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _PriorityCard(tasks: tasks)),
                        const SizedBox(width: 12),
                        Expanded(child: _WeeklyCard(tasks: tasks)),
                      ],
                    )
                  : Column(
                      children: [
                        _PriorityCard(tasks: tasks),
                        const SizedBox(height: 12),
                        _WeeklyCard(tasks: tasks),
                      ],
                    ),
              const SizedBox(height: 12),

              // Project Progress
              _ProjectCard(tasks: tasks, projectsAsync: projectsAsync),
              const SizedBox(height: 12),

              // Time + Task Time
              isWide
                  ? const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _TimeCard()),
                        SizedBox(width: 12),
                        Expanded(child: _TaskTimeCard()),
                      ],
                    )
                  : const Column(
                      children: [
                        _TimeCard(),
                        SizedBox(height: 12),
                        _TaskTimeCard(),
                      ],
                    ),
              const SizedBox(height: 12),

              // Journal + Mood + Special Days
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _JournalCard(ref: ref)),
                        const SizedBox(width: 12),
                        Expanded(child: _MoodCard(ref: ref)),
                        const SizedBox(width: 12),
                        Expanded(child: _SpecialDaysCard(ref: ref)),
                      ],
                    )
                  : Column(
                      children: [
                        _JournalCard(ref: ref),
                        const SizedBox(height: 12),
                        _MoodCard(ref: ref),
                        const SizedBox(height: 12),
                        _SpecialDaysCard(ref: ref),
                      ],
                    ),
              const SizedBox(height: 12),

              // Recent Tasks
              _RecentTasksCard(tasks: tasks),
            ],
          ),
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final List<Task> tasks;

  const _PriorityCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final low = tasks.where((t) => t.priority == Priority.low).length;
    final medium = tasks.where((t) => t.priority == Priority.medium).length;
    final high = tasks.where((t) => t.priority == Priority.high).length;
    final urgent = tasks.where((t) => t.priority == Priority.urgent).length;
    final total = tasks.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Priority', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (total == 0) const Text('-', style: TextStyle(color: AppColors.textMuted))
          else ...[
            _Bar('Low', low, total, AppColors.secondary),
            const SizedBox(height: 4),
            _Bar('Med', medium, total, AppColors.warning),
            const SizedBox(height: 4),
            _Bar('High', high, total, Colors.orange),
            const SizedBox(height: 4),
            _Bar('Urgent', urgent, total, AppColors.error),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _Bar(this.label, this.count, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(width: 40, child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10))),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(width: 16, child: Text('$count', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
      ],
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  final List<Task> tasks;

  const _WeeklyCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final created = tasks.where((t) => t.createdAt.isAfter(weekAgo)).length;
    final done = tasks.where((t) => t.status == TaskStatus.completed && t.updatedAt.isAfter(weekAgo)).length;
    final rate = created > 0 ? '${(done / created * 100).toStringAsFixed(0)}%' : '0%';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This Week', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MiniStat('Created', '$created', AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('Done', '$done', AppColors.success)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('Rate', rate, AppColors.warning)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
      ]),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final List<Task> tasks;
  final AsyncValue<List<Project>> projectsAsync;

  const _ProjectCard({required this.tasks, required this.projectsAsync});

  @override
  Widget build(BuildContext context) {
    final projects = projectsAsync.valueOrNull;
    if (projects == null || projects.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Project Progress', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...projects.take(5).map((p) {
            final name = p.name;
            final pid = p.id;
            final isDefault = p.isDefault || name.toLowerCase() == 'default';
            final ptasks = tasks.where((t) => t.projectId == pid || (isDefault && (t.projectId == AppConstants.legacyDefaultProjectId || t.projectId == AppConstants.defaultProjectId))).toList();
            final total = ptasks.length;
            final done = ptasks.where((t) => t.status == TaskStatus.completed).length;
            final pct = total > 0 ? done / total : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: 60, child: Text(name, style: const TextStyle(color: AppColors.textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pct,
                        child: Container(decoration: BoxDecoration(color: pct >= 1 ? AppColors.success : AppColors.primary, borderRadius: BorderRadius.circular(4))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 30, child: Text('$done/$total', style: const TextStyle(color: AppColors.textMuted, fontSize: 9), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TimeCard extends ConsumerWidget {
  const _TimeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(timeEntriesProvider);
    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) return _buildCard('Time Overview', Icons.timer, '-', '-', '-', AppColors.primary);
        final total = entries.where((e) => e.durationMinutes != null).fold<int>(0, (s, e) => s + e.durationMinutes!);
        if (total == 0) return _buildCard('Time Overview', Icons.timer, '-', '-', '-', AppColors.primary);
        final h = total ~/ 60;
        final d = h ~/ 24;
        final sessions = entries.length;
        return _buildCard('Time Overview', Icons.timer, d > 0 ? '${d}d' : '${h}h', '$sessions', sessions > 0 ? '${(total / sessions).round()}m' : '-', AppColors.primary);
      },
      loading: () => _buildCard('Time Overview', Icons.timer, '-', '-', '-', AppColors.primary),
      error: (_, __) => _buildCard('Time Overview', Icons.timer, '-', '-', '-', AppColors.primary),
    );
  }

  Widget _buildCard(String title, IconData icon, String v1, String v2, String v3, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MiniStat('Total', v1, color)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('Sessions', v2, AppColors.secondary)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('Avg', v3, AppColors.warning)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskTimeCard extends ConsumerWidget {
  const _TaskTimeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(timeEntriesProvider);
    return entriesAsync.when(
      data: (entries) {
        final completed = entries.where((e) => e.endTime != null).toList();
        if (completed.isEmpty) return _buildCard('Task Time', Icons.speed, '-', '-', '-', AppColors.primary);
        final durations = completed.map((e) => e.durationMinutes ?? 0).where((d) => d > 0).toList();
        if (durations.isEmpty) return _buildCard('Task Time', Icons.speed, '-', '-', '-', AppColors.primary);
        final avg = durations.reduce((a, b) => a + b) ~/ durations.length;
        final fast = durations.reduce((a, b) => a < b ? a : b);
        final slow = durations.reduce((a, b) => a > b ? a : b);
        String fmt(int m) => m >= 60 ? '${m ~/ 60}h' : '${m}m';
        return _buildCard('Task Time', Icons.speed, fmt(avg), fmt(fast), fmt(slow), AppColors.primary);
      },
      loading: () => _buildCard('Task Time', Icons.speed, '-', '-', '-', AppColors.primary),
      error: (_, __) => _buildCard('Task Time', Icons.speed, '-', '-', '-', AppColors.primary),
    );
  }

  Widget _buildCard(String title, IconData icon, String v1, String v2, String v3, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MiniStat('Avg', v1, color)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('Fast', v2, AppColors.success)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('Slow', v3, AppColors.warning)),
            ],
          ),
        ],
      ),
    );
  }
}

class _JournalCard extends ConsumerWidget {
  final WidgetRef ref;
  const _JournalCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalAsync = ref.watch(journalDatesProvider);
    return journalAsync.when(
      data: (dates) {
        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));
        final weekCount = dates.where((d) {
          final parts = d.split('-');
          if (parts.length != 3) return false;
          final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          return date.isAfter(weekAgo);
        }).length;
        return _buildCard('Journal', Icons.edit_note, '$weekCount', '${dates.length}', AppColors.warning);
      },
      loading: () => _buildCard('Journal', Icons.edit_note, '-', '-', AppColors.warning),
      error: (_, __) => _buildCard('Journal', Icons.edit_note, '-', '-', AppColors.warning),
    );
  }

  Widget _buildCard(String title, IconData icon, String v1, String v2, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MiniStat('This Week', v1, color)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('Total', v2, AppColors.secondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodCard extends ConsumerWidget {
  final WidgetRef ref;
  const _MoodCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodAsync = ref.watch(allMoodsProvider);
    return moodAsync.when(
      data: (moods) {
        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));
        final monthStart = DateTime(now.year, now.month, 1);
        final weekCount = moods.entries.where((e) {
          final parts = e.key.split('-');
          if (parts.length != 3) return false;
          final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          return date.isAfter(weekAgo);
        }).length;
        final monthCount = moods.entries.where((e) {
          final parts = e.key.split('-');
          if (parts.length != 3) return false;
          final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          return date.isAfter(monthStart);
        }).length;
        return _buildCard('Mood', Icons.emoji_emotions, '$weekCount', '$monthCount', Colors.purple);
      },
      loading: () => _buildCard('Mood', Icons.emoji_emotions, '-', '-', Colors.purple),
      error: (_, __) => _buildCard('Mood', Icons.emoji_emotions, '-', '-', Colors.purple),
    );
  }

  Widget _buildCard(String title, IconData icon, String v1, String v2, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MiniStat('This Week', v1, color)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('This Month', v2, Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecialDaysCard extends ConsumerWidget {
  final WidgetRef ref;
  const _SpecialDaysCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(specialDaysSortedProvider);
    return daysAsync.when(
      data: (days) {
        final now = DateTime.now();
        final yearCount = days.where((d) => d.year == now.year).length;
        return _buildCard('Special Days', Icons.auto_awesome, '$yearCount', '${days.length}', Colors.teal);
      },
      loading: () => _buildCard('Special Days', Icons.auto_awesome, '-', '-', Colors.teal),
      error: (_, __) => _buildCard('Special Days', Icons.auto_awesome, '-', '-', Colors.teal),
    );
  }

  Widget _buildCard(String title, IconData icon, String v1, String v2, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MiniStat('This Year', v1, color)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat('Total', v2, AppColors.secondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentTasksCard extends StatelessWidget {
  final List<Task> tasks;

  const _RecentTasksCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final recent = [...tasks]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final display = recent.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Tasks', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (display.isEmpty)
            const Text('No tasks', style: TextStyle(color: AppColors.textMuted, fontSize: 10))
          else
            ...display.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(width: 3, height: 20, decoration: BoxDecoration(color: _priorityColor(t), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.title, style: TextStyle(color: t.status == TaskStatus.completed ? AppColors.textMuted : AppColors.textPrimary, fontSize: 11, decoration: t.status == TaskStatus.completed ? TextDecoration.lineThrough : null), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Color _priorityColor(Task t) {
    switch (t.priority) {
      case Priority.low: return AppColors.secondary;
      case Priority.medium: return AppColors.warning;
      case Priority.high: return Colors.orange;
      case Priority.urgent: return AppColors.error;
    }
  }
}

class _CompactQuickActions extends StatelessWidget {
  final Function(int)? onNavigate;

  const _CompactQuickActions({this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CompactActionBtn(icon: Icons.add_task, color: AppColors.primary, tooltip: 'Add Task', onTap: () => onNavigate?.call(2)),
        _CompactActionBtn(icon: Icons.create_new_folder, color: AppColors.secondary, tooltip: 'Add Project', onTap: () => onNavigate?.call(2)),
        _CompactActionBtn(icon: Icons.edit_note, color: AppColors.warning, tooltip: 'Journal', onTap: () => onNavigate?.call(1)),
        _CompactActionBtn(icon: Icons.emoji_emotions, color: Colors.purple, tooltip: 'Mood', onTap: () => onNavigate?.call(4)),
        _CompactActionBtn(icon: Icons.auto_awesome, color: Colors.teal, tooltip: 'Special Day', onTap: () => onNavigate?.call(5)),
      ],
    );
  }
}

class _CompactActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _CompactActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
