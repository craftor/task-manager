import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class _NavItem {
  final IconData outline;
  final IconData selected;
  final String label;
  const _NavItem(this.outline, this.selected, this.label);
}

const _navItems = [
  _NavItem(Icons.edit_note_outlined, Icons.edit_note, 'Journal'),
  _NavItem(Icons.task_alt_outlined, Icons.task_alt, 'Tasks'),
  _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
  _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar'),
  _NavItem(Icons.emoji_emotions_outlined, Icons.emoji_emotions, 'Mood'),
  _NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome, 'Dates'),
  _NavItem(Icons.settings_outlined, Icons.settings, 'Settings'),
  _NavItem(Icons.person_outline, Icons.person, 'Profile'),
];

class MobileLayout extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget body;
  final Widget? updateBanner;

  const MobileLayout({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.body,
    this.updateBanner,
  });

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  String _getUserInitials(String? email) {
    if (email == null || email.isEmpty) return '?';
    final parts = email.split('@');
    return parts[0].substring(0, parts[0].length > 2 ? 2 : 1).toUpperCase();
  }

  Widget _buildAvatarWidget(String? avatarUrl, String? email) {
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
        _getUserInitials(email),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          if (widget.updateBanner != null) widget.updateBanner!,
        ],
      ),
      drawer: _buildDrawer(context),
      body: widget.body,
    );
  }

  Widget _buildDrawer(BuildContext context) {
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
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = index == widget.selectedIndex;

                return GestureDetector(
                  onTap: () {
                    setState(() {});
                    widget.onIndexChanged(index);
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
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              widget.onIndexChanged(7);
            },
            child: Container(
              margin: const EdgeInsets.all(12),
              child: _buildAvatarWidget(null, null),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}