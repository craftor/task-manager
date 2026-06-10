# Changelog

All notable changes to [Task Manager](https://github.com/craftor/task-manager) are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.11.0] - 2026-06-04

### Changed
- **Backend migrated from Supabase to self-hosted Appwrite.** `RemoteDatasource` abstraction (Phase A) keeps feature code SDK-agnostic; `AppwriteDatasource` implements all 6 collections — `projects`, `tasks`, `time_entries`, `special_days`, `moods`, `journal_entries` — with `Query.equal('user_id', currentUserId)` per query in lieu of native row-level security
- **Auth** rewired to `AppwriteAuthService` behind the existing `AuthService` interface (Phase B); login/register/logout/session flows unchanged for callers
- Appwrite endpoint and project id are hardcoded in `lib/core/appwrite/appwrite_client.dart` — no `.env`, no build-time secrets
- `CLAUDE.md` rewritten for the Appwrite architecture

### Removed
- Supabase SDK, datasource, auth service, and all related dependencies (Phase E + follow-up purges)
- `.env` / `.env.example` files and the CI `.env` creation step — Appwrite needs no build-time secrets

### Fixed
- CI now runs `build_runner` before `flutter build` so generated Drift code is fresh on every release artifact

---

## [0.10.0] - 2026-05-28

### Added
- **Rust backend** with Axum framework and PostgreSQL database
- **FAB (Floating Action Button) quick-add** dialogs for Tasks and Projects screens
- **Master-detail responsive layout** for desktop (sidebar detail panel)

### Changed
- Sync version to 0.10.0 across `pubspec.yaml` and `version.dart`

### Fixed
- Resolved code analysis warnings and deprecated API usage

---

## [0.8.5] - 2026-05-26

### Fixed
- **PIN security**: upgraded to SHA-256 hash for PIN storage
- **sortOrder**: global renumbering to maintain consistent ordering
- **Type safety**: resolved multiple type warnings across the codebase
- **Year dynamic**: fixed year selection behavior in date views
- **AppLock**: resolved deadlock condition when app resumes from background

---

## [0.8.2] - 2026-05-24

### Added
- **Month Row view** with continuous years display and responsive emoji sizing

---

## [0.8.1] - 2026-05-24

### Changed
- **Dashboard** is now the default first page in the sidebar

### Fixed
- `BuildContext` async gap issues across multiple screens
- Unnecessary null assertions removed
- Deprecated `activeColor` replaced
- 35+ `prefer_const_constructors` lint fixes across codebase
- Underscore local variable naming cleanup

### Removed
- Dead code `_TimeSummaryCard`

### Added
- **macOS DMG packaging** script (`scripts/build_dmg.sh`)
- **Responsive calendar grid** — adapts between 7-day/row mobile and expanded desktop layouts

---

## [0.8.0] - 2026-05-23

### Added
- Full codebase scan with 6 review agents
- `getTimeEntryById` method in database, repository, and provider chain
- **macOS**: close button minimizes to Dock (instead of quitting); Dock menu adds quit option
- **macOS**: network client entitlement for Supabase connectivity
- **macOS**: app name set to "TaskManager" with updated app icon

### Changed
- Drift: regenerated `app_database.g.dart` with new methods

### Fixed
- **N+1 batch upserts** — optimized to single-query operations
- **TOCTOU pattern** in `ensureDefaultProject` and `deleteProject` — now uses direct ID lookup instead of `fetchAll`
- **Timer leak** — `Timer.periodic` properly cleaned up on error paths in `time_tracking_provider`
- **Export** — `_loadSpecialDays`, `_loadMoods`, `_loadJournal` stubs now actually export all data
- Deprecated `withOpacity` calls replaced with modern `withValues`

---

## [0.7.30] - 2026-05-19

### Added
- `AppException` hierarchy for structured error handling
- `SyncQueue` with retry logic for offline resilience
- `Logger` utility for consistent logging

### Changed
- Supabase credentials moved to `flutter_secure_storage` for enhanced security

### Reverted
- `app.dart` split reverted due to navigation issues (Dates/Settings/Profile buttons not responding)

### Fixed
- Android APK copied to artifacts directory in CI
- Absolute path used for macOS artifact zip in CI
- macOS artifact path corrected in CI workflow

---

## [0.7.28] - 2026-05-18

### Added
- **Linux desktop platform** support (GTK3)

### Changed
- Version management unified with single source of truth (`lib/version.dart`)
- `pubspec.yaml` now reads version from `lib/version.dart`

### Fixed
- GTK3 dependencies installed for Linux desktop build
- `sudo` used for `apt-get` in Linux CI build step
- Linux desktop enabled and PowerShell syntax fixed in CI

---

## [0.7.7] - 2026-05-15

### Added
- Android APK signing with keystore from GitHub Secret
- CI artifact renaming to `TaskManager_{version}_{platform}.{ext}`

### Fixed
- Multiple CI release workflow fixes (artifact paths, download paths)

---

## [0.7.6] - 2026-05-14

### Fixed
- Removed Gantt and Time Tracking from navigation (reverted visibility)
- Corrected `Column` children bracket structure in SpecialDays page

### Added
- `.env` file creation step in CI build workflow
- Drift code regenerated for v2.19.1 compatibility

---

## [0.7.3] - 2026-05-14

### Added
- **Settings page** with import/export preferences
- **User profile page** with customizable avatar

---

## [0.7.2] - 2026-05-14

### Security
- Multiple security fixes applied

### Changed
- Sync improvements for reliability

---

## [0.7.1] - 2026-05-14

### Changed
- App icon updated
- Environment variable handling secured

---

## [0.7.0] - 2026-05-14

### Added
- **Sync**: immediate push on all CRUD operations (tasks, projects, moods, special days, journal)
- **Sync**: remote-wins reconciliation — local stale data auto-pruned
- **Sync**: delete via upsert + `deleted_at` (bypasses RLS UPDATE restrictions)
- **App Lock**: fingerprint/biometric + 4-digit PIN with background lock
- Responsive mobile layout support

### Changed
- Full codebase refactor with Clean Architecture structure
- Unified version management across project files

### Removed
- Gantt chart page

### Fixed
- UI: Special Days Intervals displayed in single row
- Desktop sidebar polish
- Android: `FlutterFragmentActivity` + AppCompat theme for biometric support

---

## [0.6.4] - 2026-05-13

### Fixed
- Multiple CI fixes for release workflow

---

## [0.6.3] - 2026-05-13

### Added
- Android `INTERNET` permission + `network_security_config` for Supabase connectivity
- Enhanced error handling with detailed network error messages

### Fixed
- CI release artifact upload with `merge-multiple`

---

## [0.6.2] - 2026-05-13

### Added
- **Dashboard**: Weekly Completion card
- **Dashboard**: Project Progress card  
- **Dashboard**: Time Overview card
- **Mood**: Supabase sync with auto-refresh after pull

### Changed
- Desktop sidebar: avatar at bottom, version/update banner in top bar

---

## [0.6.1] - 2026-05-13

### Fixed
- CI workflow fixes

---

## [0.6.0] - 2026-05-13

### Added
- All data synced bidirectionally (tasks, projects, time entries, journal, special days, moods)
- **Dashboard**: Weekly Completion, Project Progress, Time Overview statistics
- **Mood**: multi-emoji support (max 3/day), month navigation, tap calendar to edit
- **Journal**: multi-entry per day with timestamps, Supabase sync
- **Special Days**: 12×31 grid with 6-color categories, long-press edit/delete
- **CI**: matrix build for Android/Windows/macOS, GitHub Release on tag

### Changed
- Sidebar reordered: Journal → Tasks → Dashboard → Calendar → Mood → Dates
- Desktop fixed sidebar with collapse/expand, unified responsive breakpoints

---

## [0.5.0] - 2026-05-13

### Added
- **Journal / quick notes** page with daily entry + history
- **Mood stats** page with month/year views and distribution charts
- **Special days tracker**: 12×31 grid with intervals, year switching
- **Calendar**: mood emoji picker, go-to-today button

### Changed
- Desktop: fixed sidebar with collapse/expand
- Dashboard: removed time/mood cards, kept priority + recent tasks

---

## [0.4.1] - 2026-05-13

### Removed
- Linux desktop platform (temporarily)

---

## [0.4.0] - 2026-05-13

### Added
- **CI**: matrix build for Android/Windows/macOS/Linux with streamlined release

---

## [0.3.0] - 2026-05-12

### Added
- **Gantt chart**: zoom levels W/M/Q/Y with adaptive time headers
- **Time Tracking**: task name display instead of UUID
- **Auto-update**: GitHub Release checker with banner + dialog
- **CI**: GitHub Release workflow with APK/EXE/App artifacts

### Changed
- macOS platform support

---

## [0.2.6] - 2026-05-12

### Fixed
- Version synchronization across project files

---

## [0.2.5] - 2026-05-12

### Fixed
- Windows package build fixes

---

## [0.2.4] - 2026-05-12

### Added
- GitHub Release automation

---

## [0.2.3] - 2026-05-12

### Added
- **macOS platform** support

---

## [0.2.2] - 2026-05-12

### Changed
- Flutter upgrade for CI compatibility

### Fixed
- CI workflow fixes

---

## [0.2.1] - 2026-05-12

### Fixed
- Sync field fixes
- AGP version fix for Android CI

---

## [0.2.0] - 2026-05-12

### Added
- **Bidirectional Supabase sync** for projects, tasks, and time entries
- **Time Tracking**: manual entry form with task selector, date/time pickers, and notes
- **Timer**: task selector dialog before starting a timer
- **Dashboard** page with overview statistics
- **Avatar upload** from gallery/camera
- **Project icon picker**
- **Task filter** functionality
- **GitHub Actions CI** for Android and Windows builds on tag push
- Navigation drawer for desktop layout

### Fixed
- Project icon editing
- Various sync field mapping issues

---

## [0.1.0] - 2026-05-11

### Added
- Initial Flutter project setup with theme and app structure
- **Drift database** with tables for projects, tasks, and time entries
- **Repository interfaces and implementations** (Clean Architecture foundation)
- Tasks screen with create/edit/complete/delete functionality
- Projects screen with create/edit/delete
- **Riverpod providers** for state management
- **Calendar view** with `table_calendar`
- Default project, project/task drag-reorder, user profile, draggable cards
- **Supabase integration**: client initialization, auth service, auth provider
- Login and Register screens with email/password authentication
- Supabase datasource for remote data operations
- **Auth**: login/register/logout with Supabase
- Project entity and time tracking feature

---

[0.11.0]: https://github.com/craftor/task-manager/releases/tag/v0.11.0
[0.10.0]: https://github.com/craftor/task-manager/releases/tag/v0.10.0
[0.8.5]: https://github.com/craftor/task-manager/releases/tag/v0.8.5
[0.8.2]: https://github.com/craftor/task-manager/releases/tag/v0.8.2
[0.8.1]: https://github.com/craftor/task-manager/releases/tag/v0.8.1
[0.8.0]: https://github.com/craftor/task-manager/releases/tag/v0.8.0
[0.7.30]: https://github.com/craftor/task-manager/releases/tag/v0.7.30
[0.7.28]: https://github.com/craftor/task-manager/releases/tag/v0.7.28
[0.7.7]: https://github.com/craftor/task-manager/releases/tag/v0.7.7
[0.7.6]: https://github.com/craftor/task-manager/releases/tag/v0.7.6
[0.7.3]: https://github.com/craftor/task-manager/releases/tag/v0.7.3
[0.7.2]: https://github.com/craftor/task-manager/releases/tag/v0.7.2
[0.7.1]: https://github.com/craftor/task-manager/releases/tag/v0.7.1
[0.7.0]: https://github.com/craftor/task-manager/releases/tag/v0.7.0
[0.6.4]: https://github.com/craftor/task-manager/releases/tag/v0.6.4
[0.6.3]: https://github.com/craftor/task-manager/releases/tag/v0.6.3
[0.6.2]: https://github.com/craftor/task-manager/releases/tag/v0.6.2
[0.6.1]: https://github.com/craftor/task-manager/releases/tag/v0.6.1
[0.6.0]: https://github.com/craftor/task-manager/releases/tag/v0.6.0
[0.5.0]: https://github.com/craftor/task-manager/releases/tag/v0.5.0
[0.4.1]: https://github.com/craftor/task-manager/releases/tag/v0.4.1
[0.4.0]: https://github.com/craftor/task-manager/releases/tag/v0.4.0
[0.3.0]: https://github.com/craftor/task-manager/releases/tag/v0.3.0
[0.2.6]: https://github.com/craftor/task-manager/releases/tag/v0.2.6
[0.2.5]: https://github.com/craftor/task-manager/releases/tag/v0.2.5
[0.2.4]: https://github.com/craftor/task-manager/releases/tag/v0.2.4
[0.2.3]: https://github.com/craftor/task-manager/releases/tag/v0.2.3
[0.2.2]: https://github.com/craftor/task-manager/releases/tag/v0.2.2
[0.2.1]: https://github.com/craftor/task-manager/releases/tag/v0.2.1
[0.2.0]: https://github.com/craftor/task-manager/releases/tag/v0.2.0
[0.1.0]: https://github.com/craftor/task-manager/releases/tag/v0.1.0