import '../../../data/datasources/remote/remote_datasource.dart';
import 'journal_entry.dart';

/// Persistence boundary for journal entries. Mutating methods take a
/// [RemoteDatasource] because writes fan-out to both the local cache
/// and the remote collection.
abstract class JournalRepository {
  /// All entries for [dateKey], newest first.
  Future<List<JournalEntry>> getEntries(String dateKey);

  /// Every date key that currently has entries, sorted descending.
  Future<List<String>> getAllDates();

  /// Persist a new entry to cache and queue a remote upsert with retry.
  Future<JournalEntry> addEntry(
    RemoteDatasource remote,
    String dateKey,
    String content,
  );

  /// Remove an entry from cache and queue a remote delete with retry.
  Future<void> deleteEntry(
    RemoteDatasource remote,
    String dateKey,
    String entryId,
  );

  /// Replace the local cache with whatever [remote] currently holds.
  /// Used by SyncManager after a successful pull.
  Future<void> pullFromRemote(RemoteDatasource remote);
}