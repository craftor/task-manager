import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/logger.dart';
import '../../../data/datasources/remote/remote_datasource.dart';

const moodEmojis = ['😊', '😢', '😡', '😴', '😐', '🎉', '😰', '❤️'];
const moodLabels = {
  '😊': 'Happy', '😢': 'Sad', '😡': 'Angry', '😴': 'Tired',
  '😐': 'Neutral', '🎉': 'Excited', '😰': 'Anxious', '❤️': 'Loved',
};

class MoodService {
  static const String _cacheKey = 'moods_cache';
  static const int _maxRetries = 3;
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get all moods from local cache
  Future<Map<String, List<String>>> getAllMoods() async {
    return _loadFromCache();
  }

  /// Get moods for a date
  Future<List<String>> getMoods(String dateKey) async {
    final all = await _loadFromCache();
    return all[dateKey] ?? [];
  }

  /// Set moods for a date. Writes to local cache immediately, then syncs to remote with retry.
  Future<void> setMoods(RemoteDatasource remote, String dateKey, List<String> emojis) async {
    final all = await _loadFromCache();
    if (emojis.isEmpty) {
      all.remove(dateKey);
    } else {
      all[dateKey] = emojis.take(3).toList();
    }
    await _saveCache(all);

    // Sync to remote with retry
    if (emojis.isEmpty) {
      _syncWithRetry(() => remote.deleteMood(dateKey));
    } else {
      _syncWithRetry(() => remote.upsertMood(dateKey, json.encode(emojis.take(3).toList())));
    }
  }

  /// Remove all moods for a date
  Future<void> removeMoods(RemoteDatasource remote, String dateKey) async {
    final all = await _loadFromCache();
    all.remove(dateKey);
    await _saveCache(all);

    _syncWithRetry(() => remote.deleteMood(dateKey));
  }

  /// Get mood distribution within a date range (from cache)
  Future<Map<String, int>> getDistribution(DateTime start, DateTime end) async {
    final moods = await _loadFromCache();
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

  // ── Cache helpers ──

  Future<Map<String, List<String>>> _loadFromCache() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) {
        if (v is List) return MapEntry(k, List<String>.from(v.map((e) => e.toString())));
        return MapEntry(k, [v.toString()]);
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveCache(Map<String, List<String>> data) async {
    final prefs = await _preferences;
    await prefs.setString(_cacheKey, json.encode(data));
  }

  /// Retry helper with exponential backoff for remote sync operations
  Future<void> _syncWithRetry(Future<void> Function() operation) async {
    var attempt = 0;
    while (attempt < _maxRetries) {
      try {
        await operation();
        return;
      } catch (e) {
        attempt++;
        if (attempt >= _maxRetries) {
          Logger.e('MoodService: remote sync failed after $_maxRetries attempts', error: e);
        } else {
          await Future.delayed(Duration(seconds: attempt * 2)); // exponential backoff
        }
      }
    }
  }

  /// Called by SyncManager to merge remote data into cache
  static Future<void> mergeRemoteData(List<Map<String, dynamic>> rows) async {
    final prefs = await _preferences;
    final map = <String, List<String>>{};
    for (final row in rows) {
      final key = row['date_key'] as String?;
      final dataStr = row['data'] as String?;
      if (key != null && dataStr != null) {
        try {
          final list = (json.decode(dataStr) as List).map((e) => e.toString()).toList();
          map[key] = list;
        } catch (_) {}
      }
    }
    await prefs.setString(_cacheKey, json.encode(map));
    Logger.d('MoodService: merged ${map.length} moods from remote');
  }
}