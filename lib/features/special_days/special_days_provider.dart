import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sync/presentation/providers/sync_status_provider.dart' show remoteDatasourceProvider;
import 'special_days_service.dart';

final specialDaysServiceProvider = Provider<SpecialDaysService>((ref) => SpecialDaysService());

final specialDaysProvider = FutureProvider<Map<String, Map<String, String>>>((ref) async {
  final service = ref.watch(specialDaysServiceProvider);
  final remote = ref.watch(remoteDatasourceProvider);
  return service.getAll(remote);
});

final specialDaysSortedProvider = FutureProvider<List<DateTime>>((ref) async {
  final service = ref.watch(specialDaysServiceProvider);
  return service.getSortedDates();
});
