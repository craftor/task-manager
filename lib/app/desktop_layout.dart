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

class DesktopLayout extends StatefulWidget {
  final int selectedIndex;
  final bool sidebarExpanded;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onToggleSidebar;
  final Widget body;

  const DesktopLayout({
    super.key,
    required this.selectedIndex,
    required this.sidebarExpanded,
    required this.onIndexChanged,
    required this.onToggleSidebar,
    required this.body,
  });

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
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
          // Update banner will be added by parent
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final width = widget.sidebarExpanded ? 200.0 : 64.0;

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
          GestureDetector(
            onTap: widget.onToggleSidebar,
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
          if (widget.sidebarExpanded)
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = index == widget.selectedIndex;
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
                      onTap: () => widget.onIndexChanged(index),
                      child: widget.sidebarExpanded
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
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IconButton(
              icon: Icon(
                widget.sidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
                color: AppColors.textMuted,
                size: 22,
              ),
              onPressed: widget.onToggleSidebar,
              tooltip: widget.sidebarExpanded ? 'Collapse sidebar' : 'Expand sidebar',
            ),
          ),
        ],
      ),
    );
  }
}