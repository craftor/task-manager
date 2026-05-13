import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const moodEmojis = ['😊', '😢', '😡', '😴', '😐', '🎉', '😰', '❤️'];
const moodLabels = {
  '😊': 'Happy', '😢': 'Sad', '😡': 'Angry', '😴': 'Tired',
  '😐': 'Neutral', '🎉': 'Excited', '😰': 'Anxious', '❤️': 'Loved',
};

class MoodService {
  static const String _key = 'moods_data';

  /// Get all moods as Map<dateString, List<emoji>>
  Future<Map<String, List<String>>> getAllMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) {
        if (v is List) return MapEntry(k, List<String>.from(v.map((e) => e.toString())));
        // Legacy: single string → list
        return MapEntry(k, [v.toString()]);
      });
    } catch (_) {
      return {};
    }
  }

  /// Get moods for a date, or empty list
  Future<List<String>> getMoods(String dateKey) async {
    final all = await getAllMoods();
    return all[dateKey] ?? [];
  }

  /// Add a mood emoji to a date (max 3)
  Future<void> addMood(String dateKey, String emoji) async {
    final all = await getAllMoods();
    final list = all.putIfAbsent(dateKey, () => []);
    if (!list.contains(emoji) && list.length < 3) {
      list.add(emoji);
    } else if (list.contains(emoji)) {
      list.remove(emoji); // Tap same emoji = remove
    }
    if (list.isEmpty) all.remove(dateKey);
    await _save(all);
  }

  /// Set exact mood list for a date (replace all)
  Future<void> setMoods(String dateKey, List<String> emojis) async {
    final all = await getAllMoods();
    if (emojis.isEmpty) {
      all.remove(dateKey);
    } else {
      all[dateKey] = emojis.take(3).toList();
    }
    await _save(all);
  }

  /// Remove all moods for a date
  Future<void> removeMoods(String dateKey) async {
    final all = await getAllMoods();
    all.remove(dateKey);
    await _save(all);
  }

  /// Get mood distribution within a date range
  Future<Map<String, int>> getDistribution(DateTime start, DateTime end) async {
    final moods = await getAllMoods();
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

  Future<void> _save(Map<String, List<String>> moods) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(moods));
  }
}
