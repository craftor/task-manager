/// SyncEngine — orchestrates the push/pull of a [SyncSnapshot] over
/// WebDAV.
///
/// Workflow (single-device by default; multi-device can be enabled by
/// the optional periodic timer):
///
///   push:
///     1. export local snapshot
///     2. upload to remote
///   pull:
///     1. download remote snapshot (null → no-op, treat as empty)
///     2. export local snapshot
///     3. merge(local, remote) via [SnapshotCodec.merge]
///     4. applyMerged() to local DB
///     5. upload the merged snapshot back to remote (so the "winning"
///        side is now consistent on both ends)
///
/// All public methods report progress through a [SyncReport] stream
/// consumed by Riverpod providers.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'snapshot.dart';
import 'snapshot_codec.dart';
import 'sync_status.dart';
import 'webdav/webdav_client.dart';
import 'webdav/webdav_credentials.dart';
import 'webdav/webdav_exceptions.dart';

class SyncEngine {
  SyncEngine({
    required SnapshotCodec codec,
    required WebDavClientWrapper Function(WebDavCredentials) clientFactory,
  })  : _codec = codec,
        _clientFactory = clientFactory;

  final SnapshotCodec _codec;
  final WebDavClientWrapper Function(WebDavCredentials) _clientFactory;

  WebDavCredentials? _creds;
  Timer? _periodicTimer;
  bool _isRunning = false;

  final _reportController = StreamController<SyncReport>.broadcast();
  SyncReport _last = SyncReport.idle;
  Stream<SyncReport> get report => _reportController.stream;
  SyncReport get currentReport => _last;

  void _emit(SyncReport r) {
    _last = r;
    _reportController.add(r);
  }

  /// Install new credentials. Cancels any pending periodic timer;
  /// caller is expected to call [startPeriodic] if auto-sync is on.
  void updateCredentials(WebDavCredentials creds) {
    _creds = creds;
    stopPeriodic();
  }

  WebDavCredentials? get credentials => _creds;

  WebDavClientWrapper? _ensureClient() {
    final c = _creds;
    if (c == null || !c.isValid) return null;
    return _clientFactory(c);
  }

  /// Verify credentials without touching local data. Used by the
  /// "Test connection" button on the settings screen.
  Future<bool> testConnection() async {
    final client = _ensureClient();
    if (client == null) {
      throw WebDavException('WebDAV credentials are not configured.');
    }
    return client.testConnection();
  }

  /// Upload the current local state to the remote. Returns the number
  /// of records written. No-op if credentials are missing.
  Future<int> push() async {
    if (_isRunning) {
      throw WebDavException('A sync operation is already in progress.');
    }
    final client = _ensureClient();
    if (client == null) {
      throw WebDavException('WebDAV credentials are not configured.');
    }
    _isRunning = true;
    _emit(_last.copyWith(
      phase: SyncPhase.pushing,
      clearError: true,
    ));
    try {
      final snap = await _codec.exportSnapshot();
      final json = SnapshotCodec.encodeToJson(snap);
      await client.uploadSnapshot(Uint8List.fromList(json.codeUnits));
      final now = DateTime.now();
      _emit(_last.copyWith(
        phase: SyncPhase.idle,
        lastSuccessAt: now,
        lastDirection: SyncDirection.push,
        recordsPushed: snap.projects.length +
            snap.tasks.length +
            snap.timeEntries.length,
      ));
      return snap.projects.length + snap.tasks.length + snap.timeEntries.length;
    } on WebDavException catch (e) {
      _emit(_last.copyWith(phase: SyncPhase.error, lastError: e.toString()));
      rethrow;
    } catch (e) {
      _emit(_last.copyWith(
        phase: SyncPhase.error,
        lastError: e.toString(),
      ));
      rethrow;
    } finally {
      _isRunning = false;
    }
  }

  /// Download the remote snapshot, merge with local, and write the
  /// merged result both to the local DB and back to the remote.
  ///
  /// Returns the number of remote rows that survived the merge (i.e.
  /// the count of remote-side winning records, approximated).
  Future<int> pull() async {
    if (_isRunning) {
      throw WebDavException('A sync operation is already in progress.');
    }
    final client = _ensureClient();
    if (client == null) {
      throw WebDavException('WebDAV credentials are not configured.');
    }
    _isRunning = true;
    _emit(_last.copyWith(
      phase: SyncPhase.pulling,
      clearError: true,
    ));
    try {
      final bytes = await client.downloadSnapshot();
      final local = await _codec.exportSnapshot();
      if (bytes == null || bytes.isEmpty) {
        // No remote snapshot yet — just push local as the seed.
        final json = SnapshotCodec.encodeToJson(local);
        await client.uploadSnapshot(Uint8List.fromList(json.codeUnits));
        _emit(_last.copyWith(
          phase: SyncPhase.idle,
          lastSuccessAt: DateTime.now(),
          lastDirection: SyncDirection.push,
          recordsPushed: local.projects.length +
              local.tasks.length +
              local.timeEntries.length,
        ));
        return 0;
      }
      final remote = SnapshotCodec.decodeFromJson(String.fromCharCodes(bytes));
      final merged = SnapshotCodec.merge(local, remote);
      await _codec.applyMerged(merged);

      // Re-upload the merged state so the remote converges.
      final out = SnapshotCodec.encodeToJson(merged);
      await client.uploadSnapshot(Uint8List.fromList(out.codeUnits));

      _emit(_last.copyWith(
        phase: SyncPhase.idle,
        lastSuccessAt: DateTime.now(),
        lastDirection: SyncDirection.pull,
        recordsPulled: remote.projects.length +
            remote.tasks.length +
            remote.timeEntries.length,
      ));
      return remote.projects.length + remote.tasks.length + remote.timeEntries.length;
    } on WebDavException catch (e) {
      _emit(_last.copyWith(phase: SyncPhase.error, lastError: e.toString()));
      rethrow;
    } catch (e, st) {
      debugPrint('[SyncEngine.pull] $e\n$st');
      _emit(_last.copyWith(
        phase: SyncPhase.error,
        lastError: e.toString(),
      ));
      rethrow;
    } finally {
      _isRunning = false;
    }
  }

  /// Run a pull once at startup. Safe to call before credentials are
  /// configured — it just becomes a no-op.
  Future<void> runStartupPullIfConfigured() async {
    if (_creds == null || !_creds!.isValid) return;
    try {
      await pull();
    } catch (_) {
      // Errors already reported via SyncReport.
    }
  }

  /// Start a periodic auto-sync every [interval]. Any previous timer
  /// is cancelled first. No-op if credentials are not configured.
  void startPeriodic({Duration interval = const Duration(minutes: 5)}) {
    stopPeriodic();
    if (_creds == null || !_creds!.isValid) return;
    _periodicTimer = Timer.periodic(interval, (_) async {
      try {
        await pull();
      } catch (_) {
        // Already surfaced via SyncReport.
      }
    });
  }

  void stopPeriodic() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<void> dispose() async {
    stopPeriodic();
    await _reportController.close();
  }
}
