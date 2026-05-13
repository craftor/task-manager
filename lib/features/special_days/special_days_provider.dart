import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'special_days_service.dart';

final specialDaysServiceProvider = Provider<SpecialDaysService>((ref) => SpecialDaysService());

final specialDaysProvider = FutureProvider<Set<String>>((ref) async {
  final service = ref.watch(specialDaysServiceProvider);
  return service.getSpecialDays();
});

final specialDaysSortedProvider = FutureProvider<List<DateTime>>((ref) async {
  final service = ref.watch(specialDaysServiceProvider);
  return service.getSortedDates();
});
