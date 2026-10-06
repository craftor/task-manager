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
  final DateTime? startDate;
  final DateTime? dueDate;
  final List<String> tags;
  final int? estimatedMinutes;
  final int? actualMinutes;
  final bool isRecurring;
  final String? recurringRule;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder;

  const Task({
    required this.id,
    required this.projectId,
    this.parentTaskId,
    required this.title,
    this.description = '',
    this.priority = Priority.medium,
    this.status = TaskStatus.pending,
    this.startDate,
    this.dueDate,
    this.tags = const [],
    this.estimatedMinutes,
    this.actualMinutes,
    this.isRecurring = false,
    this.recurringRule,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  Task copyWith({
    String? id,
    String? projectId,
    String? parentTaskId,
    String? title,
    String? description,
    Priority? priority,
    TaskStatus? status,
    DateTime? startDate,
    DateTime? dueDate,
    List<String>? tags,
    int? estimatedMinutes,
    int? actualMinutes,
    bool? isRecurring,
    String? recurringRule,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
  }) {
    return Task(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      tags: tags ?? this.tags,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringRule: recurringRule ?? this.recurringRule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Serialize to the snake_case JSON shape used by the WebDAV snapshot
  /// and (historically) the Appwrite schema.
  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'parent_task_id': parentTaskId,
        'title': title,
        'description': description,
        'priority': priority.index,
        'status': status.index,
        'start_date': startDate?.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'tags': tags,
        'estimated_minutes': estimatedMinutes,
        'actual_minutes': actualMinutes,
        'is_recurring': isRecurring,
        'recurring_rule': recurringRule,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sort_order': sortOrder,
      };
}