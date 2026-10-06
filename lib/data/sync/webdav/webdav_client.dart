/// Thin wrapper around `webdav_client` for the snapshot workflow.
///
/// Responsibilities:
///   * Construct an authenticated client from [WebDavCredentials].
///   * Provide a single `snapshot.json` upload/download API.
///   * Translate dio's permissive status-code handling into typed
///     [WebDavException]s.
///
/// The underlying `webdav_client` `read/write` methods take a single
/// "remote path" argument (relative to the WebDAV root, not the
/// server's base URL). The package builds the absolute URL by
/// concatenating `Client.uri + remote_path`, so we pre-combine the
/// configured base URL + remote directory + filename into one path
/// string and pass it through.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart';

import 'webdav_credentials.dart';
import 'webdav_exceptions.dart';

/// File name of the snapshot on the WebDAV server.
const String kSnapshotFileName = 'snapshot.json';

class WebDavClientWrapper {
  WebDavClientWrapper(this._creds);

  final WebDavCredentials _creds;

  /// Remote path passed to `webdav_client`'s read/write methods. It is
  /// the path *under* the configured WebDAV root, NOT a full URL.
  String _remotePath() {
    final path = _creds.remotePath.startsWith('/')
        ? _creds.remotePath
        : '/${_creds.remotePath}';
    return '$path/$kSnapshotFileName';
  }

  /// Absolute WebDAV root URL (used as `Client.uri`).
  String _baseUri() {
    return _creds.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// Build a fresh `webdav_client` Client. The package disables dio's
  /// default status validation, so the returned client never throws on
  /// non-2xx — callers must inspect responses / status codes themselves.
  Client _build() {
    final dio = WdDio(
      options: BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    return Client(
      uri: _baseUri(),
      c: dio,
      auth: BasicAuth(user: _creds.username, pwd: _creds.password),
    );
  }

  /// Map arbitrary exceptions to typed WebDAV exceptions.
  WebDavException _translate(Object e, {int? statusCode}) {
    if (e is WebDavException) return e;
    if (e is DioException) {
      final inner = e.error;
      if (inner is SocketException ||
          inner is HandshakeException ||
          inner is HttpException) {
        return WebDavNetworkException(inner.toString(), cause: e);
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return WebDavNetworkException(
          'Connection timed out (${e.type.name})',
          cause: e,
        );
      }
      return WebDavNetworkException(e.message ?? 'Network error', cause: e);
    }
    return WebDavException(e.toString(), statusCode: statusCode, cause: e);
  }

  /// Verify credentials by attempting to ping the root.
  /// Returns `true` on success. Throws [WebDavAuthException] on 401/403,
  /// [WebDavNetworkException] on transport errors.
  Future<bool> testConnection() async {
    final client = _build();
    try {
      await client.ping();
      return true;
    } on Object catch (e) {
      throw _translate(e);
    }
  }

  /// Make sure the configured [WebDavCredentials.remotePath] directory
  /// exists. Idempotent.
  Future<void> ensureAppDir() async {
    final client = _build();
    try {
      final path = _creds.remotePath.startsWith('/')
          ? _creds.remotePath
          : '/${_creds.remotePath}';
      try {
        await client.mkdirAll(path);
        return;
      } on Object catch (e) {
        // mkdirAll may throw when the directory already exists. Treat
        // a 405 (Method Not Allowed) as success.
        if (e is WebDavException && e.statusCode == 405) return;
        // Fall back to a single-level mkdir.
        try {
          await client.mkdir(path);
          return;
        } on Object catch (e2) {
          if (e2 is WebDavException && e2.statusCode == 405) return;
          rethrow;
        }
      }
    } on Object catch (e) {
      throw _translate(e);
    }
  }

  /// Download the remote snapshot. Returns `null` if it does not yet
  /// exist (HTTP 404). Throws [WebDavAuthException] on 401/403 and
  /// [WebDavNetworkException] on transport errors.
  Future<Uint8List?> downloadSnapshot() async {
    final client = _build();
    try {
      final bytes = await client.read(_remotePath());
      if (bytes.isEmpty) return Uint8List(0);
      return Uint8List.fromList(bytes);
    } on Object catch (e) {
      // webdav_client throws plain Exceptions with status codes
      // embedded in the message string; sniff for 404/401/403 there
      // as a last resort.
      if (e is WebDavException) {
        final s = e.statusCode;
        if (s == 404) return null;
        if (s == 401 || s == 403) {
          throw WebDavAuthException(
            'Authentication failed (HTTP $s). Check username and password.',
            statusCode: s,
          );
        }
        if (s != null && s >= 400 && s < 500) {
          throw WebDavException(e.message, statusCode: s, cause: e);
        }
        throw _translate(e, statusCode: s);
      }
      final msg = e.toString();
      if (msg.contains('404') || msg.contains('Not Found')) {
        return null;
      }
      if (msg.contains('401') || msg.contains('403')) {
        throw WebDavAuthException(
          'Authentication failed. Check username and password.',
        );
      }
      throw _translate(e);
    }
  }

  /// Upload [bytes] as the new snapshot. Overwrites any existing file.
  Future<void> uploadSnapshot(Uint8List bytes) async {
    final client = _build();
    try {
      await ensureAppDir();
      await client.write(_remotePath(), bytes);
    } on Object catch (e) {
      if (e is WebDavException) rethrow;
      throw _translate(e);
    }
  }
}
