# Task Manager

Personal task and time management application built with Flutter.

## Features

- **Task Management**: Create, edit, soft-delete, and reorder tasks with drag-and-drop
- **Project Organization**: Organize tasks by projects with expandable cards
- **Priority & Time Tracking**: Set task priority (low/medium/high/urgent) with start and due dates
- **Dashboard**: Visual statistics and data overview with completion rates
- **Calendar View**: Calendar integration with mood emoji picker for deadline visualization
- **Journal**: Daily entries with timestamps, Appwrite sync
- **Mood Tracking**: Multi-emoji support (max 3/day) with month/year statistics and distribution charts
- **Special Days**: 12x31 grid with 6-color categories and interval tracking
- **App Lock**: Biometric/PIN protection with PBKDF2-secured secret storage
- **User Profile**: Customizable avatar with local storage
- **Auto-Update**: GitHub Release checker with download dialog
- **Offline-first**: All writes queue locally and sync when the network returns;
  deletes propagate as tombstones instead of being silently resurrected on pull

## Architecture

Built with Clean Architecture principles. Each feature module follows
`{feature}/{domain,data,presentation}/` — see [`CLAUDE.md`](CLAUDE.md) for the
authoritative structure overview.

```
lib/
├── core/              # Shared: theme, constants, exceptions, logger, appwrite client
├── data/              # Repository implementations + Drift database + RemoteDatasource
├── domain/            # Entities + repository interfaces
└── features/
    ├── auth/          # domain, data, presentation
    ├── calendar/      # presentation
    ├── dashboard/     # presentation
    ├── journal/       # domain, data, presentation
    ├── mood/          # domain, data, presentation
    ├── projects/      # presentation
    ├── settings/      # data, presentation
    ├── special_days/  # domain, data, presentation
    ├── sync/          # data, presentation
    ├── tasks/         # presentation
    └── time_tracking/ # domain, data, presentation
```

Cross-cutting helpers in `lib/core/`:

- `core/utils/` — `date_key`, `retry_with_backoff`, `json_cache_store`, `result`, `logger`
- `core/services/database_provider.dart` — global Drift instance
- `core/widgets/async_error_view.dart` — branded error placeholder
- `data/datasources/remote/user_scoped_query.dart` — centralized
  user-scoped query helper that every Appwrite fetch goes through

## Tech Stack

- **Flutter** — UI framework
- **Riverpod** — state management (`NotifierProvider`, `StreamNotifierProvider`,
  `Provider`, `FutureProvider`)
- **Drift** — local SQLite database with type-safe queries
- **Appwrite** — self-hosted backend (auth, database, sessions)
- **flutter_secure_storage** — encrypted credential storage (Android Keystore /
  iOS Keychain)
- **pointycastle** — PBKDF2-HMAC-SHA256 for PIN derivation
- **table_calendar** — calendar widget
- **image_picker** — avatar upload from gallery/camera
- **local_auth** — biometric authentication
- **connectivity_plus** — network status monitoring
- **share_plus** — share functionality

## Development

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

## CI/CD

GitHub Actions release workflow builds and publishes artifacts for **Android**, **Windows**, **macOS**, and **Linux** on every tag push (v*).

## Platforms

- **Android** (APK)
- **Windows** (EXE)
- **macOS** (App)
- **Linux** (Tarball)

## Version

Current version: see `lib/version.dart` (`appVersion`). Used by `pubspec.yaml`
and the CI artifact name.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full release history.