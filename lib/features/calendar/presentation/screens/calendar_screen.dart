import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/task.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../providers/calendar_provider.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final calendarState = ref.watch(calendarProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                calendarState.displayMode == CalendarDisplayMode.marker
                    ? Icons.circle_outlined
                    : Icons.view_day_outlined,
                color: AppColors.primary,
              ),
              onPressed: () {
                ref.read(calendarProvider.notifier).toggleDisplayMode();
              },
            ),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) => _buildCalendarBody(context, ref, tasks, calendarState),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  Widget _buildCalendarBody(
    BuildContext context,
    WidgetRef ref,
    List<Task> tasks,
    CalendarState calendarState,
  ) {
    return Column(
      children: [
        _buildCalendar(context, ref, tasks, calendarState),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: _buildTasksForSelectedDay(context, ref, tasks, calendarState.selectedDay),
        ),
      ],
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    WidgetRef ref,
    List<Task> tasks,
    CalendarState calendarState,
  ) {
    return TableCalendar<Task>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: calendarState.focusedDay,
      selectedDayPredicate: (day) => isSameDay(calendarState.selectedDay, day),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textSecondary),
        rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
        weekendTextStyle: const TextStyle(color: AppColors.textSecondary),
        outsideTextStyle: const TextStyle(color: AppColors.textMuted),
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(color: AppColors.textPrimary),
        selectedDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(color: AppColors.background),
        markerDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
      eventLoader: (day) {
        return tasks.where((task) {
          // Show task if its startDate or dueDate matches this day
          if (task.startDate != null && isSameDay(task.startDate!, day)) return true;
          if (task.dueDate != null && isSameDay(task.dueDate!, day)) return true;
          // Also show if task spans this day (for time block display)
          if (task.startDate != null && task.dueDate != null) {
            return !day.isBefore(task.startDate!) && !day.isAfter(task.dueDate!);
          }
          return false;
        }).toList();
      },
      onDaySelected: (selectedDay, focusedDay) {
        ref.read(calendarProvider.notifier).setSelectedDay(selectedDay);
        ref.read(calendarProvider.notifier).setFocusedDay(focusedDay);
      },
      onPageChanged: (focusedDay) {
        ref.read(calendarProvider.notifier).setFocusedDay(focusedDay);
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, date, focusedDay) {
          final displayMode = ref.read(calendarProvider).displayMode;

          // Find tasks that span this date
          final spanningTasks = tasks.where((task) {
            if (task.startDate != null && task.dueDate != null) {
              return !date.isBefore(task.startDate!) && !date.isAfter(task.dueDate!);
            }
            if (task.startDate != null && isSameDay(task.startDate!, date)) return true;
            if (task.dueDate != null && isSameDay(task.dueDate!, date)) return true;
            return false;
          }).toList();

          if (spanningTasks.isEmpty) return null;

          // In time block mode, show colored bars
          if (displayMode == CalendarDisplayMode.timeBlock) {
            return Container(
              margin: const EdgeInsets.all(2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: spanningTasks.take(2).map((task) {
                  return Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(task.priority),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }).toList(),
              ),
            );
          }

          // In marker mode, use default behavior
          return null;
        },
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;
          final displayMode = ref.read(calendarProvider).displayMode;
          if (displayMode == CalendarDisplayMode.timeBlock) return null;

          return Positioned(
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: events.take(3).map((task) {
                final color = _getPriorityColor(task.priority);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTasksForSelectedDay(
    BuildContext context,
    WidgetRef ref,
    List<Task> tasks,
    DateTime selectedDay,
  ) {
    final dayTasks = tasks.where((task) {
      // Match start date, due date, or tasks that span this day
      if (task.startDate != null && isSameDay(task.startDate!, selectedDay)) return true;
      if (task.dueDate != null && isSameDay(task.dueDate!, selectedDay)) return true;
      if (task.startDate != null && task.dueDate != null) {
        return !selectedDay.isBefore(task.startDate!) && !selectedDay.isAfter(task.dueDate!);
      }
      return false;
    }).toList();

    if (dayTasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 48, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text(
              'No tasks due on this day',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayTasks.length,
      itemBuilder: (context, index) {
        final task = dayTasks[index];
        return _CalendarTaskCard(task: task);
      },
    );
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
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
}

class _CalendarTaskCard extends StatelessWidget {
  final Task task;

  const _CalendarTaskCard({required this.task});

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

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (task.startDate != null) ...[
                      Icon(Icons.play_arrow, size: 12, color: AppColors.textMuted),
                      Text(
                        _formatDateTime(task.startDate!),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (task.dueDate != null) ...[
                      Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                      Text(
                        _formatDateTime(task.dueDate!),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _priorityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              task.priority.name.toUpperCase(),
              style: TextStyle(
                color: _priorityColor,
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