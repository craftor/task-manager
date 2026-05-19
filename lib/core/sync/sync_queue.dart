import 'dart:async';
import '../../domain/entities/task.dart' as entity;
import '../../domain/entities/project.dart' as entity_project;

enum SyncOperationType {
  taskUpsert,
  taskDelete,
  projectUpsert,
  projectDelete,
}

class SyncOperation {
  final String id;
  final SyncOperationType type;
  final Map<String, dynamic> payload;
  final int retryCount;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;

  const SyncOperation({
    required this.id,
    required this.type,
    required this.payload,
    this.retryCount = 0,
    required this.createdAt,
    this.lastAttemptAt,
  });

  SyncOperation copyWith({
    String? id,
    SyncOperationType? type,
    Map<String, dynamic>? payload,
    int? retryCount,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  DateTime get nextRetryAt {
    // Exponential backoff: 1s, 2s, 4s, 8s (max 3 retries, so 4 attempts total)
    return createdAt.add(Duration(seconds: (1 << retryCount)));
  }
}

typedef SyncExecutor = Future<void> Function(SyncOperation op);

class SyncQueue {
  static const int maxRetries = 3;

  final List<SyncOperation> _queue = [];
  final StreamController<List<SyncOperation>> _queueController =
      StreamController.broadcast();
  final StreamController<SyncOperation> _processController =
      StreamController.broadcast();
  Timer? _retryTimer;
  bool _isProcessing = false;
  SyncExecutor? _executor;

  Stream<List<SyncOperation>> get queueStream => _queueController.stream;
  Stream<SyncOperation> get processStream => _processController.stream;
  int get pendingCount => _queue.length;

  void setExecutor(SyncExecutor executor) {
    _executor = executor;
  }

  void add(SyncOperation op) {
    _queue.add(op);
    _queueController.add(_queue);
    _scheduleRetryIfNeeded();
  }

  void addTaskUpsert(entity.Task task) {
    add(SyncOperation(
      id: task.id,
      type: SyncOperationType.taskUpsert,
      payload: {'task': task},
      createdAt: DateTime.now(),
    ));
  }

  void addTaskDelete(entity.Task task) {
    add(SyncOperation(
      id: task.id,
      type: SyncOperationType.taskDelete,
      payload: {'task': task},
      createdAt: DateTime.now(),
    ));
  }

  void addProjectUpsert(entity_project.Project project) {
    add(SyncOperation(
      id: project.id,
      type: SyncOperationType.projectUpsert,
      payload: {'project': project},
      createdAt: DateTime.now(),
    ));
  }

  void addProjectDelete(entity_project.Project project) {
    add(SyncOperation(
      id: project.id,
      type: SyncOperationType.projectDelete,
      payload: {'project': project},
      createdAt: DateTime.now(),
    ));
  }

  void _scheduleRetryIfNeeded() {
    if (_isProcessing || _queue.isEmpty) return;

    final now = DateTime.now();
    final nextOp = _queue.first;

    // If we can retry now
    if (nextOp.retryCount > 0 && nextOp.nextRetryAt.isBefore(now)) {
      _processNext();
      return;
    }

    // Schedule for next retry time
    _retryTimer?.cancel();
    final delay = nextOp.retryCount == 0
        ? Duration.zero
        : nextOp.nextRetryAt.difference(now);
    _retryTimer = Timer(delay > Duration.zero ? delay : const Duration(milliseconds: 100), _processNext);
  }

  Future<void> _processNext() async {
    if (_isProcessing || _queue.isEmpty || _executor == null) return;
    _isProcessing = true;

    final op = _queue.first;
    _processController.add(op);

    try {
      await _executor!(op);
      // Success - remove from queue
      _queue.removeAt(0);
      _queueController.add(_queue);
    } catch (e) {
      if (op.retryCount < maxRetries) {
        // Retry - update retry count and move to back
        final updated = op.copyWith(
          retryCount: op.retryCount + 1,
          lastAttemptAt: DateTime.now(),
        );
        _queue[0] = updated;
        _queue.add(_queue.removeAt(0)); // Move to back
        _queueController.add(_queue);
      } else {
        // Max retries exceeded - remove and log
        _queue.removeAt(0);
        _queueController.add(_queue);
      }
    }

    _isProcessing = false;
    if (_queue.isNotEmpty) {
      _scheduleRetryIfNeeded();
    }
  }

  /// Force process all pending operations immediately
  Future<void> flush() async {
    while (_queue.isNotEmpty && !_isProcessing) {
      await _processNext();
    }
  }

  /// Clear all pending operations
  void clear() {
    _queue.clear();
    _retryTimer?.cancel();
    _queueController.add(_queue);
  }

  void dispose() {
    _retryTimer?.cancel();
    _queueController.close();
    _processController.close();
  }
}