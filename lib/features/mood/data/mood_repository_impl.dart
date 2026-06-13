import 'dart:convert';

import '../../../core/utils/json_cache_store.dart';
import '../../../core/utils/retry_with_backoff.dart';
import '../../../data/datasources/remote/remote_datasource.dart';
import '../domain/mood_repository.dart';

class MoodRepositoryImpl implements MoodRepository {
  MoodRepositoryImpl() : _store = JsonCacheStore(_cacheKey);

  static const String _cacheKey = 'moods_cache';
  final JsonCacheStore _store;

  @override
  Future<Map<String, List<String>>> getAll() => _loadCache();

  @override
  Future<List<String>> getMoods(String dateKey) async {
    final all = await _loadCache();
    return all[dateKey] ?? const [];
  }

  @override
  Future<void> setMoods(
    RemoteDatasource remote,
    String dateKey,
    List<String> emojis,
  ) async {
    final all = await _loadCache();
    if (emojis.isEmpty) {
      all.remove(dateKey);
    } else {
      all[dateKey] = emojis.take(3).toList();
    }
    await _saveCache(all);

    if (emojis.isEmpty) {
      retryWithBackoff(
        () => remote.deleteMood(dateKey),
        label: 'MoodRepository.setMoods(delete)',
      );
    } else {
      retryWithBackoff(
        () => remote.upsertMood(dateKey, json.encode(emojis.take(3).toList())),
        label: 'MoodRepository.setMoods(upsert)',
      );
    }
  }

  @override
  Future<void> removeMoods(RemoteDatasource remote, String dateKey) async {
    final all = await _loadCache();
    all.remove(dateKey);
    await _saveCache(all);
    retryWithBackoff(
      () => remote.deleteMood(dateKey),
      label: 'MoodRepository.removeMoods',
    );
  }

  @override
  Future<Map<String, int>> getDistribution(DateTime start, DateTime end) async {
    final moods = await _loadCache();
    final dist = <String, int>{};
    for (final entry in moods.entries) {
      final d = DateTime.tryParse(entry.key);
      if (d != null && !d.isBefore(start) && !d.isAfter(end)) {
        for (final e in entry.value) {
          dist[e] = (dist[e] ?? 0) + 1;
        }
      }
    }
    return dist;
  }

  @override
  Future<void> pullFromRemote(RemoteDatasource remote) async {
    try {
      final rows = await remote.fetchMoods();
      final map = <String, List<String>>{};
      for (final row in rows) {
        final key = row['date_key'] as String?;
        final dataStr = row['data'] as String?;
        if (key == null || dataStr == null) continue;
        try {
          final list = (json.decode(dataStr) as List)
              .map((e) => e.toString())
              .toList();
          map[key] = list;
        } catch (_) {
          // Skip malformed rows.
        }
      }
      await _saveCache(map);
    } catch (_) {
      // Sync layer surfaces the failure; cache stays untouched.
    }
  }

  Future<Map<String, List<String>>> _loadCache() async {
    final raw = await _store.readJson();
    if (raw is! Map) return {};
    return raw.map((k, v) {
      final list = (v as List).cast<dynamic>();
      return MapEntry(
        k as String,
        list.map((e) => e.toString()).toList(),
      );
    });
  }

  Future<void> _saveCache(Map<String, List<String>> data) =>
      _store.writeJson(data);
}