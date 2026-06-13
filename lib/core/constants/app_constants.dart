import '../../version.dart' as app_version;
class AppConstants {
  // Single source of truth for app version is lib/version.dart
  // Build system may override via --dart-define=APP_VERSION
  static const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: app_version.appVersion);
  static const String dbName = 'task_manager.db';

  // Responsive breakpoints
  static const double sidebarBreakpoint = 900;  // sidebar vs drawer
  static const double compactBreakpoint = 600;  // compact card layouts

  // Master-detail layout
  static const double masterPaneDefaultWidth = 350.0;
  static const double masterPaneMinWidth = 280.0;
  static const double masterPaneMaxWidth = 500.0;

  // Spacing
  static const double spacing8 = 8.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // Border radius
  static const double radiusSmall = 4.0;

  // Default project id (used as the seed for first-launch projects)
  static const String defaultProjectId = '00000000-0000-0000-0000-000000000001';

  // GitHub update check
  static const String githubOwner = 'craftor';
  static const String githubRepo = 'task-manager';

  // Sync settings
  static const Duration syncInterval = Duration(minutes: 5);
}