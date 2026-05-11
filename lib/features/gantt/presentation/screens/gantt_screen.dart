import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/task.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../providers/gantt_provider.dart';
import '../../widgets/gantt_chart.dart';

class GanttScreen extends ConsumerWidget {
  const GanttScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final ganttState = ref.watch(ganttProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gantt'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          SegmentedButton<GanttViewMode>(
            selected: {ganttState.viewMode},
            onSelectionChanged: (value) {
              ref.read(ganttProvider.notifier).setViewMode(value.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary.withOpacity(0.2);
                }
                return Colors.transparent;
              }),
            ),
            segments: const [
              ButtonSegment(
                value: GanttViewMode.project,
                label: Text('Project'),
              ),
              ButtonSegment(
                value: GanttViewMode.personal,
                label: Text('Personal'),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) => _buildGanttBody(context, tasks, ganttState),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  Widget _buildGanttBody(BuildContext context, List<Task> tasks, GanttState state) {
    final visibleTasks = tasks.where((task) {
      if (task.dueDate == null) return false;
      final taskStart = task.createdAt;
      final taskEnd = task.dueDate!;
      return !taskEnd.isBefore(state.startDate) && !taskStart.isAfter(state.endDate);
    }).toList();

    if (visibleTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 24),
            const Text(
              'No tasks in time range',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tasks will appear here when they have due dates',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Legend
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: AppColors.surface,
          child: Row(
            children: [
              _LegendItem(color: AppColors.error, label: 'Urgent'),
              const SizedBox(width: 16),
              _LegendItem(color: Colors.orange, label: 'High'),
              const SizedBox(width: 16),
              _LegendItem(color: AppColors.warning, label: 'Medium'),
              const SizedBox(width: 16),
              _LegendItem(color: AppColors.secondary, label: 'Low'),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 2,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Today',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        // Timeline header
        _buildTimelineHeader(state),
        const Divider(height: 1, color: AppColors.border),
        // Scrollable chart with task list on left
        Expanded(
          child: Row(
            children: [
              // Task name column (fixed left)
              Container(
                width: 120,
                color: AppColors.surface,
                child: ListView.builder(
                  itemCount: visibleTasks.length,
                  itemBuilder: (context, index) {
                    final task = visibleTasks[index];
                    return Container(
                      height: 48,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
              // Chart area (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _calculateChartWidth(state),
                    child: GanttChart(
                      tasks: visibleTasks,
                      startDate: state.startDate,
                      endDate: state.endDate,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateChartWidth(GanttState state) {
    final days = state.endDate.difference(state.startDate).inDays.clamp(1, 365);
    return days * 30.0; // 30 pixels per day
  }

  Widget _buildTimelineHeader(GanttState state) {
    final days = state.endDate.difference(state.startDate).inDays;
    final weeks = (days / 7).ceil();

    return Container(
      height: 40,
      color: AppColors.surface,
      child: Row(
        children: [
          Container(
            width: 120,
            padding: const EdgeInsets.all(8),
            child: const Text(
              'Task',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: weeks,
              itemBuilder: (context, index) {
                final weekStart = state.startDate.add(Duration(days: index * 7));
                return Container(
                  width: 100,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${weekStart.day}/${weekStart.month}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.6),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}