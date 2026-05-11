# Calendar & Gantt Feature Design

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan.

**Goal:** Add calendar and Gantt chart views for task management, enabling users to view task due dates on a calendar and visualize task timelines.

**Architecture:** Two new tab pages (Calendar, Gantt) sharing existing data providers. Calendar uses `table_calendar` package, Gantt uses custom `CustomPainter` implementation.

**Tech Stack:**
- `table_calendar: ^3.1.0` - Calendar widget
- Custom `CustomPainter` - Gantt chart rendering

---

## 1. Navigation Structure

Add two new tabs to `MainScreen`:
```
Calendar Tab (index 3) → CalendarScreen
Gantt Tab (index 4) → GanttScreen
```

Navigation rail updates to include new destinations.

---

## 2. Calendar Screen

### 2.1 View Modes
- **Day View**: Single day with hourly slots
- **Week View**: 7-day view with daily columns
- **Month View**: Traditional monthly grid (default)

### 2.2 Display Modes
Toggle button at bottom:
- **Marker Mode**: Colored dots/badges on dates with tasks
- **Time Block Mode**: Task bars spanning from start to due date

### 2.3 Interactions
| Action | Result |
|--------|--------|
| Tap date cell | Show tasks due on that day in bottom sheet |
| Tap task badge/bar | Open task detail dialog |
| Long press (time block mode) | Drag to adjust task dates |

### 2.4 Visual Design
- Priority colors: High=#ff4757, Medium=#ffcc00, Low=#00d4ff, Urgent=#ff6b81
- Today highlight: Primary color (#00ff9f) circle
- Selected date: Surface variant background

---

## 3. Gantt Screen

### 3.1 View Modes
- **Project View**: Grouped by project, show project tasks timeline
- **Personal View**: All tasks ungrouped, chronological

### 3.2 Timeline Display
- **X-axis**: Time scale (days, adaptive based on date range)
- **Y-axis**: Task list
- **Task bar**: Horizontal bar from startDate to dueDate
- **Today line**: Red vertical dashed line

### 3.3 Visual Design
| Element | Style |
|---------|-------|
| Task bar | Rounded rectangle, priority color fill, 60% opacity |
| Task bar border | Priority color, 2px solid |
| Bar height | 32px |
| Row height | 48px |
| Bar text | Task title, white, 12px, truncated |

---

## 4. Dependencies

```yaml
# pubspec.yaml
dependencies:
  table_calendar: ^3.1.0
```

---

## 5. File Structure

```
lib/features/calendar/
├── presentation/
│   └── screens/calendar_screen.dart
└── providers/

lib/features/gantt/
├── presentation/
│   └── screens/gantt_screen.dart
└── widgets/
    └── gantt_chart.dart       # CustomPainter
    └── gantt_task_bar.dart    # Task bar widget
    └── gantt_timeline.dart   # Timeline header
```

---

## 6. Data Flow

```
Existing Providers:
├── TasksProvider → List<Task>
└── ProjectsProvider → List<Project>

Calendar/Gantt read from existing providers (read-only).

CalendarProvider (if needed):
└── selectedDate: DateTime
└── viewMode: CalendarViewMode (day/week/month)
└── displayMode: DisplayMode (marker/timeblock)

GanttProvider (if needed):
└── viewMode: GanttViewMode (project/personal)
└── timeRange: DateTimeRange
```

---

## 7. Edge Cases

| Case | Handling |
|------|----------|
| Task without dueDate | Not shown on calendar/Gantt |
| Task without startDate | Use createdAt as proxy |
| Overdue task | Red tint on bar/dot |
| Task spanning multiple weeks | Visible across week boundaries |
| Empty state | Show illustration + "No tasks in this period" |

---

## 8. Implementation Order

1. Add `table_calendar` dependency
2. Create `CalendarScreen` with month view
3. Implement marker mode
4. Implement time block mode
5. Add day/week view switching
6. Create `GanttScreen` with timeline
7. Implement task bars with `CustomPainter`
8. Add project/personal view toggle
9. Add today line
10. Polish and test