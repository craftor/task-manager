import '../../../data/datasources/remote/remote_datasource.dart';

/// Colors for the 6 special-day categories. Exposed so the picker UI
/// stays in sync with the persisted color values.
const specialDayColors = [
  0xFFE91E63, // pink
  0xFFFF5722, // orange
  0xFF4CAF50, // green
  0xFF2196F3, // blue
  0xFFFF9800, // amber
  0xFF9C27B0, // purple
];

abstract class SpecialDaysRepository {
  Future<Map<String, Map<String, String>>> getAll(RemoteDatasource? remote);
  Future<Map<String, String>?> getDay(String dateKey);
  Future<void> setDay(
    RemoteDatasource remote,
    String dateKey,
    int colorIndex,
    String? desc,
  );
  Future<void> removeDay(RemoteDatasource remote, String dateKey);
  Future<List<DateTime>> getSortedDates();
  Future<void> pullFromRemote(RemoteDatasource remote);
}