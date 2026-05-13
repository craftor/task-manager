import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mood_service.dart';

final moodServiceProvider = Provider<MoodService>((ref) => MoodService());

final allMoodsProvider = FutureProvider<Map<String, String>>((ref) async {
  final service = ref.watch(moodServiceProvider);
  return service.getAllMoods();
});

/// Get mood distribution for current week (Mon–Sun)
final weeklyMoodDistributionProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final service = ref.watch(moodServiceProvider);
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final sunday = monday.add(const Duration(days: 6));
  return service.getDistribution(
    DateTime(monday.year, monday.month, monday.day),
    DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59),
  );
});
