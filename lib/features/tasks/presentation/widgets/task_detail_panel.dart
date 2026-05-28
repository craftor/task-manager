import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/entities/project.dart';
import '../providers/tasks_provider.dart';
import '../../../projects/presentation/providers/projects_provider.dart';

class TaskDetailPanel extends ConsumerWidget {
  final String? selectedTaskId;

  const TaskDetailPanel({super.key, this.selectedTaskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedTaskId == null) {
      return _EmptyState();
    }

    final tasksAsync = ref.watch(tasksProvider);
    final projectsAsync = ref.watch(projectsProvider);

    return tasksAsync.when(
      data: (tasks) {
        final task = tasks.where((t) => t.id == selectedTaskId).firstOrNull;
        if (task == null) {
          return _EmptyState(message: 'Task not found');
        }

        final projects = projectsAsync.valueOrNull ?? [];
        final defaultProject = Project(
          id: AppConstants.defaultProjectId,
          name: 'Default',
          color: '#808080',
          icon: 'folder',
          createdAt: DateTime.now(),
        );
        final projectName = projects
            .firstWhere(
              (p) => p.id == task.projectId,
              orElse: () => defaultProject,
            )
            .name;

        return _TaskDetailContent(
          task: task,
          projectName: projectName,
          onEdit: () => _showEditDialog(context, ref, task),
          onDelete: () => _confirmDelete(context, ref, task),
          onToggle: () => ref.read(tasksProvider.notifier).toggleTaskStatus(task.id),
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

  void _showEditDialog(BuildContext context, WidgetRef ref, Task task) {
    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description);
    Priority selectedPriority = task.priority;
    DateTime? startDate = task.startDate;
    DateTime? dueDate = task.dueDate;
    String selectedProjectId = task.projectId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (st, setSt) {
          final projectsAsync = ref.watch(projectsProvider);
          return Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Edit Task', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w600)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 24),
                  TextField(controller: titleController, autofocus: true,
                    decoration: const InputDecoration(labelText: 'Task Title', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                  const SizedBox(height: 16),
                  TextField(controller: descController, maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                  const SizedBox(height: 24),
                  const Text('Project', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  projectsAsync.when(
                    data: (projects) => _ProjectSelector(projects: projects, selectedProjectId: selectedProjectId,
                      onChanged: (id) => setSt(() => selectedProjectId = id)),
                    loading: () => const CircularProgressIndicator(color: AppColors.primary),
                    error: (_, __) => const Text('Failed', style: TextStyle(color: AppColors.error))),
                  const SizedBox(height: 24),
                  const Text('Priority', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  _PrioritySelector(selectedPriority: selectedPriority, onChanged: (p) => setSt(() => selectedPriority = p)),
                  const SizedBox(height: 24),
                  const Text('Start Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  _DateTimePickerField(date: startDate, hintText: 'Select start date', onChanged: (d) => setSt(() => startDate = d)),
                  const SizedBox(height: 24),
                  const Text('Due Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  _DateTimePickerField(date: dueDate, hintText: 'Select due date', onChanged: (d) => setSt(() => dueDate = d)),
                  const SizedBox(height: 32),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 12),
                    ElevatedButton(onPressed: () {
                      if (titleController.text.isNotEmpty) {
                        ref.read(tasksProvider.notifier).updateTask(task.copyWith(
                          projectId: selectedProjectId, title: titleController.text,
                          description: descController.text, priority: selectedPriority,
                          startDate: startDate, dueDate: dueDate,
                        ));
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

  void _confirmDelete(BuildContext context, WidgetRef ref, Task task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Task?'),
        content: Text('Delete "${task.title}"?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(tasksProvider.notifier).deleteTask(task.id);
              ref.read(selectedTaskIdProvider.notifier).state = null;
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

  const _EmptyState({this.message = 'Select a task to view details'});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _TaskDetailContent extends StatelessWidget {
  final Task task;
  final String projectName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _TaskDetailContent({
    required this.task,
    required this.projectName,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  Color get _priorityColor {
    switch (task.priority) {
      case Priority.low: return AppColors.secondary;
      case Priority.medium: return AppColors.warning;
      case Priority.high: return Colors.orange;
      case Priority.urgent: return AppColors.error;
    }
  }

  String get _priorityLabel {
    switch (task.priority) {
      case Priority.low: return 'Low';
      case Priority.medium: return 'Medium';
      case Priority.high: return 'High';
      case Priority.urgent: return 'Urgent';
    }
  }

  bool get _isOverdue => task.dueDate != null && task.dueDate!.isBefore(DateTime.now()) && task.status != TaskStatus.completed;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.success.withValues(alpha: 0.15) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: isCompleted ? AppColors.success : AppColors.textMuted, width: 2),
                  ),
                  child: isCompleted ? const Icon(Icons.check, color: AppColors.success, size: 18) : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    color: isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary), onPressed: onEdit),
              IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: onDelete),
            ]),
            const SizedBox(height: 24),

            // Project & Priority chips
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Chip(icon: Icons.folder_outlined, label: projectName, color: AppColors.primary),
              _Chip(icon: Icons.flag_outlined, label: _priorityLabel, color: _priorityColor),
              if (isCompleted) _Chip(icon: Icons.check_circle_outlined, label: 'Completed', color: AppColors.success),
              if (_isOverdue) _Chip(icon: Icons.warning_outlined, label: 'Overdue', color: AppColors.error),
            ]),
            const SizedBox(height: 24),

            // Description
            if (task.description.isNotEmpty) ...[
              const Text('Description', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(task.description, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5)),
              ),
              const SizedBox(height: 24),
            ],

            // Dates
            if (task.startDate != null || task.dueDate != null) ...[
              const Text('Dates', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(children: [
                  if (task.startDate != null) _DateRow(label: 'Start', date: task.startDate!, color: AppColors.secondary),
                  if (task.startDate != null && task.dueDate != null) const SizedBox(height: 8),
                  if (task.dueDate != null) _DateRow(label: 'Due', date: task.dueDate!, color: _isOverdue ? AppColors.error : AppColors.textPrimary),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final Color color;

  const _DateRow({required this.label, required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      Text(
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ]);
  }
}

class _DateTimePickerField extends StatelessWidget {
  final DateTime? date;
  final String hintText;
  final ValueChanged<DateTime?> onChanged;

  const _DateTimePickerField({required this.date, required this.hintText, required this.onChanged});

  Future<void> _selectDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (pickedDate != null && context.mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(date ?? DateTime.now()),
      );
      if (pickedTime != null) {
        onChanged(DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute));
      } else {
        onChanged(pickedDate);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _selectDateTime(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today, size: 18, color: date != null ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(
            date != null ? '${date!.day}/${date!.month}/${date!.year} ${date!.hour.toString().padLeft(2, '0')}:${date!.minute.toString().padLeft(2, '0')}' : hintText,
            style: TextStyle(color: date != null ? AppColors.textPrimary : AppColors.textMuted, fontSize: 14),
          )),
          if (date != null) GestureDetector(onTap: () => onChanged(null), child: const Icon(Icons.close, size: 18, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  final Priority selectedPriority;
  final ValueChanged<Priority> onChanged;

  const _PrioritySelector({required this.selectedPriority, required this.onChanged});

  Color _getColor(Priority p) { switch (p) { case Priority.low: return AppColors.secondary; case Priority.medium: return AppColors.warning; case Priority.high: return Colors.orange; case Priority.urgent: return AppColors.error; } }
  IconData _getIcon(Priority p) { switch (p) { case Priority.low: return Icons.arrow_downward; case Priority.medium: return Icons.remove; case Priority.high: return Icons.arrow_upward; case Priority.urgent: return Icons.priority_high; } }
  String _getLabel(Priority p) { switch (p) { case Priority.low: return 'Low'; case Priority.medium: return 'Medium'; case Priority.high: return 'High'; case Priority.urgent: return 'Urgent'; } }

  @override
  Widget build(BuildContext context) {
    return Row(children: Priority.values.map((p) {
      final sel = p == selectedPriority;
      final color = _getColor(p);
      return Expanded(child: GestureDetector(
        onTap: () => onChanged(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? color : AppColors.border, width: sel ? 2 : 1),
          ),
          child: Column(children: [
            Icon(_getIcon(p), color: sel ? color : AppColors.textMuted, size: 20),
            const SizedBox(height: 4),
            Text(_getLabel(p), style: TextStyle(color: sel ? color : AppColors.textMuted, fontSize: 11, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
          ]),
        ),
      ));
    }).toList());
  }
}

class _ProjectSelector extends StatelessWidget {
  final List<Project> projects;
  final String selectedProjectId;
  final ValueChanged<String> onChanged;

  const _ProjectSelector({required this.projects, required this.selectedProjectId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedProjectId,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          items: projects.map<DropdownMenuItem<String>>((p) {
            return DropdownMenuItem<String>(
              value: p.id,
              child: Row(children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(
                  color: _parseColor(p.color), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(p.name, style: const TextStyle(color: AppColors.textPrimary)),
              ]),
            );
          }).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try { return Color(int.parse(colorStr.replaceFirst('#', '0xFF'))); }
    catch (_) { return AppColors.primary; }
  }
}