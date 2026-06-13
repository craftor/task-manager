import 'dart:convert';

import '../../../core/utils/json_cache_store.dart';
import '../../../core/utils/logger.dart';
import '../../../data/datasources/remote/remote_datasource.dart';
import '../domain/special_days_repository.dart';

class SpecialDaysRepositoryImpl implements SpecialDaysRepository {
  SpecialDaysRepositoryImpl() : _store = JsonCacheStore(_cacheKey);

  static const String _cacheKey = 'special_days_cache';
  final JsonCacheStore _store;

  @override
  Future<Map<String, Map<String, String>>> getAll(
    RemoteDatasource? remote,
  ) async {
    final cached = await _loadCache();
    if (cached.isEmpty && remote != null) {
      await pullFromRemote(remote);
      return _loadCache();
    }
    return cached;
  }

  @override
  Future<Map<String, String>?> getDay(String dateKey) async {
    final all = await _loadCache();
    return all[dateKey];
  }

  @override
  Future<void> setDay(
    RemoteDatasource remote,
    String dateKey,
    int colorIndex,
    String? desc,
  ) async {
    final data = <String, String>{'color': colorIndex.toString()};
    if (desc != null && desc.isNotEmpty) data['desc'] = desc;
    final dataJson = json.encode(data);

    final all = await _loadCache();
    all[dateKey] = data;
    await _saveCache(all);

    remote.upsertSpecialDay(dateKey, dataJson).catchError((e) {
      Logger.d('SpecialDaysRepository.setDay: remote write failed - $e');
    });
  }

  @override
  Future<void> removeDay(RemoteDatasource remote, String dateKey) async {
    final all = await _loadCache();
    all.remove(dateKey);
    await _saveCache(all);

    remote.deleteSpecialDay(dateKey).catchError((e) {
      Logger.d('SpecialDaysRepository.removeDay: remote delete failed - $e');
    });
  }

  @override
  Future<List<DateTime>> getSortedDates() async {
    final all = await _loadCache();
    final dates = all.keys
        .map((d) => DateTime.tryParse(d))
        .whereType<DateTime>()
        .toList();
    dates.sort();
    return dates;
  }

  @override
  Future<void> pullFromRemote(RemoteDatasource remote) async {
    try {
      final rows = await remote.fetchSpecialDays();
      final map = <String, Map<String, String>>{};
      for (final row in rows) {
        final key = row['date_key'] as String?;
        final dataStr = row['data'] as String?;
        if (key == null || dataStr == null) continue;
        try {
          final data = json.decode(dataStr) as Map<String, dynamic>;
          map[key] = data.map((k, v) => MapEntry(k, v.toString()));
        } catch (_) {
          map[key] = {'color': '0'};
        }
      }
      await _saveCache(map);
    } catch (e) {
      Logger.e('SpecialDaysRepository.pullFromRemote failed', error: e);
    }
  }

  Future<Map<String, Map<String, String>>> _loadCache() async {
    final raw = await _store.readJson();
    if (raw is! Map) return {};
    return raw.map((k, v) {
      final inner = v as Map<String, dynamic>?;
      if (inner == null) return MapEntry(k, <String, String>{});
      return MapEntry(
        k as String,
        inner.map((ik, iv) => MapEntry(ik, iv.toString())),
      );
    });
  }

  Future<void> _saveCache(Map<String, Map<String, String>> data) =>
      _store.writeJson(data);
}