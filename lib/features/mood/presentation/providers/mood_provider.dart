import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/datasources/remote/remote_datasource.dart';
import '../../../sync/presentation/providers/sync_status_provider.dart';
import '../../data/mood_repository_impl.dart';
import '../../domain/mood_repository.dart';

final moodRepositoryProvider = Provider<MoodRepository>((ref) {
  return MoodRepositoryImpl();
});

final allMoodsProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  return ref.watch(moodRepositoryProvider).getAll();
});

/// Convenience provider — distribution of moods in the next 7 days.
final weeklyMoodDistributionProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final now = DateTime.now();
  return ref.watch(moodRepositoryProvider).getDistribution(
        now.subtract(const Duration(days: 7)),
        now,
      );
});

final moodActionsProvider = Provider<MoodActions>((ref) => MoodActions(ref));

class MoodActions {
  MoodActions(this._ref);
  final Ref _ref;

  RemoteDatasource? get _remote => _ref.read(remoteDatasourceProvider);

  Future<void> setMoods(String dateKey, List<String> emojis) async {
    final r = _remote;
    if (r == null) return;
    await _ref.read(moodRepositoryProvider).setMoods(r, dateKey, emojis);
    _ref.invalidate(allMoodsProvider);
  }

  Future<void> removeMoods(String dateKey) async {
    final r = _remote;
    if (r == null) return;
    await _ref.read(moodRepositoryProvider).removeMoods(r, dateKey);
    _ref.invalidate(allMoodsProvider);
  }
}