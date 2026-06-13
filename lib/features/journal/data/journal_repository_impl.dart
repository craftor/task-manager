import 'package:uuid/uuid.dart';

import '../../../core/utils/json_cache_store.dart';
import '../../../core/utils/retry_with_backoff.dart';
import '../../../data/datasources/remote/remote_datasource.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_repository.dart';

/// SharedPreferences-backed implementation of [JournalRepository]. The
/// remote handle is injected per call (rather than stored in the
/// repository) so [SyncManager] can pass a [RemoteDatasource] without
/// owning repo construction.
class JournalRepositoryImpl implements JournalRepository {
  JournalRepositoryImpl() : _store = JsonCacheStore(_cacheKey);

  static const String _cacheKey = 'journal_cache';
  final JsonCacheStore _store;

  @override
  Future<List<JournalEntry>> getEntries(String dateKey) async {
    final all = await _loadCache();
    return all[dateKey] ?? const [];
  }

  @override
  Future<List<String>> getAllDates() async {
    final all = await _loadCache();
    final dates = all.keys.toList()..sort((a, b) => b.compareTo(a));
    return dates;
  }

  @override
  Future<JournalEntry> addEntry(
    RemoteDatasource remote,
    String dateKey,
    String content,
  ) async {
    final entry = JournalEntry(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      content: content.trim(),
    );
    final all = await _loadCache();
    all.putIfAbsent(dateKey, () => []).insert(0, entry);
    await _saveCache(all);

    retryWithBackoff(
      () => remote.upsertJournalEntry(dateKey, entry.toJson()),
      label: 'JournalRepository.addEntry',
    );
    return entry;
  }

  @override
  Future<void> deleteEntry(
    RemoteDatasource remote,
    String dateKey,
    String entryId,
  ) async {
    final all = await _loadCache();
    all[dateKey]?.removeWhere((e) => e.id == entryId);
    if (all[dateKey]?.isEmpty == true) all.remove(dateKey);
    await _saveCache(all);

    retryWithBackoff(
      () => remote.deleteJournalEntry(entryId),
      label: 'JournalRepository.deleteEntry',
    );
  }

  @override
  Future<void> pullFromRemote(RemoteDatasource remote) async {
    try {
      final rows = await remote.fetchJournalEntries();
      final map = <String, List<JournalEntry>>{};
      for (final row in rows) {
        final key = row['date_key'] as String?;
        if (key == null) continue;
        try {
          map.putIfAbsent(key, () => []).add(JournalEntry.fromJson(row));
        } catch (_) {
          // Skip malformed rows rather than poison the whole cache.
        }
      }
      await _saveCache(map);
    } catch (_) {
      // Network failures bubble via SyncState.error upstream; cache
      // stays untouched so the user keeps their last-known-good view.
    }
  }

  Future<Map<String, List<JournalEntry>>> _loadCache() async {
    final raw = await _store.readJson();
    if (raw is! Map) return {};
    return raw.map((k, v) {
      final list = (v as List).cast<dynamic>();
      return MapEntry(
        k as String,
        list.map((e) => JournalEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );
    });
  }

  Future<void> _saveCache(Map<String, List<JournalEntry>> data) async {
    final encoded = data.map(
      (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
    );
    await _store.writeJson(encoded);
  }
}