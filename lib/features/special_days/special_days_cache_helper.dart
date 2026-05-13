import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to merge remote special days data into SharedPreferences cache.
/// Used by both SyncManager (pull) and SpecialDaysService (local access).
class SpecialDaysCacheHelper {
  static const String _cacheKey = 'special_days_cache';

  /// Replace local cache entirely with remote data.
  /// This ensures deletions on other devices are reflected.
  static Future<void> mergeRemoteData(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> cache = {};

    for (final row in rows) {
      final key = row['date_key'] as String?;
      final dataStr = row['data'] as String?;
      if (key != null && dataStr != null) {
        try {
          cache[key] = json.decode(dataStr);
        } catch (_) {
          cache[key] = {'color': '0'};
        }
      }
    }

    await prefs.setString(_cacheKey, json.encode(cache));
  }
}
