import '../../../core/utils/logger.dart';

/// Retry an async operation with exponential backoff. Logs at error level
/// after [maxRetries] attempts. Used by journal/mood/special_days services
/// to absorb transient network failures on first-write.
Future<void> retryWithBackoff(
  Future<void> Function() operation, {
  String label = 'remote sync',
  int maxRetries = 3,
  Duration baseDelay = const Duration(milliseconds: 500),
}) async {
  var attempt = 0;
  while (attempt < maxRetries) {
    try {
      await operation();
      return;
    } catch (e, st) {
      attempt++;
      if (attempt >= maxRetries) {
        Logger.e('$label: remote sync failed after $maxRetries attempts',
            error: e, stackTrace: st);
      } else {
        await Future<void>.delayed(baseDelay * (1 << (attempt - 1)));
      }
    }
  }
}