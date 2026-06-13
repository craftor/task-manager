import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/datasources/remote/remote_datasource.dart';
import '../../../sync/presentation/providers/sync_status_provider.dart';
import '../../data/journal_repository_impl.dart';
import '../../domain/journal_entry.dart';
import '../../domain/journal_repository.dart';

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepositoryImpl();
});

/// Date keys with at least one entry, sorted descending.
final journalDatesProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(journalRepositoryProvider).getAllDates();
});

/// All entries for a given date key.
final journalEntriesProvider =
    FutureProvider.family<List<JournalEntry>, String>((ref, dateKey) async {
  return ref.watch(journalRepositoryProvider).getEntries(dateKey);
});

/// Mutations (add/delete) require a [RemoteDatasource]. The provider
/// returns `null` when no user is signed in; callers must guard.
final journalActionsProvider = Provider<JournalActions>((ref) {
  return JournalActions(ref);
});

class JournalActions {
  JournalActions(this._ref);
  final Ref _ref;

  RemoteDatasource? get _remoteNullable => _ref.read(remoteDatasourceProvider);

  Future<JournalEntry> add(String dateKey, String content) async {
    final remote = _remoteNullable;
    if (remote == null) {
      throw StateError('Cannot add journal entry without an authenticated user.');
    }
    return _ref
        .read(journalRepositoryProvider)
        .addEntry(remote, dateKey, content);
  }

  Future<void> delete(String dateKey, String entryId) async {
    final remote = _remoteNullable;
    if (remote == null) return;
    await _ref
        .read(journalRepositoryProvider)
        .deleteEntry(remote, dateKey, entryId);
  }

  Future<void> refresh() async {
    _ref.invalidate(journalDatesProvider);
    _ref.invalidate(journalEntriesProvider);
  }
}