import '../exceptions/app_exception.dart';

/// Lightweight result type used at the UI/mutation boundary. Mutation
/// methods return [Result] so the caller can render an error message
/// (via SnackBar) instead of letting exceptions propagate silently.
sealed class Result<T> {
  const Result();

  /// True when the operation succeeded.
  bool get isSuccess => this is Success<T>;

  /// True when the operation failed.
  bool get isFailure => this is Failure<T>;

  /// Returns the success value or `null` on failure.
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => null,
      };

  /// Returns the failure error or `null` on success.
  AppException? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(:final error) => error,
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppException error;
}