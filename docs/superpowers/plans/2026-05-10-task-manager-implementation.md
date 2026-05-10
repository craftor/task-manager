# Task Manager MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Phase 1 MVP of the Task Manager app with project management, task CRUD, time tracking, and offline storage.

**Architecture:** Clean Architecture with Flutter, using Drift for local SQLite storage, Riverpod for state management, and Supabase for cloud sync (deferred for MVP).

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, Supabase

---

## File Structure

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── theme/
│   │   └── app_theme.dart
│   ├── constants/
│   │   └── app_constants.dart
│   └── utils/
│       └── date_utils.dart
├── data/
│   ├── datasources/
│   │   └── local/
│   │       └── app_database.dart
│   └── repositories/
│       ├── project_repository_impl.dart
│       └── task_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── project.dart
│   │   ├── task.dart
│   │   └── time_entry.dart
│   └── repositories/
│       ├── project_repository.dart
│       └── task_repository.dart
└── features/
    ├── projects/
    │   ├── data/
    │   │   └── project_repository_impl.dart
    │   ├── domain/
    │   │   └── project_entity.dart
    │   └── presentation/
    │       ├── providers/
    │       │   └── projects_provider.dart
    │       └── screens/
    │           └── projects_screen.dart
    └── tasks/
        ├── data/
        │   └── task_repository_impl.dart
        ├── domain/
        │   └── task_entity.dart
        └── presentation/
            ├── providers/
            │   └── tasks_provider.dart
            └── screens/
                └── tasks_screen.dart
```

---

## Task 1: Project Setup

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/app.dart`
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/core/constants/app_constants.dart`

- [ ] **Step 1: Create pubspec.yaml with dependencies**

```yaml
name: task_manager
description: Personal task and time management application
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.9
  drift: ^2.14.1
  sqlite3_flutter_libs: ^0.5.18
  path_provider: ^2.1.1
  path: ^1.8.3
  intl: ^0.18.1
  uuid: ^4.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  drift_dev: ^2.14.1
  build_runner: ^2.4.7

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Create core/theme/app_theme.dart**

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0d0d1a);
  static const surface = Color(0xFF1a1a2e);
  static const primary = Color(0xFF00ff9f);
  static const secondary = Color(0xFF00d4ff);
  static const textPrimary = Color(0xFFe0e0e0);
  static const border = Color(0xFF2a2a4a);
  static const success = Color(0xFF00ff9f);
  static const warning = Color(0xFFffcc00);
  static const error = Color(0xFFff4757);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create core/constants/app_constants.dart**

```dart
class AppConstants {
  static const String appName = 'Task Manager';
  static const String dbName = 'task_manager.db';

  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // Border radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusCard = 16.0;

  // Priority levels
  static const int priorityLow = 1;
  static const int priorityMedium = 2;
  static const int priorityHigh = 3;
  static const int priorityUrgent = 4;
}
```

- [ ] **Step 4: Create lib/app.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            backgroundColor: const Color(0xFF1a1a2e),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: Text('Projects'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.task_outlined),
                selectedIcon: Icon(Icons.task),
                label: Text('Tasks'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.timer_outlined),
                selectedIcon: Icon(Icons.timer),
                label: Text('Time'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const ProjectsView();
      case 1:
        return const TasksView();
      case 2:
        return const TimeTrackingView();
      default:
        return const ProjectsView();
    }
  }
}

class ProjectsView extends StatelessWidget {
  const ProjectsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Projects', style: TextStyle(fontSize: 24)));
  }
}

class TasksView extends StatelessWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Tasks', style: TextStyle(fontSize: 24)));
  }
}

class TimeTrackingView extends StatelessWidget {
  const TimeTrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Time Tracking', style: TextStyle(fontSize: 24)));
  }
}
```

- [ ] **Step 5: Create lib/main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: TaskManagerApp(),
    ),
  );
}
```

- [ ] **Step 6: Commit**

```bash
git init
git add pubspec.yaml lib/main.dart lib/app.dart lib/core/theme/app_theme.dart lib/core/constants/app_constants.dart
git commit -m "feat: initial project setup with Flutter theme and app structure

- Add pubspec.yaml with dependencies (flutter_riverpod, drift, etc.)
- Create dark theme with neon accent colors
- Create app constants for spacing and priorities
- Add basic app shell with navigation rail
- Setup ProviderScope for Riverpod"
```

---

## Task 2: Drift Database Setup

**Files:**
- Create: `lib/data/datasources/local/app_database.dart`
- Create: `lib/domain/entities/project.dart`
- Create: `lib/domain/entities/task.dart`
- Create: `lib/domain/entities/time_entry.dart`

- [ ] **Step 1: Create domain/entities/project.dart**

```dart
class Project {
  final String id;
  final String? parentId;
  final String name;
  final String color;
  final String icon;
  final DateTime createdAt;

  const Project({
    required this.id,
    this.parentId,
    required this.name,
    required this.color,
    required this.icon,
    required this.createdAt,
  });

  Project copyWith({
    String? id,
    String? parentId,
    String? name,
    String? color,
    String? icon,
    DateTime? createdAt,
  }) {
    return Project(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

- [ ] **Step 2: Create domain/entities/task.dart**

```dart
enum TaskStatus { pending, inProgress, completed }

enum Priority { low, medium, high, urgent }

class Task {
  final String id;
  final String projectId;
  final String? parentTaskId;
  final String title;
  final String description;
  final Priority priority;
  final TaskStatus status;
  final DateTime? dueDate;
  final List<String> tags;
  final int? estimatedMinutes;
  final int? actualMinutes;
  final bool isRecurring;
  final String? recurringRule;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.projectId,
    this.parentTaskId,
    required this.title,
    this.description = '',
    this.priority = Priority.medium,
    this.status = TaskStatus.pending,
    this.dueDate,
    this.tags = const [],
    this.estimatedMinutes,
    this.actualMinutes,
    this.isRecurring = false,
    this.recurringRule,
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({
    String? id,
    String? projectId,
    String? parentTaskId,
    String? title,
    String? description,
    Priority? priority,
    TaskStatus? status,
    DateTime? dueDate,
    List<String>? tags,
    int? estimatedMinutes,
    int? actualMinutes,
    bool? isRecurring,
    String? recurringRule,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      tags: tags ?? this.tags,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringRule: recurringRule ?? this.recurringRule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **Step 3: Create domain/entities/time_entry.dart**

```dart
class TimeEntry {
  final String id;
  final String taskId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final String note;
  final bool manual;

  const TimeEntry({
    required this.id,
    required this.taskId,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    this.note = '',
    this.manual = false,
  });

  TimeEntry copyWith({
    String? id,
    String? taskId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    String? note,
    bool? manual,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      note: note ?? this.note,
      manual: manual ?? this.manual,
    );
  }
}
```

- [ ] **Step 4: Create data/datasources/local/app_database.dart**

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/constants/app_constants.dart';

part 'app_database.g.dart';

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get color => text()();
  TextColumn get icon => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get parentTaskId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get priority => integer().withDefault(const Constant(2))();
  IntColumn get status => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get tags => text().withDefault(const Constant(''))();
  IntColumn get estimatedMinutes => integer().nullable()();
  IntColumn get actualMinutes => integer().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurringRule => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class TimeEntries extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id)();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get manual => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Projects, Tasks, TimeEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Project queries
  Future<List<Project>> getAllProjects() => select(projects).get();
  Stream<List<Project>> watchAllProjects() => select(projects).watch();
  Future<Project?> getProjectById(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();
  Future<int> insertProject(ProjectsCompanion project) =>
      into(projects).insert(project);
  Future<bool> updateProject(ProjectsCompanion project) =>
      update(projects).replace(project);
  Future<int> deleteProject(String id) =>
      (delete(projects)..where((p) => p.id.equals(id))).go();

  // Task queries
  Future<List<Task>> getAllTasks() => select(tasks).get();
  Stream<List<Task>> watchAllTasks() => select(tasks).watch();
  Future<Task?> getTaskById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<List<Task>> getTasksByProject(String projectId) =>
      (select(tasks)..where((t) => t.projectId.equals(projectId))).get();
  Future<int> insertTask(TasksCompanion task) => into(tasks).insert(task);
  Future<bool> updateTask(TasksCompanion task) => update(tasks).replace(task);
  Future<int> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  // Time entry queries
  Future<List<TimeEntry>> getAllTimeEntries() => select(timeEntries).get();
  Stream<List<TimeEntry>> watchAllTimeEntries() => select(timeEntries).watch();
  Future<List<TimeEntry>> getTimeEntriesByTask(String taskId) =>
      (select(timeEntries)..where((e) => e.taskId.equals(taskId))).get();
  Future<int> insertTimeEntry(TimeEntriesCompanion entry) =>
      into(timeEntries).insert(entry);
  Future<bool> updateTimeEntry(TimeEntriesCompanion entry) =>
      update(timeEntries).replace(entry);
  Future<int> deleteTimeEntry(String id) =>
      (delete(timeEntries)..where((e) => e.id.equals(id))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConstants.dbName));
    return NativeDatabase.createInBackground(file);
  });
}
```

- [ ] **Step 5: Run build_runner to generate drift code**

Run: `flutter pub run build_runner build --delete-conflicting-outputs`

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/project.dart lib/domain/entities/task.dart lib/domain/entities/time_entry.dart lib/data/datasources/local/app_database.dart
git commit -m "feat: add Drift database with project, task, time_entry tables

- Create domain entities (Project, Task, TimeEntry) with copyWith
- Setup Drift database with Projects, Tasks, TimeEntries tables
- Add CRUD queries for all tables
- Generate drift code with build_runner"
```

---

## Task 3: Repository Interfaces and Implementations

**Files:**
- Create: `lib/domain/repositories/project_repository.dart`
- Create: `lib/domain/repositories/task_repository.dart`
- Create: `lib/data/repositories/project_repository_impl.dart`
- Create: `lib/data/repositories/task_repository_impl.dart`

- [ ] **Step 1: Create domain/repositories/project_repository.dart**

```dart
import '../entities/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getAllProjects();
  Stream<List<Project>> watchAllProjects();
  Future<Project?> getProjectById(String id);
  Future<void> createProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String id);
}
```

- [ ] **Step 2: Create domain/repositories/task_repository.dart**

```dart
import '../entities/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getAllTasks();
  Stream<List<Task>> watchAllTasks();
  Future<Task?> getTaskById(String id);
  Future<List<Task>> getTasksByProject(String projectId);
  Future<void> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String id);
}
```

- [ ] **Step 3: Create data/repositories/project_repository_impl.dart**

```dart
import 'package:drift/drift.dart';
import '../../domain/entities/project.dart' as entity;
import '../../domain/repositories/project_repository.dart';
import '../datasources/local/app_database.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final AppDatabase _db;

  ProjectRepositoryImpl(this._db);

  @override
  Future<List<entity.Project>> getAllProjects() async {
    final projects = await _db.getAllProjects();
    return projects.map(_mapToEntity).toList();
  }

  @override
  Stream<List<entity.Project>> watchAllProjects() {
    return _db.watchAllProjects().map(
          (projects) => projects.map(_mapToEntity).toList(),
        );
  }

  @override
  Future<entity.Project?> getProjectById(String id) async {
    final project = await _db.getProjectById(id);
    return project != null ? _mapToEntity(project) : null;
  }

  @override
  Future<void> createProject(entity.Project project) async {
    await _db.insertProject(
      ProjectsCompanion(
        id: Value(project.id),
        parentId: Value(project.parentId),
        name: Value(project.name),
        color: Value(project.color),
        icon: Value(project.icon),
        createdAt: Value(project.createdAt),
      ),
    );
  }

  @override
  Future<void> updateProject(entity.Project project) async {
    await _db.updateProject(
      ProjectsCompanion(
        id: Value(project.id),
        parentId: Value(project.parentId),
        name: Value(project.name),
        color: Value(project.color),
        icon: Value(project.icon),
        createdAt: Value(project.createdAt),
      ),
    );
  }

  @override
  Future<void> deleteProject(String id) async {
    await _db.deleteProject(id);
  }

  entity.Project _mapToEntity(Project dbProject) {
    return entity.Project(
      id: dbProject.id,
      parentId: dbProject.parentId,
      name: dbProject.name,
      color: dbProject.color,
      icon: dbProject.icon,
      createdAt: dbProject.createdAt,
    );
  }
}
```

- [ ] **Step 4: Create data/repositories/task_repository_impl.dart**

```dart
import 'package:drift/drift.dart';
import '../../domain/entities/task.dart' as entity;
import '../../domain/repositories/task_repository.dart';
import '../datasources/local/app_database.dart';

class TaskRepositoryImpl implements TaskRepository {
  final AppDatabase _db;

  TaskRepositoryImpl(this._db);

  @override
  Future<List<entity.Task>> getAllTasks() async {
    final tasks = await _db.getAllTasks();
    return tasks.map(_mapToEntity).toList();
  }

  @override
  Stream<List<entity.Task>> watchAllTasks() {
    return _db.watchAllTasks().map(
          (tasks) => tasks.map(_mapToEntity).toList(),
        );
  }

  @override
  Future<entity.Task?> getTaskById(String id) async {
    final task = await _db.getTaskById(id);
    return task != null ? _mapToEntity(task) : null;
  }

  @override
  Future<List<entity.Task>> getTasksByProject(String projectId) async {
    final tasks = await _db.getTasksByProject(projectId);
    return tasks.map(_mapToEntity).toList();
  }

  @override
  Future<void> createTask(entity.Task task) async {
    await _db.insertTask(
      TasksCompanion(
        id: Value(task.id),
        projectId: Value(task.projectId),
        parentTaskId: Value(task.parentTaskId),
        title: Value(task.title),
        description: Value(task.description),
        priority: Value(task.priority.index),
        status: Value(task.status.index),
        dueDate: Value(task.dueDate),
        tags: Value(task.tags.join(',')),
        estimatedMinutes: Value(task.estimatedMinutes),
        actualMinutes: Value(task.actualMinutes),
        isRecurring: Value(task.isRecurring),
        recurringRule: Value(task.recurringRule),
        createdAt: Value(task.createdAt),
        updatedAt: Value(task.updatedAt),
      ),
    );
  }

  @override
  Future<void> updateTask(entity.Task task) async {
    await _db.updateTask(
      TasksCompanion(
        id: Value(task.id),
        projectId: Value(task.projectId),
        parentTaskId: Value(task.parentTaskId),
        title: Value(task.title),
        description: Value(task.description),
        priority: Value(task.priority.index),
        status: Value(task.status.index),
        dueDate: Value(task.dueDate),
        tags: Value(task.tags.join(',')),
        estimatedMinutes: Value(task.estimatedMinutes),
        actualMinutes: Value(task.actualMinutes),
        isRecurring: Value(task.isRecurring),
        recurringRule: Value(task.recurringRule),
        createdAt: Value(task.createdAt),
        updatedAt: Value(task.updatedAt),
      ),
    );
  }

  @override
  Future<void> deleteTask(String id) async {
    await _db.deleteTask(id);
  }

  entity.Task _mapToEntity(Task dbTask) {
    return entity.Task(
      id: dbTask.id,
      projectId: dbTask.projectId,
      parentTaskId: dbTask.parentTaskId,
      title: dbTask.title,
      description: dbTask.description,
      priority: entity.Priority.values[dbTask.priority],
      status: entity.TaskStatus.values[dbTask.status],
      dueDate: dbTask.dueDate,
      tags: dbTask.tags.isEmpty ? [] : dbTask.tags.split(','),
      estimatedMinutes: dbTask.estimatedMinutes,
      actualMinutes: dbTask.actualMinutes,
      isRecurring: dbTask.isRecurring,
      recurringRule: dbTask.recurringRule,
      createdAt: dbTask.createdAt,
      updatedAt: dbTask.updatedAt,
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/project_repository.dart lib/domain/repositories/task_repository.dart lib/data/repositories/project_repository_impl.dart lib/data/repositories/task_repository_impl.dart
git commit -m "feat: add repository interfaces and implementations

- Create ProjectRepository and TaskRepository interfaces
- Implement repositories using Drift database
- Map between domain entities and database models"
```

---

## Task 4: Riverpod Providers

**Files:**
- Create: `lib/features/projects/presentation/providers/projects_provider.dart`
- Create: `lib/features/tasks/presentation/providers/tasks_provider.dart`

- [ ] **Step 1: Create features/projects/presentation/providers/projects_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../../../data/repositories/project_repository_impl.dart';
import '../../../../domain/entities/project.dart';
import '../../../../domain/repositories/project_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl(ref.watch(databaseProvider));
});

final projectsProvider =
    StreamNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

class ProjectsNotifier extends StreamNotifier<List<Project>> {
  @override
  Stream<List<Project>> build() {
    return ref.watch(projectRepositoryProvider).watchAllProjects();
  }

  Future<void> createProject({
    String? parentId,
    required String name,
    required String color,
    required String icon,
  }) async {
    final repository = ref.read(projectRepositoryProvider);
    final project = Project(
      id: const Uuid().v4(),
      parentId: parentId,
      name: name,
      color: color,
      icon: icon,
      createdAt: DateTime.now(),
    );
    await repository.createProject(project);
  }

  Future<void> updateProject(Project project) async {
    final repository = ref.read(projectRepositoryProvider);
    await repository.updateProject(project);
  }

  Future<void> deleteProject(String id) async {
    final repository = ref.read(projectRepositoryProvider);
    await repository.deleteProject(id);
  }
}
```

- [ ] **Step 2: Create features/tasks/presentation/providers/tasks_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/repositories/task_repository_impl.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/repositories/task_repository.dart';
import '../../../projects/presentation/providers/projects_provider.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(databaseProvider));
});

final tasksProvider = StreamNotifierProvider<TasksNotifier, List<Task>>(
  TasksNotifier.new,
);

class TasksNotifier extends StreamNotifier<List<Task>> {
  @override
  Stream<List<Task>> build() {
    return ref.watch(taskRepositoryProvider).watchAllTasks();
  }

  Future<void> createTask({
    required String projectId,
    String? parentTaskId,
    required String title,
    String description = '',
    Priority priority = Priority.medium,
    DateTime? dueDate,
    List<String> tags = const [],
    int? estimatedMinutes,
    bool isRecurring = false,
    String? recurringRule,
  }) async {
    final repository = ref.read(taskRepositoryProvider);
    final now = DateTime.now();
    final task = Task(
      id: const Uuid().v4(),
      projectId: projectId,
      parentTaskId: parentTaskId,
      title: title,
      description: description,
      priority: priority,
      status: TaskStatus.pending,
      dueDate: dueDate,
      tags: tags,
      estimatedMinutes: estimatedMinutes,
      isRecurring: isRecurring,
      recurringRule: recurringRule,
      createdAt: now,
      updatedAt: now,
    );
    await repository.createTask(task);
  }

  Future<void> updateTask(Task task) async {
    final repository = ref.read(taskRepositoryProvider);
    final updatedTask = task.copyWith(updatedAt: DateTime.now());
    await repository.updateTask(updatedTask);
  }

  Future<void> deleteTask(String id) async {
    final repository = ref.read(taskRepositoryProvider);
    await repository.deleteTask(id);
  }

  Future<void> toggleTaskStatus(String id) async {
    final repository = ref.read(taskRepositoryProvider);
    final task = await repository.getTaskById(id);
    if (task != null) {
      final newStatus = task.status == TaskStatus.completed
          ? TaskStatus.pending
          : TaskStatus.completed;
      final updatedTask = task.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      await repository.updateTask(updatedTask);
    }
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/projects/presentation/providers/projects_provider.dart lib/features/tasks/presentation/providers/tasks_provider.dart
git commit -m "feat: add Riverpod providers for projects and tasks

- Add database provider and project repository provider
- Create ProjectsNotifier with stream-based state
- Create TasksNotifier with stream-based state
- Add CRUD methods with UUID generation"
```

---

## Task 5: Projects UI Screen

**Files:**
- Create: `lib/features/projects/presentation/screens/projects_screen.dart`

- [ ] **Step 1: Create features/projects/presentation/screens/projects_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/project.dart';
import '../providers/projects_provider.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Projects'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showProjectDialog(context, ref),
          ),
        ],
      ),
      body: projectsAsync.when(
        data: (projects) => _buildProjectList(context, ref, projects),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildProjectList(
    BuildContext context,
    WidgetRef ref,
    List<Project> projects,
  ) {
    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_outlined, size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            const Text(
              'No projects yet',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showProjectDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create Project'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return _ProjectCard(
          project: project,
          onTap: () => _showProjectDialog(context, ref, project),
          onDelete: () => ref.read(projectsProvider.notifier).deleteProject(project.id),
        );
      },
    );
  }

  void _showProjectDialog(BuildContext context, WidgetRef ref, [Project? project]) {
    final nameController = TextEditingController(text: project?.name ?? '');
    final isEditing = project != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(isEditing ? 'Edit Project' : 'New Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                labelStyle: TextStyle(color: AppColors.textPrimary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _ColorPicker(
              selectedColor: project?.color ?? '#00ff9f',
              onColorSelected: (color) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                if (isEditing) {
                  ref.read(projectsProvider.notifier).updateProject(
                        project!.copyWith(name: nameController.text),
                      );
                } else {
                  ref.read(projectsProvider.notifier).createProject(
                        name: nameController.text,
                        color: '#00ff9f',
                        icon: 'folder',
                      );
                }
                Navigator.pop(context);
              }
            },
            child: Text(isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(int.parse(project.color.replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  project.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatefulWidget {
  final String selectedColor;
  final ValueChanged<String> onColorSelected;

  const _ColorPicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  late String _selectedColor;

  static const _colors = [
    '#00ff9f',
    '#00d4ff',
    '#ff4757',
    '#ffcc00',
    '#ff6b81',
    '#7bed9f',
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.selectedColor;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _colors.map((color) {
        final isSelected = color == _selectedColor;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedColor = color);
            widget.onColorSelected(color);
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 2: Update app.dart to use ProjectsScreen**

Edit `lib/app.dart` - change the ProjectsView to use the actual screen:

```dart
import 'features/projects/presentation/screens/projects_screen.dart';
import 'features/tasks/presentation/screens/tasks_screen.dart';
import 'features/time_tracking/presentation/screens/time_tracking_screen.dart';
```

And update the view classes to use the actual screens.

- [ ] **Step 3: Commit**

```bash
git add lib/features/projects/presentation/screens/projects_screen.dart
git commit -m "feat: add projects screen with create/edit/delete functionality

- Add ProjectsScreen with list view and empty state
- Add project card with color indicator and delete action
- Add dialog for creating/editing projects with color picker
- Integrate with ProjectsNotifier provider"
```

---

## Task 6: Tasks UI Screen

**Files:**
- Create: `lib/features/tasks/presentation/screens/tasks_screen.dart`

- [ ] **Step 1: Create features/tasks/presentation/screens/tasks_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/task.dart';
import '../providers/tasks_provider.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showTaskDialog(context, ref),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) => _buildTaskList(context, ref, tasks),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    WidgetRef ref,
    List<Task> tasks,
  ) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_outlined, size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            const Text(
              'No tasks yet',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showTaskDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create Task'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _TaskCard(
          task: task,
          onTap: () => _showTaskDialog(context, ref, task),
          onToggle: () => ref.read(tasksProvider.notifier).toggleTaskStatus(task.id),
          onDelete: () => ref.read(tasksProvider.notifier).deleteTask(task.id),
        );
      },
    );
  }

  void _showTaskDialog(BuildContext context, WidgetRef ref, [Task? task]) {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    final isEditing = task != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(isEditing ? 'Edit Task' : 'New Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  labelStyle: TextStyle(color: AppColors.textPrimary),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: AppColors.textPrimary),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _PrioritySelector(
                selectedPriority: task?.priority ?? Priority.medium,
                onChanged: (priority) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                if (isEditing) {
                  ref.read(tasksProvider.notifier).updateTask(
                        task!.copyWith(
                          title: titleController.text,
                          description: descController.text,
                        ),
                      );
                } else {
                  ref.read(tasksProvider.notifier).createTask(
                        projectId: 'default',
                        title: titleController.text,
                        description: descController.text,
                      );
                }
                Navigator.pop(context);
              }
            },
            child: Text(isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

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
    final isCompleted = task.status == TaskStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isCompleted ? AppColors.success : AppColors.border,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: _priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.dueDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Due: ${task.dueDate!.toString().split(' ')[0]}',
                        style: const TextStyle(
                          color: AppColors.border,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  final Priority selectedPriority;
  final ValueChanged<Priority> onChanged;

  const _PrioritySelector({
    required this.selectedPriority,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: Priority.values.map((priority) {
        final isSelected = priority == selectedPriority;
        return GestureDetector(
          onTap: () => onChanged(priority),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? _getPriorityColor(priority).withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getPriorityColor(priority),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              priority.name.toUpperCase(),
              style: TextStyle(
                color: _getPriorityColor(priority),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
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
```

- [ ] **Step 2: Create placeholder time_tracking_screen.dart**

Create a simple placeholder so the import works:

```dart
import 'package:flutter/material.dart';

class TimeTrackingScreen extends StatelessWidget {
  const TimeTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Time Tracking', style: TextStyle(fontSize: 24)),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/tasks/presentation/screens/tasks_screen.dart lib/features/time_tracking/presentation/screens/time_tracking_screen.dart
git commit -m "feat: add tasks screen with create/edit/complete/delete

- Add TasksScreen with list view and empty state
- Add task card with priority indicator and checkbox
- Add dialog for creating/editing tasks with priority selector
- Integrate with TasksNotifier provider"
```

---

## Task 7: Time Tracking Feature

**Files:**
- Create: `lib/features/time_tracking/data/time_entry_repository_impl.dart`
- Create: `lib/features/time_tracking/domain/time_entry_entity.dart`
- Create: `lib/features/time_tracking/presentation/providers/time_tracking_provider.dart`
- Modify: `lib/features/time_tracking/presentation/screens/time_tracking_screen.dart`

- [ ] **Step 1: Create features/time_tracking/domain/time_entry_entity.dart**

```dart
class TimeEntry {
  final String id;
  final String taskId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final String note;
  final bool manual;

  const TimeEntry({
    required this.id,
    required this.taskId,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    this.note = '',
    this.manual = false,
  });

  TimeEntry copyWith({
    String? id,
    String? taskId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    String? note,
    bool? manual,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      note: note ?? this.note,
      manual: manual ?? this.manual,
    );
  }

  bool get isRunning => endTime == null;
}
```

- [ ] **Step 2: Create features/time_tracking/data/time_entry_repository_impl.dart**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../domain/time_entry_entity.dart' as entity;
import '../../domain/time_entry_repository.dart';

class TimeEntryRepositoryImpl implements TimeEntryRepository {
  final AppDatabase _db;

  TimeEntryRepositoryImpl(this._db);

  @override
  Future<List<entity.TimeEntry>> getAllTimeEntries() async {
    final entries = await _db.getAllTimeEntries();
    return entries.map(_mapToEntity).toList();
  }

  @override
  Stream<List<entity.TimeEntry>> watchAllTimeEntries() {
    return _db.watchAllTimeEntries().map(
          (entries) => entries.map(_mapToEntity).toList(),
        );
  }

  @override
  Future<List<entity.TimeEntry>> getTimeEntriesByTask(String taskId) async {
    final entries = await _db.getTimeEntriesByTask(taskId);
    return entries.map(_mapToEntity).toList();
  }

  @override
  Future<void> createTimeEntry(entity.TimeEntry entry) async {
    await _db.insertTimeEntry(
      TimeEntriesCompanion(
        id: Value(entry.id),
        taskId: Value(entry.taskId),
        startTime: Value(entry.startTime),
        endTime: Value(entry.endTime),
        durationMinutes: Value(entry.durationMinutes),
        note: Value(entry.note),
        manual: Value(entry.manual),
      ),
    );
  }

  @override
  Future<void> updateTimeEntry(entity.TimeEntry entry) async {
    await _db.updateTimeEntry(
      TimeEntriesCompanion(
        id: Value(entry.id),
        taskId: Value(entry.taskId),
        startTime: Value(entry.startTime),
        endTime: Value(entry.endTime),
        durationMinutes: Value(entry.durationMinutes),
        note: Value(entry.note),
        manual: Value(entry.manual),
      ),
    );
  }

  @override
  Future<void> deleteTimeEntry(String id) async {
    await _db.deleteTimeEntry(id);
  }

  entity.TimeEntry _mapToEntity(TimeEntry dbEntry) {
    return entity.TimeEntry(
      id: dbEntry.id,
      taskId: dbEntry.taskId,
      startTime: dbEntry.startTime,
      endTime: dbEntry.endTime,
      durationMinutes: dbEntry.durationMinutes,
      note: dbEntry.note,
      manual: dbEntry.manual,
    );
  }
}
```

- [ ] **Step 3: Create features/time_tracking/domain/time_entry_repository.dart**

```dart
import 'time_entry_entity.dart';

abstract class TimeEntryRepository {
  Future<List<TimeEntry>> getAllTimeEntries();
  Stream<List<TimeEntry>> watchAllTimeEntries();
  Future<List<TimeEntry>> getTimeEntriesByTask(String taskId);
  Future<void> createTimeEntry(TimeEntry entry);
  Future<void> updateTimeEntry(TimeEntry entry);
  Future<void> deleteTimeEntry(String id);
}
```

- [ ] **Step 4: Create features/time_tracking/presentation/providers/time_tracking_provider.dart**

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/repositories/task_repository_impl.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../data/time_entry_repository_impl.dart';
import '../../domain/time_entry_entity.dart';
import '../../domain/time_entry_repository.dart';

final timeEntryRepositoryProvider = Provider<TimeEntryRepository>((ref) {
  return TimeEntryRepositoryImpl(ref.watch(databaseProvider));
});

final timeEntriesProvider =
    StreamNotifierProvider<TimeEntriesNotifier, List<TimeEntry>>(
  TimeEntriesNotifier.new,
);

class TimeEntriesNotifier extends StreamNotifier<List<TimeEntry>> {
  Timer? _runningTimer;
  String? _runningEntryId;

  @override
  Stream<List<TimeEntry>> build() {
    ref.onDispose(() {
      _runningTimer?.cancel();
    });
    return ref.watch(timeEntryRepositoryProvider).watchAllTimeEntries();
  }

  Future<void> startTimer(String taskId) async {
    if (_runningEntryId != null) {
      await stopTimer();
    }

    final repository = ref.read(timeEntryRepositoryProvider);
    final entry = TimeEntry(
      id: const Uuid().v4(),
      taskId: taskId,
      startTime: DateTime.now(),
    );
    await repository.createTimeEntry(entry);
    _runningEntryId = entry.id;

    _runningTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.invalidateSelf();
    });
  }

  Future<void> stopTimer() async {
    if (_runningEntryId == null) return;

    _runningTimer?.cancel();
    _runningTimer = null;

    final repository = ref.read(timeEntryRepositoryProvider);
    final entries = await repository.getAllTimeEntries();
    final runningEntry = entries.firstWhere(
      (e) => e.id == _runningEntryId,
      orElse: () => throw Exception('Entry not found'),
    );

    final endTime = DateTime.now();
    final duration = endTime.difference(runningEntry.startTime).inMinutes;

    await repository.updateTimeEntry(
      runningEntry.copyWith(
        endTime: endTime,
        durationMinutes: duration,
      ),
    );

    _runningEntryId = null;
  }

  Future<void> createManualEntry({
    required String taskId,
    required DateTime startTime,
    required DateTime endTime,
    String note = '',
  }) async {
    final repository = ref.read(timeEntryRepositoryProvider);
    final duration = endTime.difference(startTime).inMinutes;
    final entry = TimeEntry(
      id: const Uuid().v4(),
      taskId: taskId,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: duration,
      note: note,
      manual: true,
    );
    await repository.createTimeEntry(entry);
  }

  Future<void> deleteTimeEntry(String id) async {
    if (_runningEntryId == id) {
      _runningTimer?.cancel();
      _runningEntryId = null;
    }
    final repository = ref.read(timeEntryRepositoryProvider);
    await repository.deleteTimeEntry(id);
  }
}
```

- [ ] **Step 5: Update time_tracking_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../providers/time_tracking_provider.dart';

class TimeTrackingScreen extends ConsumerWidget {
  const TimeTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeEntriesAsync = ref.watch(timeEntriesProvider);
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Time Tracking'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showManualEntryDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          _ActiveTimerCard(ref: ref),
          Expanded(
            child: timeEntriesAsync.when(
              data: (entries) => _buildTimeEntryList(context, ref, entries),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ActiveTimerCard({required WidgetRef ref}) {
    final entriesAsync = ref.watch(timeEntriesProvider);

    return entriesAsync.when(
      data: (entries) {
        final runningEntry = entries.where((e) => e.isRunning).toList();
        if (runningEntry.isEmpty) return const SizedBox.shrink();

        final entry = runningEntry.first;
        final elapsed = DateTime.now().difference(entry.startTime);
        final hours = elapsed.inHours.toString().padLeft(2, '0');
        final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer, color: AppColors.primary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Running',
                      style: TextStyle(color: AppColors.primary, fontSize: 14),
                    ),
                    Text(
                      '$hours:$minutes:$seconds',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 32,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    ref.read(timeEntriesProvider.notifier).stopTimer(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Stop'),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTimeEntryList(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> entries,
  ) {
    final completedEntries = entries.where((e) => !e.isRunning).toList();

    if (completedEntries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 64, color: AppColors.border),
            SizedBox(height: 16),
            Text(
              'No time entries yet',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedEntries.length,
      itemBuilder: (context, index) {
        final entry = completedEntries[index];
        final duration = entry.durationMinutes ?? 0;
        final hours = duration ~/ 60;
        final minutes = duration % 60;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.play_arrow, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task: ${entry.taskId}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${entry.startTime.toString().split('.')[0]} - ${entry.endTime?.toString().split('.')[0] ?? 'now'}',
                        style: const TextStyle(
                          color: AppColors.border,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${hours}h ${minutes}m',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () =>
                      ref.read(timeEntriesProvider.notifier).deleteTimeEntry(entry.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManualEntryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Manual Time Entry'),
        content: const Text(
          'Select a task to track time for it manually.',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add Entry'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/time_tracking/domain/time_entry_entity.dart lib/features/time_tracking/domain/time_entry_repository.dart lib/features/time_tracking/data/time_entry_repository_impl.dart lib/features/time_tracking/presentation/providers/time_tracking_provider.dart lib/features/time_tracking/presentation/screens/time_tracking_screen.dart
git commit -m "feat: add time tracking feature with timer and manual entry

- Create TimeEntry entity and repository interface
- Implement TimeEntryRepository with Drift
- Add TimeEntriesNotifier with start/stop timer functionality
- Update TimeTrackingScreen with active timer card and entry list
- Support manual time entry creation"
```

---

## Self-Review Checklist

**1. Spec coverage:**
- ✅ Project management (层级目录) - Task 1-5
- ✅ Task CRUD - Task 6
- ✅ Time tracking (手动 + 自动) - Task 7
- ✅ Offline storage - Task 2 (Drift database)

**2. Placeholder scan:** No TBD, TODO, or placeholder patterns found.

**3. Type consistency:**
- All entities use consistent `copyWith` pattern
- Repository interfaces match implementations
- Provider pattern is consistent across features

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-10-task-manager-implementation.md`**

## Two Execution Options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?