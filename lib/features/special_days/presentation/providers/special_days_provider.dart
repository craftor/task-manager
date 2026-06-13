import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/datasources/remote/remote_datasource.dart';
import '../../../sync/presentation/providers/sync_status_provider.dart';
import '../../data/special_days_repository_impl.dart';
import '../../domain/special_days_repository.dart';

final specialDaysRepositoryProvider = Provider<SpecialDaysRepository>((ref) {
  return SpecialDaysRepositoryImpl();
});

final specialDaysProvider =
    FutureProvider<Map<String, Map<String, String>>>((ref) async {
  final remote = ref.watch(remoteDatasourceProvider);
  return ref.watch(specialDaysRepositoryProvider).getAll(remote);
});

/// Sorted ascending list of dates that have a special day entry.
final specialDaysSortedProvider =
    FutureProvider<List<DateTime>>((ref) async {
  return ref.watch(specialDaysRepositoryProvider).getSortedDates();
});

final specialDaysActionsProvider =
    Provider<SpecialDaysActions>((ref) => SpecialDaysActions(ref));

class SpecialDaysActions {
  SpecialDaysActions(this._ref);
  final Ref _ref;

  RemoteDatasource? get _remote => _ref.read(remoteDatasourceProvider);

  Future<void> setDay(String dateKey, int colorIndex, String? desc) async {
    final r = _remote;
    if (r == null) return;
    await _ref
        .read(specialDaysRepositoryProvider)
        .setDay(r, dateKey, colorIndex, desc);
    _ref.invalidate(specialDaysProvider);
  }

  Future<void> removeDay(String dateKey) async {
    final r = _remote;
    if (r == null) return;
    await _ref.read(specialDaysRepositoryProvider).removeDay(r, dateKey);
    _ref.invalidate(specialDaysProvider);
  }
}