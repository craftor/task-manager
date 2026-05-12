# Task Manager

Personal task and time management application built with Flutter.

## Features

- **Task Management**: Create, edit, delete, and reorder tasks with drag-and-drop
- **Project Organization**: Organize tasks by projects with expandable cards
- **Priority & Time Tracking**: Set task priority (low/medium/high/urgent) with start and due dates
- **Dashboard**: Visual statistics and data overview
- **Calendar View**: Calendar integration for deadline visualization
- **Gantt Chart**: Timeline view for task scheduling
- **User Profile**: Customizable avatar with local storage

## Architecture

Built with Clean Architecture principles:

```
lib/
├── core/           # Shared utilities, theme, constants
├── data/           # Data layer (repositories, datasources)
├── domain/         # Business logic (entities, services)
└── features/       # Feature modules
    ├── auth/
    ├── calendar/
    ├── dashboard/
    ├── gantt/
    ├── projects/
    ├── tasks/
    └── time_tracking/
```

## Tech Stack

- **Flutter** - UI framework
- **Riverpod** - State management
- **Drift** - Local SQLite database
- **Supabase** - Backend services (auth, database)
- **table_calendar** - Calendar widget
- **image_picker** - Avatar upload

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
```

## Platforms

- **Android** (APK)
- **Windows** (EXE)
- **macOS** (App)

## CI/CD

GitHub Actions workflows configured for:
- **Android**: Release APK build on tag push
- **Windows**: Release build on tag push
- **macOS**: Release build on tag push

## Version

Current version: 0.3.0

## Changelog

### 0.3.0
- Desktop: fixed sidebar with collapse/expand, avatar at bottom
- Desktop: login/register width constrained to 480px
- Gantt: zoom levels W/M/Q/Y with adaptive time headers
- Time Tracking: task name display instead of UUID
- Auto-update: GitHub Release checker with banner + dialog
- macOS platform support
- GitHub Release CI with APK/EXE/App artifacts
- App icon, display name "TaskManager"
- Fix: Gantt uses startDate, not createdAt
- Fix: project sync fields, pendingSync flags
- Fix: Riverpod self-invalidation, time rounding
- Refactor: version constant, icon map dedup, Dashboard type fix

### 0.2.1
- Fix project sync: pendingSync flag, missing Supabase fields (description, dates, sort_order)
- Fix task sync: missing start_date in upsertTask
- TimeEntry: add isRunning getter to domain entity
- Project creation: pass description, startDate, endDate
- Sync status: SnackBar notification on success/error

### 0.2.0
- **Sync**: Bidirectional Supabase sync for projects, tasks, and time entries
- **Time Tracking**: Manual entry form with task selector, date/time pickers, and notes
- **Timer**: Task selector dialog before starting a timer
- **Bug Fixes**: Supabase NULL query, time rounding, Riverpod self-invalidation, version consistency
- **UI**: Custom app icon, app display name "TaskManager"
