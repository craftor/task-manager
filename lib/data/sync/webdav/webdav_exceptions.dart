/// Exceptions thrown by the WebDAV client wrapper.
///
/// The underlying `webdav_client` package disables dio's default status-code
/// validation (see `WdDio.options.validateStatus = (s) => true`), so the
/// wrapper turns non-2xx responses into explicit exceptions that
/// [SyncEngine] can surface to the UI.
library;

class WebDavException implements Exception {
  WebDavException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    final s = statusCode == null ? '' : ' [HTTP $statusCode]';
    return 'WebDavException$s: $message';
  }
}

/// Authentication failed (HTTP 401/403). Treated as "wrong credentials".
class WebDavAuthException extends WebDavException {
  WebDavAuthException(super.message, {super.statusCode});

  @override
  String toString() => 'WebDavAuthException [HTTP $statusCode]: $message';
}

/// The remote resource is missing (HTTP 404). Used by download() to signal
/// "no snapshot yet" without throwing a generic failure.
class WebDavNotFoundException extends WebDavException {
  WebDavNotFoundException(String path)
      : super('Not found: $path', statusCode: 404);

  @override
  String toString() => 'WebDavNotFoundException: $message';
}

/// Network-level failure (DNS, connection refused, TLS, timeout, …).
/// These are always retryable and surface as AuthFailureKind.network.
class WebDavNetworkException extends WebDavException {
  WebDavNetworkException(super.message, {super.cause});

  @override
  String toString() => 'WebDavNetworkException: $message';
}
