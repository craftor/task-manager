import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../../time_tracking/presentation/providers/time_tracking_provider.dart' show timeEntriesProvider;
import '../../../../domain/entities/task.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final timeEntriesAsync = ref.watch(timeEntriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: tasksAsync.when(
        data: (tasks) => _buildDashboard(context, ref, tasks, projectsAsync, timeEntriesAsync),
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
    AsyncValue<List<dynamic>> projectsAsync,
    AsyncValue<List<dynamic>> timeEntriesAsync,
  ) {
    final totalTasks = tasks.length;
    final pendingTasks = tasks.where((t) => t.status != TaskStatus.completed).length;
    final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).length;

    // Calculate overdue tasks
    final now = DateTime.now();
    final overdueTasks = tasks.where((t) {
      if (t.status == TaskStatus.completed) return false;
      if (t.dueDate == null) return false;
      return t.dueDate!.isBefore(now);
    }).length;

    // Calculate high priority tasks
    final highPriorityTasks = tasks.where((t) {
      return t.priority == Priority.high || t.priority == Priority.urgent;
    }).length;

    // Total projects
    final totalProjects = projectsAsync.valueOrNull?.length ?? 0;

    // Total time tracked (in minutes)
    int totalTimeMinutes = 0;
    timeEntriesAsync.whenData((entries) {
      for (final entry in entries) {
        final dur = entry.durationMinutes;
        totalTimeMinutes = totalTimeMinutes + (dur as int? ?? 0);
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards row
          Row(
            children: [
              Expanded(child: _SummaryCard(
                title: 'Total Tasks',
                value: totalTasks.toString(),
                icon: Icons.task_alt,
                color: AppColors.primary,
              )),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(
                title: 'Pending',
                value: pendingTasks.toString(),
                icon: Icons.pending_actions,
                color: AppColors.warning,
              )),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(
                title: 'Completed',
                value: completedTasks.toString(),
                icon: Icons.check_circle,
                color: AppColors.success,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SummaryCard(
                title: 'Overdue',
                value: overdueTasks.toString(),
                icon: Icons.warning,
                color: AppColors.error,
              )),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(
                title: 'High Priority',
                value: highPriorityTasks.toString(),
                icon: Icons.priority_high,
                color: Colors.orange,
              )),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(
                title: 'Projects',
                value: totalProjects.toString(),
                icon: Icons.folder,
                color: AppColors.secondary,
              )),
            ],
          ),
          const SizedBox(height: 24),
          // Time tracking summary
          _TimeSummaryCard(totalMinutes: totalTimeMinutes),
          const SizedBox(height: 16),
          // Priority distribution
          _PriorityDistributionCard(tasks: tasks),
          const SizedBox(height: 16),
          // Recent tasks
          _RecentTasksCard(tasks: tasks),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSummaryCard extends StatelessWidget {
  final int totalMinutes;

  const _TimeSummaryCard({required this.totalMinutes});

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.timer, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Time Tracked',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDuration(totalMinutes),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Total time tracked',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: AppColors.success, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${(totalMinutes / 60).toStringAsFixed(1)} hrs',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Priority Distribution',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const Center(
              child: Text(
                'No tasks yet',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else ...[
            _PriorityBar(
              label: 'Low',
              count: lowCount,
              total: total,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 8),
            _PriorityBar(
              label: 'Medium',
              count: mediumCount,
              total: total,
              color: AppColors.warning,
            ),
            const SizedBox(height: 8),
            _PriorityBar(
              label: 'High',
              count: highCount,
              total: total,
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            _PriorityBar(
              label: 'Urgent',
              count: urgentCount,
              total: total,
              color: AppColors.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _PriorityBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _PriorityBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _RecentTasksCard extends StatelessWidget {
  final List<Task> tasks;

  const _RecentTasksCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final recentTasks = tasks.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Recent Tasks',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentTasks.isEmpty)
            const Center(
              child: Text(
                'No tasks yet',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            ...recentTasks.map((task) => _RecentTaskItem(task: task)),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: _priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: task.status == TaskStatus.completed
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    fontSize: 14,
                    decoration: task.status == TaskStatus.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.dueDate != null)
                  Text(
                    'Due ${task.dueDate!.day}/${task.dueDate!.month}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: task.status == TaskStatus.completed
                  ? AppColors.success.withOpacity(0.15)
                  : _priorityColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              task.status == TaskStatus.completed
                  ? 'Done'
                  : task.priority.name,
              style: TextStyle(
                color: task.status == TaskStatus.completed
                    ? AppColors.success
                    : _priorityColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}