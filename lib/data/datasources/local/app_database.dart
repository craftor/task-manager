import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/constants/app_constants.dart';

part 'app_database.g.dart';

class TagsConverter extends TypeConverter<List<String>, String> {
  const TagsConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    try {
      return List<String>.from(json.decode(fromDb));
    } catch (_) {
      return fromDb.split(',');
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
  TextColumn get color => text()();
  TextColumn get icon => text()();
  DateTimeColumn get createdAt => dateTime()();

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
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get tags => text().map(const TagsConverter()).withDefault(const Constant('[]'))();
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
  TextColumn get taskId => text().references(Tasks, #id, onDelete: KeyAction.cascade)();
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