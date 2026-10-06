# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal task and time management Flutter app. **Local-first**: all data
lives in a Drift/SQLite database plus a few SharedPreferences caches.
**Optional WebDAV backup** (configurable server URL + Basic-auth) keeps
a single snapshot file (`snapshot.json`) that the app can push to or
pull-merge from on demand or on a 5-minute timer.

## Commands

```bash
# Install dependencies (required before first run or after pubspec changes)
flutter pub get

# Run on device/emulator
flutter run

# Run a single test file
flutter test test/unit/snapshot_merge_test.dart

# Run all tests
flutter test

# Analyze code (lib/ only)
flutter analyze lib/

# Build for a specific platform
flutter build apk --debug
flutter build apk --release
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

## Architecture

```
lib/
├── core/              # Shared: theme, constants, exceptions, logger
├── data/              # Repository implementations + Drift database + RemoteDatasource (Noop stub)
│   ├── datasources/
│   │   ├── local/app_database.dart  # Drift schema (projects, tasks, time_entries)
│   │   └── remote/                  # NoopRemote + buildRemoteDatasource() shim
│   └── sync/                       # NEW: WebDAV sync pipeline
│       ├── snapshot.dart           # SyncSnapshot wire shape
│       ├── snapshot_codec.dart     # Drift/SharedPrefs ↔ JSON
│       ├── sync_engine.dart        # push / pull / merge orchestration
│       ├── sync_status.dart        # SyncReport / SyncPhase / SyncDirection
│       └── webdav/
│           ├── webdav_client.dart
│           ├── webdav_credentials.dart
│           └── webdav_exceptions.dart
├── domain/            # Entities + repository interfaces
└── features/         # Feature modules (auth, calendar, dashboard, journal, mood, projects, settings, special_days, sync, tasks, time_tracking)
    └── [feature]/
        ├── domain/       # Feature entities
        ├── data/         # Feature repository implementations
        └── presentation/ # Screens, providers, widgets
```

**State management:** Riverpod (StreamNotifierProvider, StateNotifierProvider)

**Database:** Drift (SQLite) with generated type-safe queries in `lib/data/datasources/local/app_database.g.dart`. Soft-delete is supported via `deleted_at` columns on `projects` and `tasks`.

**Auth:** Local-only. AppLock (PIN + biometric, PBKDF2-HMAC-SHA256 with random salt in `flutter_secure_storage`) gates the app on launch; user-facing nickname/avatar is optional cosmetic data stored in SharedPreferences. There is **no server-side account**.

**Sync:** Optional WebDAV. `SyncEngine` exports a JSON snapshot, uploads it via Basic-auth PUT to `<baseUrl><remotePath>/snapshot.json`. Pull downloads, three-way merges (last-write-wins on `updated_at`; tombstone priority; tie → local), applies to the local DB, then re-uploads the merged result so both sides converge. The default interval is 5 minutes.

**Providers:** Located in `presentation/` directories under each feature (e.g., `features/auth/presentation/providers/`). The global `syncEngineProvider` lives in `features/sync/presentation/providers/sync_status_provider.dart`.

## Backend

There is **no backend**. The app connects to a user-configured WebDAV
server (any standard-compliant provider — Nextcloud, Apache mod_dav,
Synology, etc.) only when the user supplies a URL + username +
password in **Settings → Sync (WebDAV)**. The default remote path is
`/task_manager`, and credentials are kept locally:

- `webdav_base_url` / `webdav_username` / `webdav_remote_path` →
  SharedPreferences (plain text)
- `webdav_password` → `flutter_secure_storage`

No fields are baked into the source; nothing on the server is shared
between installs.

## Version

Version is defined in `lib/version.dart` (`appVersion`). This is the single source of truth — used by pubspec.yaml and CI.

## macOS Specifics

- `macos/Runner/Release.entitlements` includes `com.apple.security.network.client` — required for WebDAV connectivity
- Close button minimizes to Dock (`AppDelegate.applicationShouldTerminateAfterLastWindowClosed = false`)
- To rebuild after entitlement changes: `flutter build macos --release`

## Known Issues

- Run `flutter analyze lib/` to check lib/ code quality
- **The `webdav_client` Dart package disables dio's default status-code
  validation** (`WdDio.options.validateStatus = (s) => true`). `WebDavClientWrapper`
  inspects every response itself and throws `WebDavAuthException`,
  `WebDavNotFoundException`, or `WebDavNetworkException` as appropriate.
