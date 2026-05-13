import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/projects/presentation/providers/projects_provider.dart';
import 'features/projects/presentation/tasks_projects_screen.dart';
import 'features/calendar/presentation/screens/calendar_screen.dart';
import 'features/gantt/presentation/screens/gantt_screen.dart';
import 'features/journal/presentation/journal_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/mood/presentation/mood_stats_screen.dart';
import 'features/special_days/presentation/special_days_screen.dart';
import 'features/sync/presentation/providers/sync_status_provider.dart';
import 'features/sync/data/sync_manager.dart' show SyncStatus;
import 'core/services/providers/update_provider.dart';
import 'core/services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';
class TaskManagerApp extends ConsumerWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    switch (authState.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt, size: 80, color: AppColors.primary),
                SizedBox(height: 32),
                CircularProgressIndicator(color: AppColors.primary),
              ],
            ),
          ),
        );
      case AuthStatus.authenticated:
        return const MainScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();
    }
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectsProvider.notifier).ensureDefaultProject();
    });
  }

  static const _navItems = [
    _NavItem(Icons.edit_note_outlined, Icons.edit_note, 'Journal'),
    _NavItem(Icons.task_alt_outlined, Icons.task_alt, 'Tasks'),
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar'),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Gantt'),
    _NavItem(Icons.emoji_emotions_outlined, Icons.emoji_emotions, 'Mood'),
    _NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome, 'Dates'),
  ];

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStatusProvider);
    ref.listen(syncStatusProvider, (prev, next) {
      final now = next.valueOrNull;
      if (now == null || prev?.valueOrNull?.status == now.status) return;
      if (now.status == SyncStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.cloud_done, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Sync completed'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (now.status == SyncStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(now.errorMessage ?? 'Sync failed')),
            ]),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= AppConstants.sidebarBreakpoint;

    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  // ─── Desktop Layout: fixed sidebar + content ───
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _buildSidebar(),
          // Content area
          Expanded(
            child: Column(
              children: [
                // Compact top bar
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Task Manager',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      _buildUpdateBanner(context),
                    ],
                  ),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final width = _sidebarExpanded ? 200.0 : 64.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Logo + collapse toggle
          GestureDetector(
            onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.task_alt, size: 22, color: AppColors.background),
            ),
          ),
          if (_sidebarExpanded)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 16),
              child: Text(
                'Task Manager',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(height: 16),
          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = index == _selectedIndex;
                final color = isSelected ? AppColors.primary : AppColors.textMuted;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Material(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _selectedIndex = index),
                      child: _sidebarExpanded
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? item.selected : item.outline,
                                    color: color,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Icon(
                                isSelected ? item.selected : item.outline,
                                color: color,
                                size: 22,
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // Bottom: avatar + collapse toggle
          GestureDetector(
            onTap: () => _showUserProfile(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _sidebarExpanded
                  ? Row(
                      children: [
                        _buildAvatarWidget(ref),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _getUserInitials(ref),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Center(child: _buildAvatarWidget(ref)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IconButton(
              icon: Icon(
                _sidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
                color: AppColors.textMuted,
                size: 22,
              ),
              onPressed: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
              tooltip: _sidebarExpanded ? 'Collapse sidebar' : 'Expand sidebar',
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mobile Layout: drawer ───
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'Task Manager',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 20),
        ),
        centerTitle: true,
      ),
      drawer: _buildMobileDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: AppColors.surface,
      width: 88,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.task_alt, size: 28, color: AppColors.background),
          ),
          const SizedBox(height: 32),
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = index == _selectedIndex;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = index);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? item.selected : item.outline,
                        size: 26,
                        color: isSelected ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _showUserProfile(context);
            },
            child: Container(
              margin: const EdgeInsets.all(12),
              child: _buildAvatarWidget(ref),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const JournalScreen();
      case 1:
        return const TasksProjectsScreen();
      case 2:
        return DashboardScreen(
            onNavigate: (index) => setState(() => _selectedIndex = index));
      case 3:
        return const CalendarScreen();
      case 4:
        return const GanttScreen();
      case 5:
        return const MoodStatsScreen();
      case 6:
        return const SpecialDaysScreen();
      default:
        return const JournalScreen();
    }
  }

  String _getUserInitials(WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final email = authState.email ?? '';
    if (email.isEmpty) return '?';
    final parts = email.split('@');
    return parts[0].substring(0, parts[0].length > 2 ? 2 : 1).toUpperCase();
  }

  Widget _buildAvatarWidget(WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final avatarUrl = authState.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: FileImage(File(avatarUrl)),
        backgroundColor: AppColors.primary.withOpacity(0.2),
      );
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary.withOpacity(0.2),
      child: Text(
        _getUserInitials(ref),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  void _showUserProfile(BuildContext context) {
    final authState = ref.read(authStateProvider);
    final email = authState.email ?? 'Unknown';
    final avatarUrl = authState.avatarUrl;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _pickImage(dialogContext),
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: avatarUrl != null && avatarUrl.isNotEmpty
                            ? null
                            : AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        color: avatarUrl != null && avatarUrl.isNotEmpty
                            ? AppColors.surfaceLight
                            : null,
                        image: avatarUrl != null && avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: FileImage(File(avatarUrl)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? Center(
                              child: Text(
                                _getUserInitials(ref),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text('Tap to change avatar',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 16),
              const Text('Personal Profile',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              _ProfileItem(
                  icon: Icons.email_outlined, label: 'Email', value: email),
              const SizedBox(height: 12),
              _ProfileItem(
                  icon: Icons.badge_outlined,
                  label: 'Nickname',
                  value: email.split('@').first),
              const SizedBox(height: 12),
              _ProfileItem(
                  icon: Icons.info_outline,
                  label: 'Version',
                  value: '0.6.3'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(authStateProvider.notifier).signOut();
                        Navigator.pop(dialogContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateBanner(BuildContext context) {
    final updateAsync = ref.watch(updateInfoProvider);
    return updateAsync.when(
      data: (info) {
        if (info == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => _showUpdateDialog(context, info),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'v${info.version} available',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Text(
              'Update Available',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${info.version} is ready.',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            if (info.body.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  info.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openDownloadUrl(info.downloadUrl);
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
          ),
        ],
      ),
    );
  }

  void _openDownloadUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _pickImage(BuildContext dialogContext) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      ref.read(authStateProvider.notifier).updateAvatar(pickedFile.path);
    }
  }
}

class _NavItem {
  final IconData outline;
  final IconData selected;
  final String label;
  const _NavItem(this.outline, this.selected, this.label);
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
