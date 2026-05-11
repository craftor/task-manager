import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CalendarDisplayMode { marker, timeBlock }

class CalendarState {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarDisplayMode displayMode;

  CalendarState({
    required this.focusedDay,
    required this.selectedDay,
    this.displayMode = CalendarDisplayMode.marker,
  });
}

class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier()
      : super(CalendarState(
          focusedDay: DateTime.now(),
          selectedDay: DateTime.now(),
        ));

  void setFocusedDay(DateTime day) {
    state = CalendarState(
      focusedDay: day,
      selectedDay: state.selectedDay,
      displayMode: state.displayMode,
    );
  }

  void setSelectedDay(DateTime day) {
    state = CalendarState(
      focusedDay: state.focusedDay,
      selectedDay: day,
      displayMode: state.displayMode,
    );
  }

  void toggleDisplayMode() {
    state = CalendarState(
      focusedDay: state.focusedDay,
      selectedDay: state.selectedDay,
      displayMode: state.displayMode == CalendarDisplayMode.marker
          ? CalendarDisplayMode.timeBlock
          : CalendarDisplayMode.marker,
    );
  }
}

final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier();
});