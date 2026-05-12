import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GanttViewMode { project, personal }

enum GanttZoom { week, month, quarter, year }

class GanttState {
  final GanttViewMode viewMode;
  final GanttZoom zoom;
  final DateTime startDate;
  final DateTime endDate;

  GanttState({
    this.viewMode = GanttViewMode.project,
    this.zoom = GanttZoom.month,
    required this.startDate,
    required this.endDate,
  });
}

class GanttNotifier extends StateNotifier<GanttState> {
  GanttNotifier()
      : super(_buildState(GanttZoom.month));

  static GanttState _buildState(GanttZoom zoom) {
    final now = DateTime.now();
    late DateTime start;
    switch (zoom) {
      case GanttZoom.week:
        start = now.subtract(const Duration(days: 3));
        return GanttState(
          zoom: zoom,
          startDate: start,
          endDate: start.add(const Duration(days: 7)),
        );
      case GanttZoom.month:
        start = now.subtract(const Duration(days: 7));
        return GanttState(
          zoom: zoom,
          startDate: start,
          endDate: start.add(const Duration(days: 30)),
        );
      case GanttZoom.quarter:
        start = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
        return GanttState(
          zoom: zoom,
          startDate: start,
          endDate: DateTime(start.year, start.month + 3, 0),
        );
      case GanttZoom.year:
        return GanttState(
          zoom: zoom,
          startDate: DateTime(now.year, 1, 1),
          endDate: DateTime(now.year, 12, 31),
        );
    }
  }

  void setViewMode(GanttViewMode mode) {
    state = GanttState(
      viewMode: mode,
      zoom: state.zoom,
      startDate: state.startDate,
      endDate: state.endDate,
    );
  }

  void setZoom(GanttZoom zoom) {
    state = _buildState(zoom);
  }

  void setTimeRange(DateTime start, DateTime end) {
    state = GanttState(
      viewMode: state.viewMode,
      zoom: state.zoom,
      startDate: start,
      endDate: end,
    );
  }
}

final ganttProvider = StateNotifierProvider<GanttNotifier, GanttState>((ref) {
  return GanttNotifier();
});
