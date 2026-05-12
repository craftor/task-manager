import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/projects/presentation/providers/projects_provider.dart';
import 'features/projects/presentation/screens/projects_screen.dart';
import 'features/tasks/presentation/screens/tasks_screen.dart';
import 'features/time_tracking/presentation/screens/time_tracking_screen.dart';
import 'features/calendar/presentation/screens/calendar_screen.dart';
import 'features/gantt/presentation/screens/gantt_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';

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
                Icon(
                  Icons.task_alt,
                  size: 80,
                  color: AppColors.primary,
                ),
                SizedBox(height: 32),
                CircularProgressIndicator(
                  color: AppColors.primary,
                ),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectsProvider.notifier).ensureDefaultProject();
    });
  }

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined, size: 26),
      selectedIcon: Icon(Icons.dashboard, size: 26),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.folder_outlined, size: 26),
      selectedIcon: Icon(Icons.folder, size: 26),
      label: 'Projects',
    ),
    NavigationDestination(
      icon: Icon(Icons.task_alt_outlined, size: 26),
      selectedIcon: Icon(Icons.task_alt, size: 26),
      label: 'Tasks',
    ),
    NavigationDestination(
      icon: Icon(Icons.timer_outlined, size: 26),
      selectedIcon: Icon(Icons.timer, size: 26),
      label: 'Time',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined, size: 26),
      selectedIcon: Icon(Icons.calendar_month, size: 26),
      label: 'Calendar',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined, size: 26),
      selectedIcon: Icon(Icons.bar_chart, size: 26),
      label: 'Gantt',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Navigation Rail
          Container(
            width: 88,
            color: AppColors.surface,
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.task_alt,
                    size: 28,
                    color: AppColors.background,
                  ),
                ),
                const SizedBox(height: 32),
                // Navigation items
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(_destinations.length, (index) {
                    final dest = _destinations[index];
                    final isSelected = index == _selectedIndex;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = index),
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
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isSelected
                                  ? dest.selectedIcon
                                  : dest.icon,
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              child: Text(dest.label),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const Spacer(),
                // User avatar
                GestureDetector(
                  onTap: () => _showUserProfile(context),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    child: _buildAvatarWidget(ref),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.border,
          ),
          // Content
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ProjectsScreen();
      case 2:
        return const TasksScreen();
      case 3:
        return const TimeTrackingScreen();
      case 4:
        return const CalendarScreen();
      case 5:
        return const GanttScreen();
      default:
        return const DashboardScreen();
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
        radius: 20,
        backgroundImage: FileImage(File(avatarUrl)),
        backgroundColor: AppColors.primary.withOpacity(0.2),
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primary.withOpacity(0.2),
      child: Text(
        _getUserInitials(ref),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
                                  fontWeight: FontWeight.bold,
                                ),
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
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to change avatar',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Personal Profile',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              _ProfileItem(
                icon: Icons.email_outlined,
                label: 'Email',
                value: email,
              ),
              const SizedBox(height: 12),
              _ProfileItem(
                icon: Icons.badge_outlined,
                label: 'Nickname',
                value: email.split('@').first,
              ),
              const SizedBox(height: 12),
              _ProfileItem(
                icon: Icons.info_outline,
                label: 'Version',
                value: '0.1.1',
              ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  Future<void> _pickImage(BuildContext dialogContext) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      ref.read(authStateProvider.notifier).updateAvatar(pickedFile.path);
    }
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
  });

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
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
