/// State of the WebDAV sync pipeline.
///
/// Mirrors the old `SyncState` enum used by [SyncManager]; the engine
/// reports one of these to the UI via a `StateNotifier`.
library;

enum SyncPhase {
  idle,
  pulling,
  pushing,
  conflict,
  error,
}

class SyncReport {
  const SyncReport({
    required this.phase,
    this.lastSuccessAt,
    this.lastError,
    this.lastDirection,
    this.recordsPulled = 0,
    this.recordsPushed = 0,
  });

  final SyncPhase phase;

  /// When the last fully successful sync (push or pull) finished.
  final DateTime? lastSuccessAt;

  /// Last error message (cleared on next successful operation).
  final String? lastError;

  /// What the last operation was. Useful for the UI to say
  /// "Last pushed 3 records 2 minutes ago".
  final SyncDirection? lastDirection;

  final int recordsPulled;
  final int recordsPushed;

  static const idle = SyncReport(phase: SyncPhase.idle);

  SyncReport copyWith({
    SyncPhase? phase,
    DateTime? lastSuccessAt,
    String? lastError,
    bool clearError = false,
    SyncDirection? lastDirection,
    int? recordsPulled,
    int? recordsPushed,
  }) {
    return SyncReport(
      phase: phase ?? this.phase,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastDirection: lastDirection ?? this.lastDirection,
      recordsPulled: recordsPulled ?? this.recordsPulled,
      recordsPushed: recordsPushed ?? this.recordsPushed,
    );
  }
}

enum SyncDirection { push, pull }
