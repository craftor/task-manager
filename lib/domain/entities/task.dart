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
    );
  }
}