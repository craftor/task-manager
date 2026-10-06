/// WebDAV connection settings, stored locally (URL/username via
/// SharedPreferences; password via flutter_secure_storage).
///
/// The remote WebDAV server is expected to expose a single user-writable
/// folder (e.g. `/dav/task_manager/`) where we put `snapshot.json`.
library;

import 'package:flutter/foundation.dart';

@immutable
class WebDavCredentials {
  const WebDavCredentials({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.remotePath = '/task_manager',
  });

  /// Base URL of the WebDAV server, e.g. `https://dav.example.com`.
  /// Must NOT include a trailing slash.
  final String baseUrl;

  /// Basic-auth username (often the email on hosted WebDAV providers).
  final String username;

  final String password;

  /// Folder under [baseUrl] where the snapshot lives.
  /// Defaults to `/task_manager`.
  final String remotePath;

  /// `true` when all fields are non-empty and the URL is plausible.
  bool get isValid {
    final u = baseUrl.trim();
    if (u.isEmpty || username.isEmpty || password.isEmpty) return false;
    final parsed = Uri.tryParse(u);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return false;
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') return false;
    return true;
  }

  WebDavCredentials copyWith({
    String? baseUrl,
    String? username,
    String? password,
    String? remotePath,
  }) {
    return WebDavCredentials(
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remotePath: remotePath ?? this.remotePath,
    );
  }

  Map<String, String> toMap() => {
        'baseUrl': baseUrl,
        'username': username,
        // Password intentionally omitted — kept in secure storage.
        'remotePath': remotePath,
      };

  static WebDavCredentials fromMap(Map<String, String?> m) {
    return WebDavCredentials(
      baseUrl: m['baseUrl'] ?? '',
      username: m['username'] ?? '',
      password: m['password'] ?? '',
      remotePath: m['remotePath'] ?? '/task_manager',
    );
  }
}
