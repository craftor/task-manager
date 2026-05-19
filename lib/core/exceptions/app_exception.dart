/// Base exception type for the application.
/// All app-specific exceptions should extend this class.
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Database-related exceptions (local SQLite operations)
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Sync-related exceptions (remote operations, network issues)
class SyncException extends AppException {
  final bool canRetry;

  const SyncException({
    required super.message,
    super.code,
    super.originalError,
    this.canRetry = true,
  });
}

/// Validation errors (invalid input, business rule violations)
class ValidationException extends AppException {
  final String? field;

  const ValidationException({
    required super.message,
    super.code,
    super.originalError,
    this.field,
  });
}

/// Authentication/authorization errors
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
  });
}