import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/datasources/local/app_database.dart';

class ImportExportService {
  final AppDatabase _db;

  ImportExportService(this._db);

  /// Export all data to a JSON string
  Future<String> exportToJson() async {
    final projects = await _db.getAllProjects();
    final tasks = await _db.getAllTasks();
    final timeEntries = await _db.getAllTimeEntries();

    final specialDays = await _loadSpecialDays();
    final moods = await _loadMoods();
    final journal = await _loadJournal();

    final data = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'projects': projects.map((p) => {
        'id': p.id,
        'parentId': p.parentId,
        'name': p.name,
        'description': p.description,
        'color': p.color,
        'icon': p.icon,
        'startDate': p.startDate?.toIso8601String(),
        'endDate': p.endDate?.toIso8601String(),
        'createdAt': p.createdAt.toIso8601String(),
        'isDefault': p.isDefault,
        'sortOrder': p.sortOrder,
      }).toList(),
      'tasks': tasks.map((t) => {
        'id': t.id,
        'projectId': t.projectId,
        'parentTaskId': t.parentTaskId,
        'title': t.title,
        'description': t.description,
        'priority': t.priority,
        'status': t.status,
        'startDate': t.startDate?.toIso8601String(),
        'dueDate': t.dueDate?.toIso8601String(),
        'tags': t.tags,
        'estimatedMinutes': t.estimatedMinutes,
        'actualMinutes': t.actualMinutes,
        'isRecurring': t.isRecurring,
        'recurringRule': t.recurringRule,
        'createdAt': t.createdAt.toIso8601String(),
        'updatedAt': t.updatedAt.toIso8601String(),
        'sortOrder': t.sortOrder,
      }).toList(),
      'timeEntries': timeEntries.map((e) => {
        'id': e.id,
        'taskId': e.taskId,
        'startTime': e.startTime.toIso8601String(),
        'endTime': e.endTime?.toIso8601String(),
        'durationMinutes': e.durationMinutes,
        'note': e.note,
        'manual': e.manual,
      }).toList(),
      'specialDays': specialDays,
      'moods': moods,
      'journal': journal,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Save export to a temp file and share it
  Future<void> shareExport() async {
    final json = await exportToJson();
    final dir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/task_manager_export_$timestamp.json');
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Task Manager Export',
      ),
    );
  }

  /// Pick a JSON file and import data from it
  Future<ImportResult> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult(success: false, message: 'No file selected');
    }

    final file = File(result.files.first.path!);
    final json = await file.readAsString();

    return importFromJson(json);
  }

  /// Import data from a JSON string
  Future<ImportResult> importFromJson(String json) async {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;

      // Validate version
      final version = data['version'] as String?;
      if (version == null) {
        return ImportResult(success: false, message: 'Invalid export file: missing version');
      }

      int importedProjects = 0;
      int importedTasks = 0;
      int importedTimeEntries = 0;

      // Import projects
      final projects = data['projects'] as List<dynamic>? ?? [];
      for (final p in projects) {
        final map = p as Map<String, dynamic>;
        try {
          await _db.insertProject(ProjectsCompanion(
            id: Value(map['id'] as String),
            parentId: Value(map['parentId'] as String?),
            name: Value(map['name'] as String),
            description: Value(map['description'] as String? ?? ''),
            color: Value(map['color'] as String),
            icon: Value(map['icon'] as String),
            startDate: Value(map['startDate'] != null ? DateTime.parse(map['startDate'] as String) : null),
            endDate: Value(map['endDate'] != null ? DateTime.parse(map['endDate'] as String) : null),
            createdAt: Value(DateTime.parse(map['createdAt'] as String)),
            isDefault: Value(map['isDefault'] as bool? ?? false),
            sortOrder: Value(map['sortOrder'] as int? ?? 0),
            pendingSync: const Value(true),
          ));
          importedProjects++;
        } catch (_) {}
      }

      // Import tasks
      final tasks = data['tasks'] as List<dynamic>? ?? [];
      for (final t in tasks) {
        final map = t as Map<String, dynamic>;
        try {
          await _db.insertTask(TasksCompanion(
            id: Value(map['id'] as String),
            projectId: Value(map['projectId'] as String),
            parentTaskId: Value(map['parentTaskId'] as String?),
            title: Value(map['title'] as String),
            description: Value(map['description'] as String? ?? ''),
            priority: Value(map['priority'] as int? ?? 2),
            status: Value(map['status'] as int? ?? 0),
            startDate: Value(map['startDate'] != null ? DateTime.parse(map['startDate'] as String) : null),
            dueDate: Value(map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null),
            tags: Value(List<String>.from(map['tags'] ?? [])),
            estimatedMinutes: Value(map['estimatedMinutes'] as int?),
            actualMinutes: Value(map['actualMinutes'] as int?),
            isRecurring: Value(map['isRecurring'] as bool? ?? false),
            recurringRule: Value(map['recurringRule'] as String?),
            createdAt: Value(DateTime.parse(map['createdAt'] as String)),
            updatedAt: Value(map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : DateTime.now()),
            sortOrder: Value(map['sortOrder'] as int? ?? 0),
            pendingSync: const Value(true),
          ));
          importedTasks++;
        } catch (_) {}
      }

      // Import time entries
      final timeEntries = data['timeEntries'] as List<dynamic>? ?? [];
      for (final e in timeEntries) {
        final map = e as Map<String, dynamic>;
        try {
          await _db.insertTimeEntry(TimeEntriesCompanion(
            id: Value(map['id'] as String),
            taskId: Value(map['taskId'] as String),
            startTime: Value(DateTime.parse(map['startTime'] as String)),
            endTime: Value(map['endTime'] != null ? DateTime.parse(map['endTime'] as String) : null),
            durationMinutes: Value(map['durationMinutes'] as int?),
            note: Value(map['note'] as String? ?? ''),
            manual: Value(map['manual'] as bool? ?? false),
            pendingSync: const Value(true),
          ));
          importedTimeEntries++;
        } catch (_) {}
      }

      return ImportResult(
        success: true,
        message: 'Imported $importedProjects projects, $importedTasks tasks, $importedTimeEntries time entries',
        projectsCount: importedProjects,
        tasksCount: importedTasks,
        timeEntriesCount: importedTimeEntries,
      );
    } catch (e) {
      return ImportResult(success: false, message: 'Import failed: $e');
    }
  }

  Future<Map<String, dynamic>> _loadSpecialDays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('special_days_cache');
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _loadMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('moods_cache');
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _loadJournal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('journal_cache');
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded;
    } catch (_) {
      return {};
    }
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int projectsCount;
  final int tasksCount;
  final int timeEntriesCount;

  ImportResult({
    required this.success,
    required this.message,
    this.projectsCount = 0,
    this.tasksCount = 0,
    this.timeEntriesCount = 0,
  });
}
