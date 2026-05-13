import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported mood emojis
const moodEmojis = ['😊', '😢', '😡', '😴', '😐', '🎉', '😰', '❤️'];

const moodLabels = {
  '😊': 'Happy',
  '😢': 'Sad',
  '😡': 'Angry',
  '😴': 'Tired',
  '😐': 'Neutral',
  '🎉': 'Excited',
  '😰': 'Anxious',
  '❤️': 'Loved',
};

class MoodService {
  static const String _key = 'moods_data';

  /// Get all moods as Map<dateString, emoji>
  Future<Map<String, String>> getAllMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  /// Set mood for a specific date (yyyy-MM-dd)
  Future<void> setMood(String dateKey, String emoji) async {
    final moods = await getAllMoods();
    moods[dateKey] = emoji;
    await _save(moods);
  }

  /// Remove mood for a specific date
  Future<void> removeMood(String dateKey) async {
    final moods = await getAllMoods();
    moods.remove(dateKey);
    await _save(moods);
  }

  /// Get mood for a specific date, or null
  Future<String?> getMood(String dateKey) async {
    final moods = await getAllMoods();
    return moods[dateKey];
  }

  /// Get mood distribution within a date range
  Future<Map<String, int>> getDistribution(DateTime start, DateTime end) async {
    final moods = await getAllMoods();
    final dist = <String, int>{};
    for (final entry in moods.entries) {
      final d = DateTime.tryParse(entry.key);
      if (d != null && !d.isBefore(start) && !d.isAfter(end)) {
        dist[entry.value] = (dist[entry.value] ?? 0) + 1;
      }
    }
    return dist;
  }

  /// Get all moods for a month (yyyy-MM)
  Future<Map<String, String>> getMonthMoods(String yearMonth) async {
    final moods = await getAllMoods();
    return Map.fromEntries(
      moods.entries.where((e) => e.key.startsWith(yearMonth)),
    );
  }

  Future<void> _save(Map<String, String> moods) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(moods));
  }
}
