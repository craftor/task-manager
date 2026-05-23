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
          // Zoom selector
          SegmentedButton<GanttZoom>(
            selected: {ganttState.zoom},
            onSelectionChanged: (value) {
              ref.read(ganttProvider.notifier).setZoom(value.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary.withValues(alpha: 0.2);
                }
                return Colors.transparent;
              }),
            ),
            segments: const [
              ButtonSegment(value: GanttZoom.week, label: Text('W')),
              ButtonSegment(value: GanttZoom.month, label: Text('M')),
              ButtonSegment(value: GanttZoom.quarter, label: Text('Q')),
              ButtonSegment(value: GanttZoom.year, label: Text('Y')),
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
          child: Text('Error: $error',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  Widget _buildGanttBody(
      BuildContext context, List<Task> tasks, GanttState state) {
    final visibleTasks = tasks.where((task) {
      if (task.dueDate == null) return false;
      final taskStart = task.createdAt;
      final taskEnd = task.dueDate!;
      return !taskEnd.isBefore(state.startDate) &&
          !taskStart.isAfter(state.endDate);
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
                  fontWeight: FontWeight.w600),
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
                  Container(width: 12, height: 2, color: AppColors.error),
                  const SizedBox(width: 4),
                  const Text('Today',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        _buildTimelineHeader(state),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: Row(
            children: [
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
                          bottom: BorderSide(
                              color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        task.title,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _calculateChartWidth(state),
                    child: GanttChart(
                      tasks: visibleTasks,
                      startDate: state.startDate,
                      endDate: state.endDate,
                      zoom: state.zoom,
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
    final days =
        state.endDate.difference(state.startDate).inDays.clamp(1, 365);
    final ppd = _pixelsPerDay(state.zoom);
    return days * ppd;
  }

  double _pixelsPerDay(GanttZoom zoom) {
    switch (zoom) {
      case GanttZoom.week:
        return 50.0;
      case GanttZoom.month:
        return 30.0;
      case GanttZoom.quarter:
        return 12.0;
      case GanttZoom.year:
        return 3.5;
    }
  }

  Widget _buildTimelineHeader(GanttState state) {
    return Container(
      height: 40,
      color: AppColors.surface,
      child: Row(
        children: [
          Container(
            width: 120,
            padding: const EdgeInsets.all(8),
            child: const Text('Task',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: _buildHeaderCells(state),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCells(GanttState state) {
    final ppd = _pixelsPerDay(state.zoom);
    final start = state.startDate;

    switch (state.zoom) {
      case GanttZoom.week:
        // Daily headers for week view
        final dayCount =
            state.endDate.difference(start).inDays.clamp(1, 7);
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: dayCount,
          itemBuilder: (context, i) {
            final d = start.add(Duration(days: i));
            final isToday = d.day == DateTime.now().day &&
                d.month == DateTime.now().month &&
                d.year == DateTime.now().year;
            return Container(
              width: ppd,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: Column(
                children: [
                  Text(
                    _weekday(d.weekday),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                  ),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      color: isToday
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          },
        );

      case GanttZoom.month:
        // Weekly headers
        final dayCount = state.endDate.difference(start).inDays;
        final weekCount = (dayCount / 7).ceil();
        final ppd7 = ppd * 7;
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: weekCount,
          itemBuilder: (context, i) {
            final ws = start.add(Duration(days: i * 7));
            return Container(
              width: ppd7,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
                ),
              ),
              child: Text(
                '${ws.day}/${ws.month}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            );
          },
        );

      case GanttZoom.quarter:
        // Monthly headers
        final monthCount = ((state.endDate.year - start.year) * 12 +
                state.endDate.month -
                start.month +
                1)
            .clamp(1, 4);
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: monthCount,
          itemBuilder: (context, i) {
            final m = DateTime(start.year, start.month + i, 1);
            final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
            return Container(
              width: ppd * daysInMonth,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
                ),
              ),
              child: Text(
                _monthName(m.month),
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            );
          },
        );

      case GanttZoom.year:
        // Monthly headers for year view
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 12,
          itemBuilder: (context, i) {
            final m = DateTime(start.year, i + 1, 1);
            final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
            return Container(
              width: ppd * daysInMonth,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _monthAbbr(m.month),
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 10),
              ),
            );
          },
        );
    }
  }

  String _weekday(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  String _monthName(int m) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[m];
  }

  String _monthAbbr(int m) {
    const abbr = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return abbr[m];
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
            color: color.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}
