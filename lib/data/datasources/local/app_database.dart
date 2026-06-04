import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/constants/app_constants.dart';

part 'app_database.g.dart';

// GENERATED CODE - DO NOT MODIFY BY HAND
// To regenerate: dart run build_runner build --delete-conflicting-outputs

class TagsConverter extends TypeConverter<List<String>, String> {
  const TagsConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    try {
      return List<String>.from(json.decode(fromDb));
    } catch (e) {
      debugPrint('TagsConverter.fromSql: failed to decode JSON "$fromDb" — $e');
      return fromDb.isNotEmpty ? fromDb.split(',') : [];
    }
  }

  @override
  String toSql(List<String> value) {
    return json.encode(value);
  }
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get color => text()();
  TextColumn get icon => text()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get parentTaskId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get priority => integer().withDefault(const Constant(2))();
  IntColumn get status => integer().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get tags => text().map(const TagsConverter()).withDefault(const Constant('[]'))();
  IntColumn get estimatedMinutes => integer().nullable()();
  IntColumn get actualMinutes => integer().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurringRule => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class TimeEntries extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get manual => boolean().withDefault(const Constant(false))();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Projects, Tasks, TimeEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await customStatement('ALTER TABLE tasks ADD COLUMN start_date INTEGER');
        }
        if (from < 3) {
          await customStatement('ALTER TABLE projects ADD COLUMN description TEXT');
          await customStatement('ALTER TABLE projects ADD COLUMN start_date INTEGER');
          await customStatement('ALTER TABLE projects ADD COLUMN end_date INTEGER');
        }
        if (from < 4) {
          await customStatement('ALTER TABLE projects ADD COLUMN is_default INTEGER DEFAULT 0');
        }
        if (from < 5) {
          await customStatement('ALTER TABLE projects ADD COLUMN sort_order INTEGER DEFAULT 0');
          await customStatement('ALTER TABLE tasks ADD COLUMN sort_order INTEGER DEFAULT 0');
        }
      },
    );
  }

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

  // Sync-related queries
  Future<List<Project>> getPendingProjects() =>
      (select(projects)..where((p) => p.pendingSync.equals(true))).get();
  Future<void> markProjectSynced(String id) async {
    await (update(projects)..where((p) => p.id.equals(id)))
        .write(const ProjectsCompanion(pendingSync: Value(false)));
  }

  Future<void> upsertProjectFromRemote(Map<String, dynamic> data) async {
    await into(projects).insertOnConflictUpdate(ProjectsCompanion(
      id: Value(data['id'] as String),
      parentId: Value(data['parent_id'] as String?),
      name: Value(data['name'] as String),
      description: Value(data['description'] as String?),
      color: Value(data['color'] as String),
      icon: Value(data['icon'] as String),
      startDate: Value(data['start_date'] != null ? DateTime.parse(data['start_date'] as String) : null),
      endDate: Value(data['end_date'] != null ? DateTime.parse(data['end_date'] as String) : null),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      sortOrder: Value(data['sort_order'] as int? ?? 0),
      isDefault: Value(data['is_default'] as bool? ?? false),
      pendingSync: const Value(false),
    ));
  }

  // Task queries
  Future<List<Task>> getAllTasks() => select(tasks).get();
  Stream<List<Task>> watchAllTasks() => select(tasks).watch();
  Future<Task?> getTaskById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<List<Task>> getTasksByProject(String projectId) =>
      (select(tasks)..where((t) => t.projectId.equals(projectId))).get();
  Future<int> insertTask(TasksCompanion task) => into(tasks).insert(task);
  Future<int> updateTask(TasksCompanion task) =>
      (update(tasks)..where((t) => t.id.equals(task.id.value))).write(task);
  Future<int> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  // Sync-related task queries
  Future<List<Task>> getPendingTasks() =>
      (select(tasks)..where((t) => t.pendingSync.equals(true))).get();
  Future<void> markTaskSynced(String id) async {
    await (update(tasks)..where((t) => t.id.equals(id)))
        .write(const TasksCompanion(pendingSync: Value(false)));
  }

  Future<void> upsertTaskFromRemote(Map<String, dynamic> data) async {
    await into(tasks).insertOnConflictUpdate(TasksCompanion(
      id: Value(data['id'] as String),
      projectId: Value(data['project_id'] as String),
      parentTaskId: Value(data['parent_task_id'] as String?),
      title: Value(data['title'] as String),
      description: Value(data['description'] as String? ?? ''),
      priority: Value(data['priority'] as int? ?? 2),
      status: Value(data['status'] as int? ?? 0),
      startDate: Value(data['start_date'] != null ? DateTime.parse(data['start_date'] as String) : null),
      dueDate: Value(data['due_date'] != null ? DateTime.parse(data['due_date'] as String) : null),
      tags: Value((data['tags'] as String?)?.split(',') ?? []),
      estimatedMinutes: Value(data['estimated_minutes'] as int?),
      actualMinutes: Value(data['actual_minutes'] as int?),
      isRecurring: Value(data['is_recurring'] as bool? ?? false),
      recurringRule: Value(data['recurring_rule'] as String?),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(data['updated_at'] != null ? DateTime.parse(data['updated_at'] as String) : DateTime.now()),
      sortOrder: Value(data['sort_order'] as int? ?? 0),
      pendingSync: const Value(false),
    ));
  }

  // Time entry queries
  Future<List<TimeEntry>> getAllTimeEntries() => select(timeEntries).get();
  Stream<List<TimeEntry>> watchAllTimeEntries() => select(timeEntries).watch();
  Future<TimeEntry?> getTimeEntryById(String id) =>
      (select(timeEntries)..where((e) => e.id.equals(id))).getSingleOrNull();
  Future<List<TimeEntry>> getTimeEntriesByTask(String taskId) =>
      (select(timeEntries)..where((e) => e.taskId.equals(taskId))).get();
  Future<int> insertTimeEntry(TimeEntriesCompanion entry) =>
      into(timeEntries).insert(entry);
  Future<bool> updateTimeEntry(TimeEntriesCompanion entry) =>
      update(timeEntries).replace(entry);
  Future<int> deleteTimeEntry(String id) =>
      (delete(timeEntries)..where((e) => e.id.equals(id))).go();

  // Sync-related time entry queries
  Future<List<TimeEntry>> getPendingTimeEntries() =>
      (select(timeEntries)..where((e) => e.pendingSync.equals(true))).get();
  Future<void> markTimeEntrySynced(String id) async {
    await (update(timeEntries)..where((e) => e.id.equals(id)))
        .write(const TimeEntriesCompanion(pendingSync: Value(false)));
  }

  // Parametrized delete to replace customStatement SQL
  Future<void> deleteProjectById(String id) async {
    await (delete(projects)..where((p) => p.id.equals(id))).go();
  }

  Future<void> deleteTaskById(String id) async {
    await (delete(tasks)..where((t) => t.id.equals(id))).go();
  }

  Future<void> upsertTimeEntryFromRemote(Map<String, dynamic> data) async {
    await into(timeEntries).insertOnConflictUpdate(TimeEntriesCompanion(
      id: Value(data['id'] as String),
      taskId: Value(data['task_id'] as String),
      startTime: Value(DateTime.parse(data['start_time'] as String)),
      endTime: Value(data['end_time'] != null ? DateTime.parse(data['end_time'] as String) : null),
      durationMinutes: Value(data['duration_minutes'] as int?),
      note: Value(data['note'] as String? ?? ''),
      manual: Value(data['manual'] as bool? ?? false),
      pendingSync: const Value(false),
    ));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConstants.dbName));
    return NativeDatabase.createInBackground(file);
  });
}