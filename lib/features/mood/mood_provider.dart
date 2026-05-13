import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mood_service.dart';

final moodServiceProvider = Provider<MoodService>((ref) => MoodService());

final allMoodsProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  final service = ref.watch(moodServiceProvider);
  return service.getAllMoods();
});

final weeklyMoodDistributionProvider = FutureProvider<Map<String, int>>((ref) async {
  final service = ref.watch(moodServiceProvider);
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 6));
  return service.getDistribution(DateTime(weekStart.year, weekStart.month, weekStart.day),
      DateTime(weekEnd.year, weekEnd.month, weekEnd.day));
});
