# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal task and time management Flutter app with Appwrite backend, built with Clean Architecture.

## Commands

```bash
# Install dependencies (required before first run or after pubspec changes)
flutter pub get

# Run on device/emulator
flutter run

# Run a single test file
flutter test test/unit/sync_manager_test.dart

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
├── core/              # Shared: theme, constants, exceptions, logger, appwrite client
├── data/              # Repository implementations + Drift database + RemoteDatasource (Appwrite impl)
├── domain/            # Entities + repository interfaces
└── features/         # Feature modules (auth, calendar, dashboard, journal, mood, projects, settings, special_days, sync, tasks, time_tracking)
    └── [feature]/
        ├── domain/       # Feature entities
        ├── data/         # Feature repository implementations
        └── presentation/ # Screens, providers, widgets
```

**State management:** Riverpod (StreamNotifierProvider, StateNotifierProvider)

**Database:** Drift (SQLite) with generated type-safe queries in `lib/data/datasources/local/app_database.g.dart`

**Sync:** Appwrite self-hosted. `SyncManager` runs a 5-min pull timer with optimistic push-before-pull; offline changes queue in Drift (`pendingSync=true`) and retry on reconnect.

**Providers:** Located in `presentation/` directories under each feature (e.g., `features/auth/presentation/providers/`)

## Backend

The app connects to a self-hosted Appwrite instance. Endpoint and project ID
are hardcoded in `lib/core/appwrite/appwrite_client.dart`. **No local
config, `.env`, or build-time secrets are needed.**

The Appwrite console must define 6 collections — `projects`, `tasks`,
`time_entries`, `special_days`, `moods`, `journal_entries` — with the
attributes each module expects (see `lib/data/datasources/remote/appwrite_datasource.dart`
for the field-per-collection contract). Permissions are user-scoped; every
query also adds `Query.equal('user_id', currentUserId)` because Appwrite
self-hosted has no native row-level RLS.

## Version

Version is defined in `lib/version.dart` (`appVersion`). This is the single source of truth — used by pubspec.yaml and CI.

## macOS Specifics

- `macos/Runner/Release.entitlements` includes `com.apple.security.network.client` — required for Appwrite connectivity
- Close button minimizes to Dock (AppDelegate.applicationShouldTerminateAfterLastWindowClosed = false)
- To rebuild after entitlement changes: `flutter build macos --release`

## Known Issues

- Run `flutter analyze lib/` to check lib/ code quality