import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/logger.dart';
import '../../../data/datasources/remote/remote_datasource.dart';

/// Colors for the 6 special day categories
const specialDayColors = [
  0xFFE91E63, // pink
  0xFFFF5722, // orange
  0xFF4CAF50, // green
  0xFF2196F3, // blue
  0xFFFF9800, // amber
  0xFF9C27B0, // purple
];

class SpecialDaysService {
  static const String _cacheKey = 'special_days_cache';
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get all special days from SharedPreferences (always fresh).
  /// Falls back to remote if cache is empty.
  Future<Map<String, Map<String, String>>> getAll(RemoteDatasource? remote) async {
    final cached = await _loadFromCache();

    if (cached.isEmpty && remote != null) {
      await _pullFromRemote(remote);
      return await _loadFromCache();
    }

    return cached;
  }

  /// Get data for a specific date
  Future<Map<String, String>?> getDay(String dateKey) async {
    final all = await _loadFromCache();
    return all[dateKey];
  }

  /// Mark a day as special. Writes to remote + cache.
  Future<void> setDay(RemoteDatasource remote, String dateKey, int colorIndex, String? desc) async {
    // Build data map
    final data = <String, String>{'color': colorIndex.toString()};
    if (desc != null && desc.isNotEmpty) data['desc'] = desc;
    final dataJson = json.encode(data);

    // Update local SharedPreferences FIRST so UI updates immediately
    final all = await _loadFromCache();
    all[dateKey] = data;
    await _saveCache(all);

    // Write to remote (fire-and-forget for responsiveness)
    remote.upsertSpecialDay(dateKey, dataJson).catchError((e) {
      Logger.d('SpecialDaysService.setDay: remote write failed - $e');
    });
  }

  /// Remove a special day. Deletes from remote + cache.
  Future<void> removeDay(RemoteDatasource remote, String dateKey) async {
    // Update local SharedPreferences FIRST
    final all = await _loadFromCache();
    all.remove(dateKey);
    await _saveCache(all);

    // Delete from remote (fire-and-forget)
    remote.deleteSpecialDay(dateKey).catchError((e) {
      Logger.d('SpecialDaysService.removeDay: remote delete failed - $e');
    });
  }

  /// Pull all special days from remote and merge into SharedPreferences.
  Future<void> pullFromRemote(RemoteDatasource remote) async {
    await _pullFromRemote(remote);
  }

  /// Get sorted list of special dates from cache
  Future<List<DateTime>> getSortedDates() async {
    final all = await _loadFromCache();
    final dates = all.keys
        .map((d) => DateTime.tryParse(d))
        .whereType<DateTime>()
        .toList();
    dates.sort();
    return dates;
  }

  // ── Private ──

  Future<Map<String, Map<String, String>>> _loadFromCache() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) {
        final inner = v as Map<String, dynamic>?;
        if (inner == null) return MapEntry(k, <String, String>{});
        return MapEntry(k, inner.map((ik, iv) => MapEntry(ik, iv.toString())));
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveCache(Map<String, Map<String, String>> data) async {
    final prefs = await _preferences;
    await prefs.setString(_cacheKey, json.encode(data));
  }

  Future<void> _pullFromRemote(RemoteDatasource remote) async {
    try {
      final rows = await remote.fetchSpecialDays();
      final map = <String, Map<String, String>>{};
      for (final row in rows) {
        final key = row['date_key'] as String?;
        final dataStr = row['data'] as String?;
        if (key != null && dataStr != null) {
          try {
            final data = json.decode(dataStr) as Map<String, dynamic>;
            map[key] = data.map((k, v) => MapEntry(k, v.toString()));
          } catch (_) {
            map[key] = {'color': '0'};
          }
        }
      }
      await _saveCache(map);
      Logger.d('SpecialDaysService: pulled ${map.length} special days from remote');
    } catch (e) {
      Logger.d('SpecialDaysService.pullFromRemote: failed - $e');
    }
  }
}
