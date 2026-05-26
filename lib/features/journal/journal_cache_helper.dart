import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class JournalCacheHelper {
  static const String _cacheKey = 'journal_cache';

  /// Replace local cache entirely with remote data.
  static Future<void> mergeRemoteData(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, List<Map<String, dynamic>>> cache = {};

    for (final row in rows) {
      final key = row['date_key'] as String?;
      if (key == null) continue;
      cache.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(row);
    }

    await prefs.setString(_cacheKey, json.encode(cache));
  }
}
