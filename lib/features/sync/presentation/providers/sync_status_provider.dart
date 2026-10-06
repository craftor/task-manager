/// Sync providers — exposes the [SyncEngine] plus the [SyncReport]
/// stream and the WebDAV credentials notifier.
///
/// Replaces the previous Appwrite `SyncManager` provider. The
/// `userIdProvider` shim is kept so downstream code (now using
/// `NoopRemote`) still compiles.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/database_provider.dart';
import '../../../../data/datasources/remote/remote_datasource.dart';
import '../../../../data/sync/snapshot_codec.dart';
import '../../../../data/sync/sync_engine.dart';
import '../../../../data/sync/sync_status.dart';
import '../../../../data/sync/webdav/webdav_client.dart';
import '../../../../data/sync/webdav/webdav_credentials.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Stable per-install identifier. Always "local" — used wherever a
/// previous Appwrite user_id was expected.
final userIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).userId ?? 'local';
});

/// Always a no-op now. Kept so the rest of the codebase that reads
/// `ref.watch(remoteDatasourceProvider)` still compiles.
final remoteDatasourceProvider = Provider<RemoteDatasource?>((ref) {
  ref.watch(userIdProvider);
  return buildRemoteDatasource();
});

/// SharedPreferences-backed [WebDavCredentials] provider. Returns the
/// currently-stored credentials (which may be invalid / empty if the
/// user hasn't set anything up yet).
final webdavCredentialsProvider =
    NotifierProvider<WebDavCredentialsNotifier, WebDavCredentials>(
  WebDavCredentialsNotifier.new,
);

class WebDavCredentialsNotifier extends Notifier<WebDavCredentials> {
  static const _kBaseUrl = 'webdav_base_url';
  static const _kUsername = 'webdav_username';
  static const _kRemotePath = 'webdav_remote_path';

  @override
  WebDavCredentials build() {
    _load();
    return const WebDavCredentials(
      baseUrl: '',
      username: '',
      password: '',
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = WebDavCredentials(
      baseUrl: prefs.getString(_kBaseUrl) ?? '',
      username: prefs.getString(_kUsername) ?? '',
      password: '', // password is stored in flutter_secure_storage
      remotePath: prefs.getString(_kRemotePath) ?? '/task_manager',
    );
    // Re-fetch the password from secure storage if it exists.
    final pwd = await _readSecurePassword();
    if (pwd != null && pwd.isNotEmpty) {
      state = state.copyWith(password: pwd);
    }
  }

  Future<String?> _readSecurePassword() async {
    try {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      return storage.read(key: 'webdav_password');
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSecurePassword(String value) async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    if (value.isEmpty) {
      await storage.delete(key: 'webdav_password');
    } else {
      await storage.write(key: 'webdav_password', value: value);
    }
  }

  Future<void> save(WebDavCredentials creds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, creds.baseUrl);
    await prefs.setString(_kUsername, creds.username);
    await prefs.setString(_kRemotePath, creds.remotePath);
    await _writeSecurePassword(creds.password);
    state = creds;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBaseUrl);
    await prefs.remove(_kUsername);
    await prefs.remove(_kRemotePath);
    await _writeSecurePassword('');
    state = const WebDavCredentials(
      baseUrl: '',
      username: '',
      password: '',
    );
  }
}

/// The [SyncEngine] singleton. Built lazily on first access and
/// disposed when the provider container is torn down.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final codec = SnapshotCodec(db);
  final credsNotifier = ref.watch(webdavCredentialsProvider.notifier);

  final engine = SyncEngine(
    codec: codec,
    clientFactory: WebDavClientWrapper.new,
  );

  // Whenever credentials change, push them into the engine.
  ref.listen<WebDavCredentials>(webdavCredentialsProvider, (prev, next) {
    engine.updateCredentials(next);
    if (next.isValid) {
      engine.startPeriodic();
    } else {
      engine.stopPeriodic();
    }
  }, fireImmediately: true);

  // Try a startup pull if we have valid creds; failure is non-fatal.
  Future<void>(() async {
    final initialCreds = ref.read(webdavCredentialsProvider);
    if (initialCreds.isValid) {
      engine.updateCredentials(initialCreds);
      await engine.runStartupPullIfConfigured();
      engine.startPeriodic();
    }
  });

  ref.onDispose(engine.dispose);
  // Touch credsNotifier so it isn't tree-shaken — we depend on its
  // state changes to drive the engine above.
  credsNotifier.toString();

  return engine;
});

/// Stream of [SyncReport]s from the engine.
final syncStatusProvider = StreamProvider<SyncReport>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.report;
});
