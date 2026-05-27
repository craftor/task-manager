import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/project.dart';
import '../../../../domain/entities/task.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../providers/projects_provider.dart';

class ProjectDetailPanel extends ConsumerWidget {
  final String? selectedProjectId;

  const ProjectDetailPanel({super.key, this.selectedProjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedProjectId == null) {
      return _EmptyState();
    }

    final projectsAsync = ref.watch(projectsProvider);
    final tasksAsync = ref.watch(tasksProvider);

    return projectsAsync.when(
      data: (projects) {
        final project = projects.where((p) => p.id == selectedProjectId).firstOrNull;
        if (project == null) {
          return _EmptyState(message: 'Project not found');
        }

        final tasks = tasksAsync.when(
          data: (allTasks) => allTasks.where((t) => t.projectId == project.id).toList(),
          loading: () => <Task>[],
          error: (_, __) => <Task>[],
        );

        return _ProjectDetailContent(
          project: project,
          tasks: tasks,
          onEdit: () => _showEditDialog(context, ref, project),
          onDelete: () => _confirmDelete(context, ref, project),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => Center(
        child: Text('Error: $error', style: const TextStyle(color: AppColors.error)),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Project project) {
    final nameController = TextEditingController(text: project.name);
    final descController = TextEditingController(text: project.description ?? '');
    String selectedColor = project.color;
    String selectedIcon = project.icon;
    DateTime? startDate = project.startDate;
    DateTime? endDate = project.endDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (st, setSt) {
          return Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Edit Project', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w600)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 24),
                  TextField(controller: nameController, autofocus: true,
                    decoration: const InputDecoration(labelText: 'Project Name', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                  const SizedBox(height: 16),
                  TextField(controller: descController, maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                  const SizedBox(height: 24),
                  const Text('Icon', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  _IconPicker(selectedIcon: selectedIcon, selectedColor: selectedColor,
                    onIconSelected: (icon) => setSt(() => selectedIcon = icon)),
                  const SizedBox(height: 16),
                  const Text('Color', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  _ColorPicker(selectedColor: selectedColor,
                    onColorSelected: (color) => setSt(() => selectedColor = color)),
                  const SizedBox(height: 24),
                  const Text('Start Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  _DatePickerField(date: startDate, hintText: 'Select start date',
                    onChanged: (d) => setSt(() => startDate = d)),
                  const SizedBox(height: 16),
                  const Text('End Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  _DatePickerField(date: endDate, hintText: 'Select end date',
                    onChanged: (d) => setSt(() => endDate = d)),
                  const SizedBox(height: 32),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 12),
                    ElevatedButton(onPressed: () {
                      if (nameController.text.isNotEmpty) {
                        ref.read(projectsProvider.notifier).updateProject(
                          project.copyWith(name: nameController.text, description: descController.text.isEmpty ? null : descController.text,
                            color: selectedColor, icon: selectedIcon, startDate: startDate, endDate: endDate),
                        );
                        Navigator.pop(ctx);
                      }
                    }, child: const Text('Save')),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Project project) {
    if (project.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete default project'), backgroundColor: AppColors.error),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Project?'),
        content: Text('Delete "${project.name}"?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(projectsProvider.notifier).deleteProject(project.id);
              ref.read(selectedProjectIdProvider.notifier).state = null;
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({this.message = 'Select a project to view details'});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _ProjectDetailContent extends StatelessWidget {
  final Project project;
  final List<Task> tasks;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProjectDetailContent({
    required this.project,
    required this.tasks,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _projectColor {
    try { return Color(int.parse(project.color.replaceFirst('#', '0xFF'))); }
    catch (_) { return AppColors.primary; }
  }

  IconData get _projectIcon {
    const iconMap = {
      'folder': Icons.folder_rounded, 'work': Icons.work_rounded, 'star': Icons.star_rounded,
      'favorite': Icons.favorite_rounded, 'bookmark': Icons.bookmark_rounded, 'code': Icons.code_rounded,
      'build': Icons.build_rounded, 'home': Icons.home_rounded, 'shopping': Icons.shopping_cart_rounded,
      'school': Icons.school_rounded, 'fitness': Icons.fitness_center_rounded, 'travel': Icons.flight_rounded,
      'music': Icons.music_note_rounded, 'photo': Icons.photo_rounded, 'movie': Icons.movie_rounded,
      'game': Icons.games_rounded, 'sports': Icons.sports_soccer_rounded, 'health': Icons.health_and_safety_rounded,
      'science': Icons.science_rounded, 'business': Icons.business_center_rounded,
    };
    return iconMap[project.icon] ?? Icons.folder_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final pending = tasks.where((t) => t.status != TaskStatus.completed).length;
    final completed = tasks.where((t) => t.status == TaskStatus.completed).length;

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: _projectColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: Icon(_projectIcon, color: _projectColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(project.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
                if (project.isDefault) const Text('Default project', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ])),
              IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary), onPressed: onEdit),
              if (!project.isDefault)
                IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: onDelete),
            ]),
            const SizedBox(height: 24),

            // Stats
            Row(children: [
              _StatChip(label: 'Total', value: tasks.length.toString(), color: AppColors.primary),
              const SizedBox(width: 8),
              _StatChip(label: 'Pending', value: pending.toString(), color: AppColors.warning),
              const SizedBox(width: 8),
              _StatChip(label: 'Done', value: completed.toString(), color: AppColors.success),
            ]),
            const SizedBox(height: 24),

            // Description
            if (project.description != null && project.description!.isNotEmpty) ...[
              const Text('Description', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Text(project.description!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5)),
              ),
              const SizedBox(height: 24),
            ],

            // Dates
            if (project.startDate != null || project.endDate != null) ...[
              const Text('Dates', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(children: [
                  if (project.startDate != null) _DateRow(label: 'Start', date: project.startDate!),
                  if (project.startDate != null && project.endDate != null) const SizedBox(height: 8),
                  if (project.endDate != null) _DateRow(label: 'End', date: project.endDate!),
                ]),
              ),
              const SizedBox(height: 24),
            ],

            // Task list
            if (tasks.isNotEmpty) ...[
              Text('Tasks (${tasks.length})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              ...tasks.map((t) => _MiniTaskCard(task: t)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime date;

  const _DateRow({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _MiniTaskCard extends StatelessWidget {
  final Task task;

  const _MiniTaskCard({required this.task});

  Color get _priorityColor {
    switch (task.priority) {
      case Priority.low: return AppColors.secondary;
      case Priority.medium: return AppColors.warning;
      case Priority.high: return Colors.orange;
      case Priority.urgent: return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 4, height: 24, decoration: BoxDecoration(color: done ? AppColors.border : _priorityColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(task.title, style: TextStyle(color: done ? AppColors.textMuted : AppColors.textPrimary, fontSize: 14,
          decoration: done ? TextDecoration.lineThrough : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (task.dueDate != null) ...[
          const SizedBox(width: 8),
          Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 2),
          Text('${task.dueDate!.day}/${task.dueDate!.month}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ]),
    );
  }
}

class _IconPicker extends StatelessWidget {
  final String selectedIcon;
  final String selectedColor;
  final ValueChanged<String> onIconSelected;

  const _IconPicker({required this.selectedIcon, required this.selectedColor, required this.onIconSelected});

  static const _icons = {
    'folder': Icons.folder_rounded, 'work': Icons.work_rounded, 'star': Icons.star_rounded,
    'favorite': Icons.favorite_rounded, 'bookmark': Icons.bookmark_rounded, 'code': Icons.code_rounded,
    'build': Icons.build_rounded, 'home': Icons.home_rounded, 'shopping': Icons.shopping_cart_rounded,
    'school': Icons.school_rounded, 'fitness': Icons.fitness_center_rounded, 'travel': Icons.flight_rounded,
    'music': Icons.music_note_rounded, 'photo': Icons.photo_rounded, 'movie': Icons.movie_rounded,
    'game': Icons.games_rounded, 'sports': Icons.sports_soccer_rounded, 'health': Icons.health_and_safety_rounded,
    'science': Icons.science_rounded, 'business': Icons.business_center_rounded,
  };

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    try { iconColor = Color(int.parse(selectedColor.replaceFirst('#', '0xFF'))); }
    catch (_) { iconColor = AppColors.primary; }
    return Wrap(spacing: 8, runSpacing: 8, children: _icons.entries.map((e) {
      final sel = e.key == selectedIcon;
      return GestureDetector(
        onTap: () => onIconSelected(e.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: sel ? iconColor.withValues(alpha: 0.2) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: sel ? Border.all(color: iconColor, width: 2) : null,
          ),
          child: Icon(e.value, color: sel ? iconColor : AppColors.textMuted, size: 22),
        ),
      );
    }).toList());
  }
}

class _ColorPicker extends StatelessWidget {
  final String selectedColor;
  final ValueChanged<String> onColorSelected;

  const _ColorPicker({required this.selectedColor, required this.onColorSelected});

  static const _colors = ['#00ff9f', '#00d4ff', '#ff4757', '#ffcc00', '#ff6b81', '#7bed9f', '#a55eea', '#f368e0'];

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: _colors.map((color) {
      final isSelected = color == selectedColor;
      final c = Color(int.parse(color.replaceFirst('#', '0xFF')));
      return GestureDetector(
        onTap: () => onColorSelected(color),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: c, shape: BoxShape.circle,
            border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
            boxShadow: isSelected ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)] : null,
          ),
          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
        ),
      );
    }).toList());
  }
}

class _DatePickerField extends StatelessWidget {
  final DateTime? date;
  final String hintText;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({required this.date, required this.hintText, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            date != null ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}' : hintText,
            style: TextStyle(color: date != null ? AppColors.textPrimary : AppColors.textMuted, fontSize: 14),
          ),
        ]),
      ),
    );
  }
}