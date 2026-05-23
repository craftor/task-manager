# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal task and time management Flutter app with Supabase backend, built with Clean Architecture.

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
├── core/              # Shared: theme, constants, exceptions, sync queue, logger, supabase client
├── data/              # Repository implementations + Drift database + Supabase datasource
├── domain/            # Entities + repository interfaces
└── features/         # Feature modules (auth, calendar, dashboard, journal, mood, projects, settings, special_days, sync, tasks, time_tracking)
    └── [feature]/
        ├── domain/       # Feature entities
        ├── data/         # Feature repository implementations
        └── presentation/ # Screens, providers, widgets
```

**State management:** Riverpod (StreamNotifierProvider, StateNotifierProvider)

**Database:** Drift (SQLite) with generated type-safe queries in `lib/data/datasources/local/app_database.g.dart`

**Sync:** Supabase PostgreSQL. `core/sync/sync_queue.dart` handles offline retry. Remote-wins reconciliation on pull.

**Providers:** Located in `presentation/` directories under each feature (e.g., `features/auth/presentation/providers/`)

## Environment Setup

Create a `.env` file from `.env.example` before running:
```bash
cp .env.example .env
# Then fill in SUPABASE_URL and SUPABASE_KEY
```

pubspec.yaml references `assets: - .env` — the file must exist or the build fails.

## Version

Version is defined in `lib/version.dart` (`appVersion`). This is the single source of truth — used by pubspec.yaml and CI.

## macOS Specifics

- `macos/Runner/Release.entitlements` includes `com.apple.security.network.client` — required for Supabase connectivity
- Close button minimizes to Dock (AppDelegate.applicationShouldTerminateAfterLastWindowClosed = false)
- To rebuild after entitlement changes: `flutter build macos --release`

## Known Issues

- Run `flutter analyze lib/` to check lib/ code quality
- `.env` file must exist before building (cp .env.example .env)