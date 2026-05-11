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
