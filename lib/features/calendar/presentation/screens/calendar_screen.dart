import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/task.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../../../mood/mood_provider.dart';
import '../../../mood/mood_service.dart';
import '../providers/calendar_provider.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final calendarState = ref.watch(calendarProvider);
    final moodsAsync = ref.watch(allMoodsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          // Mood button for selected day
          moodsAsync.when(
            data: (moods) {
              final key = _dateKey(calendarState.selectedDay);
              final todayMood = moods[key];
              return Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: Text(
                    todayMood ?? '😶',
                    style: const TextStyle(fontSize: 22),
                  ),
                  onPressed: () =>
                      _showMoodPicker(context, ref, calendarState.selectedDay, todayMood),
                  tooltip: todayMood != null ? 'Change mood' : 'Add mood',
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Today button
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.today, color: AppColors.primary),
              onPressed: () {
                final now = DateTime.now();
                ref.read(calendarProvider.notifier).setSelectedDay(now);
                ref.read(calendarProvider.notifier).setFocusedDay(now);
              },
              tooltip: 'Go to today',
            ),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) =>
            _buildCalendarBody(context, ref, tasks, calendarState),
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

  Widget _buildCalendarBody(BuildContext context, WidgetRef ref,
      List<Task> tasks, CalendarState calendarState) {
    return Column(
      children: [
        _buildCalendar(context, ref, tasks, calendarState),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: _buildTasksForSelectedDay(
              context, ref, tasks, calendarState.selectedDay),
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context, WidgetRef ref,
      List<Task> tasks, CalendarState calendarState) {
    final moodsAsync = ref.watch(allMoodsProvider);
    final moods = moodsAsync.valueOrNull ?? {};

    return TableCalendar<Task>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: calendarState.focusedDay,
      selectedDayPredicate: (day) =>
          isSameDay(calendarState.selectedDay, day),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600),
        leftChevronIcon:
            Icon(Icons.chevron_left, color: AppColors.textSecondary),
        rightChevronIcon:
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
        weekendTextStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        outsideTextStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w400),
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
        cellMargin: const EdgeInsets.all(4),
      ),
      eventLoader: (day) {
        return tasks.where((task) {
          if (task.startDate != null && isSameDay(task.startDate!, day))
            return true;
          if (task.dueDate != null && isSameDay(task.dueDate!, day))
            return true;
          if (task.startDate != null && task.dueDate != null) {
            return !day.isBefore(task.startDate!) &&
                !day.isAfter(task.dueDate!);
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
          final key = _dateKey(date);
          final mood = moods[key];
          if (mood == null) return null; // use default cell rendering

          final isToday = isSameDay(date, DateTime.now());
          final isSelected = isSameDay(date, calendarState.selectedDay);
          final isOutside = date.month != calendarState.focusedDay.month;

          Color textColor;
          FontWeight weight;
          if (isSelected) {
            textColor = AppColors.background;
            weight = FontWeight.w600;
          } else if (isToday) {
            textColor = AppColors.textPrimary;
            weight = FontWeight.w700;
          } else if (isOutside) {
            textColor = AppColors.textSecondary;
            weight = FontWeight.w400;
          } else if (date.weekday == 6 || date.weekday == 7) {
            textColor = AppColors.textSecondary;
            weight = FontWeight.w500;
          } else {
            textColor = AppColors.textPrimary;
            weight = FontWeight.w400;
          }

          return Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: weight),
                ),
                Text(mood, style: const TextStyle(fontSize: 13)),
              ],
            ),
          );
        },
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;
          return Positioned(
            bottom: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: events.take(3).map((task) {
                final color = _getPriorityColor(task.priority);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 5, height: 5,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTasksForSelectedDay(BuildContext context, WidgetRef ref,
      List<Task> tasks, DateTime selectedDay) {
    final dayTasks = tasks.where((task) {
      if (task.startDate != null && isSameDay(task.startDate!, selectedDay))
        return true;
      if (task.dueDate != null && isSameDay(task.dueDate!, selectedDay))
        return true;
      if (task.startDate != null && task.dueDate != null) {
        return !selectedDay.isBefore(task.startDate!) &&
            !selectedDay.isAfter(task.dueDate!);
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
            Text('No tasks due on this day',
                style: TextStyle(color: AppColors.textSecondary)),
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

  void _showMoodPicker(BuildContext context, WidgetRef ref,
      DateTime day, String? currentMood) {
    final key = _dateKey(day);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('MMM d, yyyy').format(day),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text('How are you feeling?',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: moodEmojis.map((emoji) {
                  final isSelected = emoji == currentMood;
                  return GestureDetector(
                    onTap: () async {
                      if (isSelected) {
                        await ref
                            .read(moodServiceProvider)
                            .removeMood(key);
                      } else {
                        await ref
                            .read(moodServiceProvider)
                            .setMood(key, emoji);
                      }
                      ref.invalidate(allMoodsProvider);
                      ref.invalidate(weeklyMoodDistributionProvider);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 30)),
                          const SizedBox(height: 4),
                          Text(
                            moodLabels[emoji] ?? '',
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (currentMood != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await ref.read(moodServiceProvider).removeMood(key);
                    ref.invalidate(allMoodsProvider);
                    ref.invalidate(weeklyMoodDistributionProvider);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Clear mood',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            ],
          ),
        ),
      ),
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
      case Priority.low: return AppColors.secondary;
      case Priority.medium: return AppColors.warning;
      case Priority.high: return Colors.orange;
      case Priority.urgent: return AppColors.error;
    }
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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
      child: Row(children: [
        Container(width: 4, height: 40,
          decoration: BoxDecoration(color: _priorityColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(children: [
            if (task.startDate != null) ...[
              Icon(Icons.play_arrow, size: 12, color: AppColors.textMuted),
              Text(_formatDateTime(task.startDate!), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              const SizedBox(width: 8),
            ],
            if (task.dueDate != null) ...[
              Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
              Text(_formatDateTime(task.dueDate!), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ]),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _priorityColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(task.priority.name.toUpperCase(), style: TextStyle(color: _priorityColor, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
