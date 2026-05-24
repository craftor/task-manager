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

  void _scrollToSection(int index) {
    onNavigate?.call(index);
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    List<Task> tasks,
    AsyncValue<List<dynamic>> projectsAsync,
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
        final isWide = constraints.maxWidth > 800;
        final crossAxisCount = isWide ? 4 : 2;
        final cardWidth = (constraints.maxWidth - 48 - (crossAxisCount - 1) * 12) / crossAxisCount;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary stats - full width row
              _StatsRow(
                tasks: tasks,
                totalProjects: totalProjects,
                onTap: _scrollToSection,
              ),
              const SizedBox(height: 16),
              // Priority + This Week + Project Progress + Recent Tasks (4 cols desktop, 2 cols mobile)
              _FourCardGrid(
                isWide: isWide,
                children: [
                  _PriorityDistributionCard(tasks: tasks),
                  _WeeklyCompletionCard(tasks: tasks),
                  _ProjectCompletionCard(tasks: tasks, projectsAsync: projectsAsync),
                  _RecentTasksCard(tasks: tasks),
                ],
              ),
              const SizedBox(height: 16),
              // Time overview + Task time stats
              _GridRow(
                crossAxisCount: isWide ? 2 : 1,
                children: [
                  SizedBox(width: isWide ? null : constraints.maxWidth, child: const _TimeOverviewCard()),
                  if (isWide) SizedBox(width: null, child: const _TaskTimeStatsCard()),
                ],
              ),
              const SizedBox(height: 16),
              // Journal + Mood + Special Days
              _GridRow(
                crossAxisCount: isWide ? 3 : 1,
                children: [
                  _JournalActivityCard(ref: ref),
                  _MoodSummaryCard(ref: ref),
                  _SpecialDaysUpcomingCard(ref: ref),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<Task> tasks;
  final int totalProjects;
  final Function(int) onTap;

  const _StatsRow({required this.tasks, required this.totalProjects, required this.onTap});

  @override
  Widget build(BuildContext context) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final chips = <Widget>[
          _StatChip(title: 'Total', value: totalTasks.toString(), icon: Icons.task_alt, color: AppColors.primary, onTap: () => onTap(1)),
          _StatChip(title: 'Pending', value: pendingTasks.toString(), icon: Icons.pending_actions, color: AppColors.warning),
          _StatChip(title: 'Completed', value: completedTasks.toString(), icon: Icons.check_circle, color: AppColors.success),
          _StatChip(title: 'Overdue', value: overdueTasks.toString(), icon: Icons.warning, color: AppColors.error),
          _StatChip(title: 'High Priority', value: highPriorityTasks.toString(), icon: Icons.priority_high, color: Colors.orange),
          _StatChip(title: 'Projects', value: totalProjects.toString(), icon: Icons.folder, color: AppColors.secondary, onTap: () => onTap(1)),
        ];

        final minChipWidth = 80.0;
        final maxWidth = constraints.maxWidth;
        final rowWidth = chips.length * minChipWidth + (chips.length - 1) * 12;

        if (rowWidth <= maxWidth) {
          return Row(
            children: chips.asMap().entries.map((entry) {
              final index = entry.key;
              final chip = entry.value;
              return Expanded(child: Padding(padding: EdgeInsets.only(right: index == chips.length - 1 ? 0 : 12), child: chip));
            }).toList(),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: chips.map((chip) => SizedBox(width: minChipWidth, child: chip)).toList(),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatChip({required this.title, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _GridRow extends StatelessWidget {
  final int crossAxisCount;
  final List<Widget> children;

  const _GridRow({required this.crossAxisCount, required this.children});

  @override
  Widget build(BuildContext context) {
    if (crossAxisCount == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.map((child) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: child))).toList(),
    );
  }
}

class _FourCardGrid extends StatelessWidget {
  final bool isWide;
  final List<Widget> children;

  const _FourCardGrid({required this.isWide, required this.children});

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.map((child) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: _EqualHeightCard(child: child)))).toList(),
      );
    }
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: _EqualHeightCard(child: children[1]))),
              Expanded(child: _EqualHeightCard(child: children[2])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: _EqualHeightCard(child: children[3]))),
              Expanded(child: _EqualHeightCard(child: children[0])),
            ],
          ),
        ),
      ],
    );
  }
}

class _EqualHeightCard extends StatelessWidget {
  final Widget child;
  const _EqualHeightCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight > 0 ? constraints.maxHeight : 120,
          child: child,
        );
      },
    );
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
        _CompactActionBtn(icon: Icons.add_task, color: AppColors.primary, tooltip: 'Add Task', onTap: () {}),
        _CompactActionBtn(icon: Icons.create_new_folder, color: AppColors.secondary, tooltip: 'Add Project', onTap: () {}),
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

class _PriorityDistributionCard extends StatelessWidget {
  final List<Task> tasks;

  const _PriorityDistributionCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final lowCount = tasks.where((t) => t.priority == Priority.low).length;
    final mediumCount = tasks.where((t) => t.priority == Priority.medium).length;
    final highCount = tasks.where((t) => t.priority == Priority.high).length;
    final urgentCount = tasks.where((t) => t.priority == Priority.urgent).length;
    final total = tasks.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.pie_chart, color: AppColors.primary, size: 16), SizedBox(width: 6), Text('Priority', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 10),
          if (total == 0)
            const Text('No tasks', style: TextStyle(color: AppColors.textMuted, fontSize: 11))
          else ...[
            _MiniBar(label: 'Low', count: lowCount, total: total, color: AppColors.secondary),
            const SizedBox(height: 4),
            _MiniBar(label: 'Med', count: mediumCount, total: total, color: AppColors.warning),
            const SizedBox(height: 4),
            _MiniBar(label: 'High', count: highCount, total: total, color: Colors.orange),
            const SizedBox(height: 4),
            _MiniBar(label: 'Urgent', count: urgentCount, total: total, color: AppColors.error),
          ],
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _MiniBar({required this.label, required this.count, required this.total, required this.color});

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
        SizedBox(width: 20, child: Text('$count', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
      ],
    );
  }
}

class _WeeklyCompletionCard extends StatelessWidget {
  final List<Task> tasks;
  const _WeeklyCompletionCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));
    final thisWeekCreated = tasks.where((t) => t.createdAt.isAfter(weekAgo)).length;
    final thisWeekCompleted = tasks.where((t) => t.status == TaskStatus.completed && t.updatedAt.isAfter(weekAgo)).length;
    final completionRate = thisWeekCreated > 0 ? (thisWeekCompleted / thisWeekCreated * 100).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.date_range, color: AppColors.primary, size: 16), SizedBox(width: 6), Text('This Week', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MiniStat2(label: 'Created', value: '$thisWeekCreated', color: AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat2(label: 'Done', value: '$thisWeekCompleted', color: AppColors.success)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat2(label: 'Rate', value: '$completionRate%', color: AppColors.warning)),
          ]),
        ],
      ),
    );
  }
}

class _MiniStat2 extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat2({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
      ]),
    );
  }
}

class _ProjectCompletionCard extends StatelessWidget {
  final List<Task> tasks;
  final AsyncValue<List<dynamic>> projectsAsync;
  const _ProjectCompletionCard({required this.tasks, required this.projectsAsync});

  @override
  Widget build(BuildContext context) {
    final projects = projectsAsync.valueOrNull;
    if (projects == null || projects.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.folder_copy, color: AppColors.primary, size: 16), SizedBox(width: 6), Text('Project Progress', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 10),
          ...projects.take(5).map((p) {
            final name = (p as dynamic).name as String? ?? 'Unknown';
            final pid = (p as dynamic).id as String? ?? '';
            final isDefault = (p as dynamic).isDefault == true || name.toLowerCase() == 'default';
            final projectTasks = tasks.where((t) => t.projectId == pid || (isDefault && (t.projectId == AppConstants.legacyDefaultProjectId || t.projectId == AppConstants.defaultProjectId))).toList();
            final total = projectTasks.length;
            final done = projectTasks.where((t) => t.status == TaskStatus.completed).length;
            final pct = total > 0 ? done / total : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 60, child: Text(name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation(pct >= 1 ? AppColors.success : AppColors.primary)))),
                const SizedBox(width: 6),
                SizedBox(width: 30, child: Text('$done/$total', style: const TextStyle(color: AppColors.textMuted, fontSize: 9), textAlign: TextAlign.right)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

class _TimeOverviewCard extends ConsumerWidget {
  const _TimeOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(timeEntriesProvider);
    return entriesAsync.when(data: (entries) {
      if (entries.isEmpty) return const SizedBox.shrink();
      final totalMinutes = entries.where((e) => e.durationMinutes != null).fold<int>(0, (s, e) => s + e.durationMinutes!);
      if (totalMinutes == 0) return const SizedBox.shrink();
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      final d = h ~/ 24;
      final sessions = entries.length;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.timer, color: AppColors.primary, size: 16), SizedBox(width: 6), Text('Time Overview', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _MiniStat2(label: 'Total', value: d > 0 ? '${d}d' : '${h}h', color: AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat2(label: 'Sessions', value: '$sessions', color: AppColors.secondary)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat2(label: 'Avg', value: sessions > 0 ? '${(totalMinutes / sessions).round()}m' : '0m', color: AppColors.warning)),
            ]),
          ],
        ),
      );
    }, loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink());
  }
}

class _TaskTimeStatsCard extends ConsumerWidget {
  const _TaskTimeStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(timeEntriesProvider);

    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        final completed = entries.where((e) => e.endTime != null).toList();
        if (completed.isEmpty) return const SizedBox.shrink();

        final durations = completed.map((e) => e.durationMinutes ?? 0).where((d) => d > 0).toList();
        if (durations.isEmpty) return const SizedBox.shrink();

        final avg = durations.reduce((a, b) => a + b) ~/ durations.length;
        final fastest = durations.reduce((a, b) => a < b ? a : b);
        final slowest = durations.reduce((a, b) => a > b ? a : b);

        String fmt(int m) => m >= 60 ? '${m ~/ 60}h' : '${m}m';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(Icons.speed, color: AppColors.primary, size: 16), SizedBox(width: 6), Text('Task Time', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _MiniStat2(label: 'Avg', value: fmt(avg), color: AppColors.primary)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat2(label: 'Fast', value: fmt(fastest), color: AppColors.success)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat2(label: 'Slow', value: fmt(slowest), color: AppColors.warning)),
              ]),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _JournalActivityCard extends ConsumerWidget {
  final WidgetRef ref;
  const _JournalActivityCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalDatesAsync = ref.watch(journalDatesProvider);

    return journalDatesAsync.when(
      data: (dates) {
        final now = DateTime.now();
        final weekAgo = DateTime(now.year, now.month, now.day - 7);
        final thisWeek = dates.where((d) {
          final parts = d.split('-');
          if (parts.length != 3) return false;
          final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          return date.isAfter(weekAgo);
        }).length;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(Icons.edit_note, color: AppColors.warning, size: 16), SizedBox(width: 6), Text('Journal', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _MiniStat2(label: 'This Week', value: '$thisWeek', color: AppColors.warning)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat2(label: 'Total', value: '${dates.length}', color: AppColors.secondary)),
              ]),
            ],
          ),
        );
      },
      loading: () => _buildLoadingCard(),
      error: (_, __) => _buildLoadingCard(),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.edit_note, color: AppColors.warning, size: 16), SizedBox(width: 6), Text('Journal', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MiniStat2(label: 'This Week', value: '-', color: AppColors.warning)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat2(label: 'Total', value: '-', color: AppColors.secondary)),
          ]),
        ],
      ),
    );
  }
}

class _MoodSummaryCard extends ConsumerWidget {
  final WidgetRef ref;
  const _MoodSummaryCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodsAsync = ref.watch(allMoodsProvider);

    return moodsAsync.when(
      data: (moods) {
        final now = DateTime.now();
        final weekAgo = DateTime(now.year, now.month, now.day - 7);
        final monthStart = DateTime(now.year, now.month, 1);
        final thisWeekCount = moods.entries.where((e) {
          final parts = e.key.split('-');
          if (parts.length != 3) return false;
          final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          return date.isAfter(weekAgo);
        }).length;
        final thisMonthCount = moods.entries.where((e) {
          final parts = e.key.split('-');
          if (parts.length != 3) return false;
          final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          return date.isAfter(monthStart);
        }).length;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(Icons.emoji_emotions, color: Colors.purple, size: 16), SizedBox(width: 6), Text('Mood', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _MiniStat2(label: 'This Week', value: '$thisWeekCount', color: Colors.purple)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat2(label: 'This Month', value: '$thisMonthCount', color: Colors.orange)),
              ]),
            ],
          ),
        );
      },
      loading: () => _buildLoadingCard(),
      error: (_, __) => _buildLoadingCard(),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.emoji_emotions, color: Colors.purple, size: 16), SizedBox(width: 6), Text('Mood', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MiniStat2(label: 'This Week', value: '-', color: Colors.purple)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat2(label: 'This Month', value: '-', color: Colors.orange)),
          ]),
        ],
      ),
    );
  }
}

class _SpecialDaysUpcomingCard extends ConsumerWidget {
  final WidgetRef ref;
  const _SpecialDaysUpcomingCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specialDaysAsync = ref.watch(specialDaysSortedProvider);

    return specialDaysAsync.when(
      data: (days) {
        final now = DateTime.now();
        final yearStart = DateTime(now.year, 1, 1);
        final thisYearCount = days.where((d) => d.year == now.year).length;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(Icons.auto_awesome, color: Colors.teal, size: 16), SizedBox(width: 6), Text('Special Days', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _MiniStat2(label: 'This Year', value: '$thisYearCount', color: Colors.teal)),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat2(label: 'Total', value: '${days.length}', color: AppColors.secondary)),
              ]),
            ],
          ),
        );
      },
      loading: () => _buildLoadingCard(),
      error: (_, __) => _buildLoadingCard(),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.auto_awesome, color: Colors.teal, size: 16), SizedBox(width: 6), Text('Special Days', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MiniStat2(label: 'This Year', value: '-', color: Colors.teal)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat2(label: 'Total', value: '-', color: AppColors.secondary)),
          ]),
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
    final recentTasks = [...tasks]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final displayTasks = recentTasks.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.history, color: AppColors.primary, size: 16), SizedBox(width: 6), Text('Recent Tasks', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 10),
          if (displayTasks.isEmpty)
            const Text('No tasks', style: TextStyle(color: AppColors.textMuted, fontSize: 11))
          else
            ...displayTasks.map((task) => _RecentTaskItem(task: task)),
        ],
      ),
    );
  }
}

class _RecentTaskItem extends StatelessWidget {
  final Task task;

  const _RecentTaskItem({required this.task});

  Color get _priorityColor {
    switch (task.priority) {
      case Priority.low:
        return AppColors.secondary;
      case Priority.medium:
        return AppColors.warning;
      case Priority.high:
        return Colors.orange;
      case Priority.urgent:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 3, height: 24, decoration: BoxDecoration(color: _priorityColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                color: task.status == TaskStatus.completed ? AppColors.textMuted : AppColors.textPrimary,
                fontSize: 12,
                decoration: task.status == TaskStatus.completed ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _priorityColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(task.status == TaskStatus.completed ? 'Done' : task.priority.name, style: TextStyle(color: _priorityColor, fontSize: 9, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}