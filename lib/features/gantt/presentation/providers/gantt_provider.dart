import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GanttViewMode { project, personal }

class GanttState {
  final GanttViewMode viewMode;
  final DateTime startDate;
  final DateTime endDate;

  GanttState({
    this.viewMode = GanttViewMode.project,
    required this.startDate,
    required this.endDate,
  });
}

class GanttNotifier extends StateNotifier<GanttState> {
  GanttNotifier()
      : super(GanttState(
          startDate: DateTime.now().subtract(const Duration(days: 7)),
          endDate: DateTime.now().add(const Duration(days: 30)),
        ));

  void setViewMode(GanttViewMode mode) {
    state = GanttState(
      viewMode: mode,
      startDate: state.startDate,
      endDate: state.endDate,
    );
  }

  void setTimeRange(DateTime start, DateTime end) {
    state = GanttState(
      viewMode: state.viewMode,
      startDate: start,
      endDate: end,
    );
  }
}

final ganttProvider = StateNotifierProvider<GanttNotifier, GanttState>((ref) {
  return GanttNotifier();
});