# Calendar & Gantt Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add calendar and Gantt chart views for task management with marker/timeblock modes and project/personal views.

**Architecture:** Two new feature modules (calendar, gantt) with presentation screens. Data from existing TasksProvider and ProjectsProvider. Calendar uses table_calendar package, Gantt uses CustomPainter.

**Tech Stack:** table_calendar: ^3.1.0, CustomPainter

---

## Task 1: Add table_calendar Dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Update pubspec.yaml**

```yaml
dependencies:
  table_calendar: ^3.1.0
```

- [ ] **Step 2: Run flutter pub get**

Run: `cd "E:/01-AI-Proj/task-manager" && flutter pub get`
Expected: Downloads table_calendar package

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml
git commit -m "feat: add table_calendar for calendar view"
```

---

## Task 2: Update Navigation Structure

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: Update MainScreen with new tabs**

```dart
static const List<NavigationDestination> _destinations = [
  NavigationDestination(
    icon: Icon(Icons.folder_outlined, size: 26),
    selectedIcon: Icon(Icons.folder, size: 26),
    label: 'Projects',
  ),
  NavigationDestination(
    icon: Icon(Icons.task_alt_outlined, size: 26),
    selectedIcon: Icon(Icons.task_alt, size: 26),
    label: 'Tasks',
  ),
  NavigationDestination(
    icon: Icon(Icons.timer_outlined, size: 26),
    selectedIcon: Icon(Icons.timer, size: 26),
    label: 'Time',
  ),
  NavigationDestination(
    icon: Icon(Icons.calendar_month_outlined, size: 26),
    selectedIcon: Icon(Icons.calendar_month, size: 26),
    label: 'Calendar',
  ),
  NavigationDestination(
    icon: Icon(Icons.bar_chart_outlined, size: 26),
    selectedIcon: Icon(Icons.bar_chart, size: 26),
    label: 'Gantt',
  ),
];
```

- [ ] **Step 2: Update _buildBody switch**

```dart
Widget _buildBody() {
  switch (_selectedIndex) {
    case 0:
      return const ProjectsScreen();
    case 1:
      return const TasksScreen();
    case 2:
      return const TimeTrackingScreen();
    case 3:
      return const CalendarScreen();
    case 4:
      return const GanttScreen();
    default:
      return const ProjectsScreen();
  }
}
```

- [ ] **Step 3: Add imports and stub screens**

```dart
import '../features/calendar/presentation/screens/calendar_screen.dart';
import '../features/gantt/presentation/screens/gantt_screen.dart';
```

- [ ] **Step 4: Commit**

```bash
git add lib/app.dart
git commit -m "feat: add calendar and gantt tabs to navigation"
```

---

## Task 3: Create Calendar Feature Structure

**Files:**
- Create: `lib/features/calendar/presentation/screens/calendar_screen.dart`
- Create: `lib/features/calendar/presentation/providers/calendar_provider.dart`

- [ ] **Step 1: Create calendar_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CalendarDisplayMode { marker, timeBlock }

class CalendarState {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarDisplayMode displayMode;

  CalendarState({
    required this.focusedDay,
    required this.selectedDay,
    this.displayMode = CalendarDisplayMode.marker,
  });
}

class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier()
      : super(CalendarState(
          focusedDay: DateTime.now(),
          selectedDay: DateTime.now(),
        ));

  void setFocusedDay(DateTime day) {
    state = CalendarState(
      focusedDay: day,
      selectedDay: state.selectedDay,
      displayMode: state.displayMode,
    );
  }

  void setSelectedDay(DateTime day) {
    state = CalendarState(
      focusedDay: state.focusedDay,
      selectedDay: day,
      displayMode: state.displayMode,
    );
  }

  void toggleDisplayMode() {
    state = CalendarState(
      focusedDay: state.focusedDay,
      selectedDay: state.selectedDay,
      displayMode: state.displayMode == CalendarDisplayMode.marker
          ? CalendarDisplayMode.timeBlock
          : CalendarDisplayMode.marker,
    );
  }
}

final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier();
});
```

- [ ] **Step 2: Create calendar_screen.dart stub**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/calendar_provider.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Calendar Screen - Coming Soon'),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/calendar/
git commit -m "feat: create calendar feature structure"
```

---

## Task 4: Implement Calendar Month View with Markers

**Files:**
- Modify: `lib/features/calendar/presentation/screens/calendar_screen.dart`

- [ ] **Step 1: Implement full calendar screen with table_calendar**

```dart
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
              color: AppColors.primary.withOpacity(0.1),
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
          color: AppColors.primary.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(color: AppColors.textPrimary),
        selectedDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(color: AppColors.background),
        markerDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
      eventLoader: (day) {
        return tasks.where((task) {
          if (task.dueDate == null) return false;
          return isSameDay(task.dueDate!, day);
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
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;
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
      if (task.dueDate == null) return false;
      return isSameDay(task.dueDate!, selectedDay);
    }).toList();

    if (dayTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
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
            child: Text(
              task.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _priorityColor.withOpacity(0.15),
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
```

- [ ] **Step 2: Verify build**

Run: `cd "E:/01-AI-Proj/task-manager" && flutter build apk --debug`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add lib/features/calendar/
git commit -m "feat: implement calendar month view with task markers"
```

---

## Task 5: Implement Time Block Mode for Calendar

**Files:**
- Modify: `lib/features/calendar/presentation/screens/calendar_screen.dart`

- [ ] **Step 1: Add time block calendar builders**

Add to the `calendarBuilders` in `CalendarScreen`:

```dart
calendarBuilders: CalendarBuilders(
  markerBuilder: (context, date, events) {
    if (events.isEmpty) return null;
    final displayMode = ref.read(calendarProvider).displayMode;
    if (displayMode == CalendarDisplayMode.timeBlock) {
      // Time block mode - show task bars
      return null; // Handled by defaultBuilder
    }
    // Marker mode - show colored dots
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
  defaultBuilder: (context, date, focusedDay) {
    final displayMode = ref.read(calendarProvider).displayMode;
    if (displayMode == CalendarDisplayMode.timeBlock) {
      // Show task duration bars in time block mode
      final dayTasks = tasks.where((task) {
        if (task.dueDate == null || task.createdAt == null) return false;
        final taskStart = task.createdAt!;
        final taskEnd = task.dueDate!;
        return !date.isBefore(taskStart) && !date.isAfter(taskEnd);
      }).toList();

      if (dayTasks.isEmpty) return null;

      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: dayTasks.take(2).map((task) {
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
    return null;
  },
),
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/calendar/
git commit -m "feat: add time block display mode to calendar"
```

---

## Task 6: Create Gantt Feature Structure

**Files:**
- Create: `lib/features/gantt/presentation/screens/gantt_screen.dart`
- Create: `lib/features/gantt/presentation/providers/gantt_provider.dart`
- Create: `lib/features/gantt/widgets/gantt_chart.dart`

- [ ] **Step 1: Create gantt_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GanttViewMode { project, personal }

class GanttState {
  final GanttViewMode viewMode;
  final DateTime startDate;
  final DateTime endDate;

  GanttState({
    this.viewMode = GanttViewMode.project,
    required this.startDate,
    required this.endDate,
  });
}

class GanttNotifier extends StateNotifier<GanttState> {
  GanttNotifier()
      : super(GanttState(
          startDate: DateTime.now().subtract(const Duration(days: 7)),
          endDate: DateTime.now().add(const Duration(days: 30)),
        ));

  void setViewMode(GanttViewMode mode) {
    state = GanttState(
      viewMode: mode,
      startDate: state.startDate,
      endDate: state.endDate,
    );
  }

  void setTimeRange(DateTime start, DateTime end) {
    state = GanttState(
      viewMode: state.viewMode,
      startDate: start,
      endDate: end,
    );
  }
}

final ganttProvider = StateNotifierProvider<GanttNotifier, GanttState>((ref) {
  return GanttNotifier();
});
```

- [ ] **Step 2: Create gantt_chart.dart**

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/task.dart';

class GanttChart extends StatelessWidget {
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;

  const GanttChart({
    super.key,
    required this.tasks,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GanttChartPainter(
        tasks: tasks,
        startDate: startDate,
        endDate: endDate,
      ),
      size: Size.infinite,
    );
  }
}

class GanttChartPainter extends CustomPainter {
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;

  GanttChartPainter({
    required this.tasks,
    required this.startDate,
    required this.endDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final taskHeight = 32.0;
    final rowHeight = 48.0;
    final leftPadding = 120.0;
    final dayWidth = (size.width - leftPadding) / endDate.difference(startDate).inDays.clamp(1, 365);

    final todayX = leftPadding + DateTime.now().difference(startDate).inDays * dayWidth;

    // Draw today line
    final todayPaint = Paint()
      ..color = AppColors.error
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    todayPaint.style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(todayX, 0),
      Offset(todayX, size.height),
      todayPaint,
    );

    // Draw task bars
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final taskStart = task.createdAt;
      final taskEnd = task.dueDate ?? task.createdAt.add(const Duration(days: 1));

      final startDays = taskStart.difference(startDate).inDays.clamp(0, endDate.difference(startDate).inDays);
      final endDays = taskEnd.difference(startDate).inDays.clamp(0, endDate.difference(startDate).inDays);
      final duration = (endDays - startDays).clamp(1, endDate.difference(startDate).inDays);

      final barX = leftPadding + startDays * dayWidth;
      final barY = i * rowHeight + (rowHeight - taskHeight) / 2;
      final barWidth = duration * dayWidth;

      final color = _getPriorityColor(task.priority);

      // Draw bar
      final barPaint = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.fill;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barWidth, taskHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(barRect, barPaint);

      // Draw border
      final borderPaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(barRect, borderPaint);

      // Draw title
      final textPainter = TextPainter(
        text: TextSpan(
          text: task.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      textPainter.layout(maxWidth: barWidth - 8);
      textPainter.paint(canvas, Offset(barX + 4, barY + (taskHeight - textPainter.height) / 2));
    }
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

- [ ] **Step 3: Create gantt_screen.dart stub**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/task.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../providers/gantt_provider.dart';
import '../widgets/gantt_chart.dart';

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
            onChanged: (value) {
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
        // Timeline header
        _buildTimelineHeader(state),
        const Divider(height: 1, color: AppColors.border),
        // Gantt chart
        Expanded(
          child: GanttChart(
            tasks: visibleTasks,
            startDate: state.startDate,
            endDate: state.endDate,
          ),
        ),
      ],
    );
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
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/gantt/
git commit -m "feat: create gantt feature structure with chart"
```

---

## Task 7: Add Task Bar Labels and Legend

**Files:**
- Modify: `lib/features/gantt/widgets/gantt_chart.dart`

- [ ] **Step 1: Enhance gantt_chart.dart with legend and scroll**

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/task.dart';

class GanttChart extends StatelessWidget {
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;

  const GanttChart({
    super.key,
    required this.tasks,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Legend
        _buildLegend(),
        const Divider(height: 1, color: AppColors.border),
        // Chart
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _calculateWidth(),
              child: CustomPaint(
                painter: GanttChartPainter(
                  tasks: tasks,
                  startDate: startDate,
                  endDate: endDate,
                ),
                size: Size(_calculateWidth(), double.infinity),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _calculateWidth() {
    final days = endDate.difference(startDate).inDays.clamp(1, 365);
    return 120 + days * 30.0; // Left padding + days * pixels per day
  }

  Widget _buildLegend() {
    return Container(
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/gantt/
git commit -m "feat: add legend and scrollable gantt chart"
```

---

## Task 8: Test and Install

- [ ] **Step 1: Build APK**

Run: `cd "E:/01-AI-Proj/task-manager" && flutter build apk --debug`
Expected: Build succeeds

- [ ] **Step 2: Install to emulator**

Run: `cd "E:/01-AI-Proj/task-manager" && adb install -r build/app/outputs/flutter-apk/app-debug.apk`
Expected: Install success

- [ ] **Step 3: Launch**

Run: `adb shell am start -n com.example.task_manager/com.example.task_manager.MainActivity`
Expected: App launches

---

## Summary

Added:
- Calendar tab with month view, task markers, marker/timeblock modes
- Gantt tab with project/personal views, priority-colored task bars, today line
- Legend for priority colors
- Scrollable chart for long timelines