# Changelog

All notable changes to Task Manager are documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.13.1] - 2026-08-17

### Changed
- **Dependency upgrade within `^` constraints** — 42 packages bumped
  to newer compatible versions via `flutter pub upgrade`. Notable
  cross-minor jumps: `analyzer` 6.4.1 → 10.0.1, `source_gen`
  1.5.0 → 4.2.4 (drove a Drift codegen re-run), `sqlite3` 2.9.4 →
  3.5.1 (build hook downloads the macOS arm64 dylib on first build,
  cached thereafter), `sqlparser` 0.37.1 → 0.44.5, `shelf_web_socket`
  2.0.1 → 3.0.0. No `pubspec.yaml` edits and no application code
  changes. `flutter analyze` clean, 27/27 unit tests pass, macOS
  debug build verified.

## [0.13.0] - 2026-08-04

### Added
- **Appwrite Realtime subscription** in `SyncManager`. Changes from
  other devices now propagate within ~1s instead of waiting for the
  5-min poll. Subscribes to all 6 collections (`projects`, `tasks`,
  `time_entries`, `special_days`, `moods`, `journal_entries`) over a
  shared WebSocket using the Appwrite session cookie for auth.
- **Per-key apply methods** on the journal / mood / special_days
  repositories (`applyRemoteUpsertEntry` / `applyRemoteDeleteEntry`,
  `applyRemoteMood` / `applyRemoteDeleteMood`,
  `applyRemoteDay` / `applyRemoteDeleteDay`). Realtime events now
  write the affected key only, instead of clobbering the whole
  SharedPreferences cache the way `pullFromRemote` does.
- **`scripts/smoke_tablesdb.sh`** — pre-merge validation for the
  TablesDB migration. Accepts either an opaque session token or
  email + password (auto-login). 6/6 collections pass against the
  self-hosted Appwrite 1.9 instance.

### Changed
- **Migrated Appwrite `Databases` → `TablesDB`** (SDK 21.4.0's
  recommended replacement for the deprecated document API).
  `listDocuments` → `listRows`, `createDocument` → `createRow`,
  `updateDocument` → `updateRow`, `deleteDocument` → `deleteRow`;
  collection/document ids renamed to table/row. The manual
  try-create-then-update-on-409 upsert is replaced with the SDK's
  native `TablesDB.upsertRow` (one round-trip, no exception-driven
  control flow). `Row.fromMap` has the same `data: map["data"] ?? map`
  shadowing bug that hit `Document.fromMap` (now fixed in 0.12.6),
  so `special_days` and `moods` still use the raw HTTP path — now
  pointing at `/tablesdb/.../tables/.../rows`. The
  `// ignore_for_file: deprecated_member_use` annotation is gone.
- **Drift `upsert{Project,Task,TimeEntry}FromRemote` now return
  `Future<bool>`** and short-circuit when the local copy is
  `pendingSync=true`. Same guard applies to the periodic pull, so
  offline edits are never clobbered by either a Realtime event or a
  pull that arrives before the push completes.

### Removed
- **`backend/`** — the v0.10.0-era Rust+Axum+PostgreSQL service
  that was made redundant by the v0.11.0 Supabase → Appwrite
  migration but never deleted. Cargo workspace, Dockerfile,
  docker-compose, migrations, and 22 Rust source files all gone.
  `run_api_tests.bat` (the only file outside `backend/` that
  referenced it) gone too. Net diff: −1,773 lines.

## [0.12.7] - 2026-07-19

### Changed
- **CI actions bumped to Node 24 majors** (`checkout` v7,
  `upload-artifact` v7, `download-artifact` v8, `action-gh-release` v3),
  silencing the "Node.js 20 is deprecated" workflow annotations. No app
  code changes — this tag exists to exercise the updated release workflow
  end to end.

## [0.12.6] - 2026-07-19

### Fixed
- **Special Days / Moods never synced from the cloud (all platforms)**.
  Appwrite SDK 21.4.0's `Document.fromMap` does `data: map["data"] ?? map`,
  so any document in a collection with a custom attribute literally named
  `data` (`special_days`, `moods`) deserialized with `Document.data` set to
  that attribute's raw String — losing all sibling attributes and throwing
  `type 'String' is not a subtype of type 'Map<String, dynamic>'` in
  `_docToRow`. The pull died before touching the local cache, so 68 cloud
  rows never appeared. Both collections now fetch through a raw
  `client.call` path that skips the broken model (`_fetchRaw`).
- **Fetches capped at 25 rows**. Every `listDocuments` call used the
  Appwrite default page size; larger collections silently truncated. All
  fetches now paginate with `limit(100)` + `offset`.
- **Failed logins showed no error and no navigation**. `AuthWrapper`
  replaces `LoginScreen` with a loading splash during the sign-in attempt,
  so the SnackBar listener unmounted before the error state arrived.
  Sign-in errors now render inline on the login page, straight from
  `AuthState`.

### Added
- **"Send a ping" button** on the Dashboard (calls `client.ping()`), per
  the Appwrite onboarding checklist.

## [0.12.5] - 2026-07-16

### Fixed
- **Special Days not showing on macOS**. `SpecialDaysRepositoryImpl.getAll()`
  now refreshes from Appwrite whenever a remote datasource is available,
  instead of only pulling when the local SharedPreferences cache is empty.
  A stale/non-empty cache could prevent special days written on another
  device (or after a reinstall) from appearing.

## [0.12.4] - 2026-07-16

### Fixed
- **macOS update dialog downloaded the Android APK**. `UpdateService` now picks
  the GitHub Release asset that matches the current platform (`.apk`,
  `_macos.dmg`, `_windows.zip`, `_linux.tar.gz`) instead of always selecting the
  first `.apk`. Falls back to the release page when no matching asset is found.

## [0.12.3] - 2026-06-14

### Changed
- **GitHub Actions macOS artifact switched from `.zip` to `.dmg`**. The release
  job now uses the macOS-bundled `hdiutil` to wrap `task_manager.app` in a
  compressed read-only UDZO DMG with an `/Applications` symlink, so users
  can drag the app to the Applications folder in Finder. No third-party
  packaging tools added.

## [0.12.2] - 2026-06-14

### Fixed
- **GitHub Actions Linux build broken**: `desktop_webview_window` (used by
  `flutter_web_auth_2` for OAuth) requires `webkit2gtk-4.x` + `libsoup` at
  build time. The previous workflow only installed
  `libgtk-3-dev / pkg-config / cmake / ninja-build / libsecret-1-dev`, so
  the CMake configure step failed with:
  `The following required packages were not found: - webkit2gtk-4.0`.
  The install step now tries 4.1 / 3.0 first (Ubuntu 24.04, current
  `ubuntu-latest`) and falls back to 4.0 / 2.4 (Ubuntu 22.04) so the
  workflow survives runner bumps.

## [0.12.1] - 2026-06-14

### Fixed
- **macOS login broken**: `createEmailPasswordSession` hung indefinitely with no
  SnackBar feedback. Two root causes stacked:
  - **App Transport Security** silently dropped the plain-HTTP request to
    `http://o.21up.cn:6080/v1`. Added an `NSAppTransportSecurity` exception for
    `o.21up.cn` in `macos/Runner/Info.plist` so NSURLSession actually starts the
    connection. (Android was never affected — no ATS layer.)
  - **Appwrite origin whitelist** rejected the bundled `com.example.taskManager`
    with `403 general_unknown_origin`. The default Flutter scaffold bundle ID
    was never registered in the Appwrite console. Renamed the Runner target to
    `cn.logicpi.TaskManager` to match the project's registered macOS platform.
    When registering a new bundle in Appwrite, also update
    `macos/Runner/Configs/AppInfo.xcconfig` and the `RunnerTests` targets in
    `project.pbxproj`.

### Changed
- **`AppwriteAuthService.signInWithEmail` now logs `[AUTH]`-prefixed traces
  and applies a 15s timeout** to each Appwrite call. Previously a hung request
  left the UI stuck on the loading spinner with no signal; now a real timeout
  surfaces a SnackBar with `"请求超时 (15s) — 网络或后端无响应"`.
- `_humanize` defaults now use `e.message` so unexpected Appwrite error codes
  reach the user instead of being swallowed as `"Auth error (code N)"`.

## [0.12.0] - 2026-06-13

### Security
- **PIN storage hardened**: SHA-256 + static salt replaced with PBKDF2-HMAC-SHA256
  (100k iterations) and a random per-install salt.
- **flutter_secure_storage wired into AppLockService** (Android Keystore / iOS Keychain).
  Previously the PIN hash lived in plain `SharedPreferences` even though the
  `flutter_secure_storage` dependency was already declared.
- **Legacy hash migration**: installs from the previous version auto-detect the
  legacy SHA-256 + static-salt hash on first `verifyPin`, wipe it, and force the
  user to re-enroll. No silent lockouts.
- **Auth errors carry `AuthFailureKind`**: machine-readable enum
  (`invalidCredentials` / `emailInUse` / `rateLimited` / `network` / `unknown`)
  so UI can switch on failure type instead of parsing message strings.

### Data integrity
- **Drift schema v6** adds `deleted_at` tombstone columns to `Projects` and `Tasks`.
- **Soft-delete with tombstone**: `deleteTask` / `deleteProject` now stamp
  `deleted_at + pending_sync` locally and push the tombstone to remote, only
  physically removing the local row after the remote upsert succeeds.
- Fixes the offline-delete "resurrection" bug where a local delete that failed
  to push would be re-pulled from the remote on the next sync tick.
- `SyncManager._pullRemoteChanges` now skips tombstones during the prune loop
  so in-flight offline deletes aren't clobbered by an early pull.
- Journal cache write/read protocols aligned — `mergeRemoteData` now serializes
  through `JournalEntry.toJson` so the cache never decodes into empty.

### Architecture
- **Clean Architecture split for `journal`, `mood`, `special_days`**:
  each feature now has its own `domain/` (entity + repository interface),
  `data/` (repository implementation + cache helper), and `presentation/`
  (provider + screen) subdirectories.
- **`SyncManager` no longer reaches into other features' internals** —
  it calls `journalRepo.pullFromRemote(remote)` / `moodRepo.pullFromRemote(...)`
  / `specialDaysRepo.pullFromRemote(...)` instead of poking cache helpers
  directly.
- **`databaseProvider` relocated** from `features/projects/presentation/providers/`
  into `core/services/` so every feature can depend on it without reversing
  the layer hierarchy.
- **`TimeEntry` entity de-duplicated** — the local copy under
  `features/time_tracking/domain/time_entry_entity.dart` is gone; everyone
  imports the shared `lib/domain/entities/time_entry.dart` now.
- **`deleteProjectById` / `deleteTaskById` removed** — duplicates of
  `deleteProject` / `deleteTask`.

### State management
- **`StateNotifierProvider` → `NotifierProvider`** for `auth` and `app_lock`.
  The rest of the codebase already used `StreamNotifierProvider` / `Provider`.
- **TimeEntriesNotifier timer leak fixed** — the `ref.invalidateSelf()` loop
  that recreated the timer every second is gone. The new
  `runningEntryIdProvider` (StateProvider) and `stopwatchProvider`
  (StreamProvider) replace both the notifier's timer and the duplicate
  per-screen `Timer.periodic`.

### UI consistency
- **`AsyncErrorView` widget** replaces 6+ `SizedBox.shrink()` fallbacks that
  silently swallowed `AsyncValue.error`.
- **`Result<T, AppException>`** sealed class added for mutation return types;
  package surface ready for future Result-aware UI work.

### Shared helpers (new files in `core/`)
- `core/utils/date_key.dart` — canonical `yyyy-MM-dd` date key
- `core/utils/retry_with_backoff.dart` — shared exponential-backoff retry
- `core/utils/json_cache_store.dart` — SharedPreferences JSON helper
- `core/utils/result.dart` — sealed `Result<T>`
- `core/services/database_provider.dart` — global Drift provider
- `core/widgets/async_error_view.dart` — branded error placeholder
- `data/datasources/remote/user_scoped_query.dart` — user-scoped query helper
  that all Appwrite fetches now go through

### Tests
- `test/unit/appwrite_datasource_test.dart` — locks the user_id filter invariant
  at the `buildUserScopedQueries` / `buildLiveUserScopedQueries` boundary so
  any future fetch that forgets the partition key fails the test.
- `test/unit/app_lock_service_test.dart` — 6 cases covering PBKDF2 verify,
  salt randomness across installs, and legacy hash migration.
- `test/unit/auth_provider_test.dart` — migrated to `Notifier` +
  `ProviderContainer`; covers `AuthFailureKind` propagation.
- `test/unit/sync_manager_test.dart` — rewired for the new
  `JournalRepository` / `MoodRepository` / `SpecialDaysRepository`
  injection.
- Total tests: 11 → 20 passing.

### Dependency cleanup
- `flutter_dotenv` removed (no callers; superseded by Appwrite).
- `flutter_secure_storage` now actually wired in.
- `pointycastle: ^4.0.0` added for PBKDF2.

### Misc
- Dead constants removed from `app_constants.dart` (`appName`, `spacing4`,
  `spacing12`, `radiusMedium`, `radiusLarge`, `radiusCard`, `priorityLow..Urgent`).
- Sync errors now log at `Logger.e` (visible in release builds) instead of
  `Logger.d` (debug-only).
- `syncStatusProvider` returns `Stream.value(SyncState.idle)` instead of
  `Stream.empty()` when no manager exists, so first-time UI listeners get
  a baseline state.

---

## [0.11.0] - 2026-01 (preceding)
- Appwrite backend migration (replaced Supabase across auth, projects, tasks,
  time entries, special days, moods, journal).

---

## [0.8.1]
- Fix: BuildContext async gap issues, unnecessary null assertions, deprecated activeColor
- Cleanup: Remove dead code _TimeSummaryCard, fix underscore local variable naming
- Const optimization: 35+ prefer_const_constructors fixes across codebase
- Dates: Responsive calendar grid (7 days/row) with mobile vs desktop layouts
- Dashboard: Dashboard now default first page in sidebar
- Build: Add macOS DMG packaging script (scripts/build_dmg.sh)

## [0.8.0]
- Code quality: full codebase scan with 6 review agents — fixes for N+1 batch upserts, TOCTOU patterns, timer leaks, deprecated withOpacity calls
- Export: fix `_loadSpecialDays/Moods/Journal` stubs — now actually exports all data
- Timer: fix `Timer.periodic` leak on error paths in time_tracking_provider
- TOCTOU: fix `ensureDefaultProject` and `deleteProject` to use direct ID lookup instead of fetchAll
- Import: add `getTimeEntryById` to DB/repository/provider chain
- Drift: regenerate `app_database.g.dart` with new methods
- macOS: close button minimizes to Dock instead of quitting; dock menu adds quit option
- macOS: add network client entitlement for Supabase connectivity
- macOS: set app name to TaskManager and update app icon

## [0.7.33]
- Fix: copy Android APK to artifacts directory in CI

## [0.7.32]
- Fix: use absolute path for macOS artifact zip

## [0.7.31]
- Fix: correct macOS artifact path in CI workflow

## [0.7.30]
- Revert: app.dart split due to navigation issues (Dates/Settings/Profile buttons not responding)
- Code quality: AppException hierarchy, SyncQueue with retry, Logger utility
- Security: Supabase credentials moved to flutter_secure_storage

## [0.7.28]
- Unify version management with single source of truth
- Linux desktop platform support

## [0.7.0]
- Sync: immediate push on all CRUD (tasks, projects, moods, special days, journal)
- Sync: remote-wins reconciliation — local stale data auto-pruned
- Sync: delete via upsert + deleted_at (bypasses RLS UPDATE restrictions)
- App Lock: fingerprint/biometric + 4-digit PIN with background lock
- Removed Gantt chart page
- UI: Special Days Intervals in single row, desktop sidebar polish
- Android: FlutterFragmentActivity + AppCompat theme for biometric support

## [0.6.3]
- Android: add INTERNET permission + network_security_config for Supabase connectivity
- Auth: improve error handling with detailed network error messages
- CI: fix release artifact upload with merge-multiple

## [0.6.2]
- Dashboard: add Weekly Completion, Project Progress, Time Overview cards
- Mood: Supabase sync with auto-refresh after pull
- Desktop sidebar: avatar at bottom, version/update banner in top bar

## [0.6.0]
- All data synced bidirectionally (tasks, projects, time entries, journal, special days, moods)
- Dashboard: Weekly Completion, Project Progress, Time Overview stats
- Sidebar: Journal → Tasks → Dashboard → Calendar → Mood → Dates
- Desktop fixed sidebar with collapse/expand, unified responsive breakpoints
- Mood: multi-emoji (max 3/day), month navigation fix, tap calendar to edit
- Journal: multi-entry per day with timestamps, Supabase sync
- Special Days: 12x31 grid, 6-color categories, long-press edit/delete
- CI: matrix build for Android/Windows/macOS, GitHub Release on tag

## [0.5.0]
- Journal / quick notes page with daily entry + history
- Mood stats page with month/year views and distribution charts
- Special days tracker: 12×31 grid with intervals, year switching
- Calendar: mood emoji picker, go-to-today button
- Desktop: fixed sidebar with collapse/expand
- Dashboard: remove time/mood cards, keep priority + recent tasks

## [0.4.0]
- CI: matrix build for Android/Windows/macOS/Linux, streamlined release

## [0.3.0]
- Gantt: zoom levels W/M/Q/Y with adaptive time headers
- Time Tracking: task name display instead of UUID
- Auto-update: GitHub Release checker with banner + dialog
- macOS platform support
- GitHub Release CI with APK/EXE/App artifacts

## [0.2.0]
- **Sync**: Bidirectional Supabase sync for projects, tasks, and time entries
- **Time Tracking**: Manual entry form with task selector, date/time pickers, and notes
- **Timer**: Task selector dialog before starting a timer

## [0.1.0]
- Initial release with task management and project organization