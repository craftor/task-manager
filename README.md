# Task Manager

Personal task and time management application built with Flutter.

## Features

- **Task Management**: Create, edit, delete, and reorder tasks with drag-and-drop
- **Project Organization**: Organize tasks by projects with expandable cards
- **Priority & Time Tracking**: Set task priority (low/medium/high/urgent) with start and due dates
- **Dashboard**: Visual statistics and data overview with completion rates
- **Calendar View**: Calendar integration with mood emoji picker for deadline visualization
- **Journal**: Daily entries with timestamps, Supabase sync
- **Mood Tracking**: Multi-emoji support (max 3/day) with month/year statistics and distribution charts
- **Special Days**: 12x31 grid with 6-color categories and interval tracking
- **App Lock**: Biometric/PIN protection when app resumes
- **User Profile**: Customizable avatar with local storage
- **Auto-Update**: GitHub Release checker with download dialog

## Architecture

Built with Clean Architecture principles:

```
lib/
├── core/           # Shared utilities, theme, constants, exceptions, sync
├── data/           # Data layer (repositories, datasources, database)
├── domain/         # Business logic (entities, services)
└── features/       # Feature modules
    ├── auth/       # Login, register, app lock, profile
    ├── calendar/   # Calendar screen
    ├── dashboard/  # Statistics overview
    ├── journal/    # Daily journal entries
    ├── mood/       # Mood tracking and stats
    ├── projects/   # Project management
    ├── settings/   # Import/export, preferences
    ├── special_days/  # Special dates grid
    ├── sync/       # Supabase synchronization
    └── tasks/      # Task management
```

## Tech Stack

- **Flutter** - UI framework
- **Riverpod** - State management (StreamNotifierProvider, StateNotifierProvider)
- **Drift** - Local SQLite database with type-safe queries
- **Supabase** - Backend (auth, PostgreSQL database)
- **flutter_secure_storage** - Secure credential storage
- **table_calendar** - Calendar widget
- **image_picker** - Avatar upload from gallery/camera
- **local_auth** - Biometric authentication
- **connectivity_plus** - Network status monitoring
- **share_plus** - Share functionality

## Development

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Build Windows
flutter build windows --release

# Build macOS
flutter build macos --release

# Build Linux
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

Current version: see `lib/version.dart` (`appVersion`)

## Changelog

### 0.7.33
- Fix: copy Android APK to artifacts directory in CI

### 0.7.32
- Fix: use absolute path for macOS artifact zip

### 0.7.31
- Fix: correct macOS artifact path in CI workflow

### 0.7.30
- Revert: app.dart split due to navigation issues (Dates/Settings/Profile buttons not responding)
- Code quality: AppException hierarchy, SyncQueue with retry, Logger utility
- Security: Supabase credentials moved to flutter_secure_storage

### 0.7.28
- Unify version management with single source of truth
- Linux desktop platform support

### 0.7.0
- Sync: immediate push on all CRUD (tasks, projects, moods, special days, journal)
- Sync: remote-wins reconciliation — local stale data auto-pruned
- Sync: delete via upsert + deleted_at (bypasses RLS UPDATE restrictions)
- App Lock: fingerprint/biometric + 4-digit PIN with background lock
- Removed Gantt chart page
- UI: Special Days Intervals in single row, desktop sidebar polish
- Android: FlutterFragmentActivity + AppCompat theme for biometric support

### 0.6.3
- Android: add INTERNET permission + network_security_config for Supabase connectivity
- Auth: improve error handling with detailed network error messages
- CI: fix release artifact upload with merge-multiple

### 0.6.2
- Dashboard: add Weekly Completion, Project Progress, Time Overview cards
- Mood: Supabase sync with auto-refresh after pull
- Desktop sidebar: avatar at bottom, version/update banner in top bar

### 0.6.0
- All data synced bidirectionally (tasks, projects, time entries, journal, special days, moods)
- Dashboard: Weekly Completion, Project Progress, Time Overview stats
- Sidebar: Journal → Tasks → Dashboard → Calendar → Mood → Dates
- Desktop fixed sidebar with collapse/expand, unified responsive breakpoints
- Mood: multi-emoji (max 3/day), month navigation fix, tap calendar to edit
- Journal: multi-entry per day with timestamps, Supabase sync
- Special Days: 12x31 grid, 6-color categories, long-press edit/delete
- CI: matrix build for Android/Windows/macOS, GitHub Release on tag

### 0.5.0
- Journal / quick notes page with daily entry + history
- Mood stats page with month/year views and distribution charts
- Special days tracker: 12×31 grid with intervals, year switching
- Calendar: mood emoji picker, go-to-today button
- Desktop: fixed sidebar with collapse/expand
- Dashboard: remove time/mood cards, keep priority + recent tasks

### 0.4.0
- CI: matrix build for Android/Windows/macOS/Linux, streamlined release

### 0.3.0
- Gantt: zoom levels W/M/Q/Y with adaptive time headers
- Time Tracking: task name display instead of UUID
- Auto-update: GitHub Release checker with banner + dialog
- macOS platform support
- GitHub Release CI with APK/EXE/App artifacts

### 0.2.0
- **Sync**: Bidirectional Supabase sync for projects, tasks, and time entries
- **Time Tracking**: Manual entry form with task selector, date/time pickers, and notes
- **Timer**: Task selector dialog before starting a timer

### 0.1.0
- Initial release with task management and project organization