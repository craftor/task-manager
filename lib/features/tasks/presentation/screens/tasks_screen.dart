import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/entities/project.dart';
import '../providers/tasks_provider.dart';
import '../../../projects/presentation/providers/projects_provider.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Tasks'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              onPressed: () => _showTaskDialog(context, ref),
            ),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) => _buildTaskList(context, ref, tasks),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => _buildErrorState(error),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          ),
          const SizedBox(height: 24),
          const Text(
            'Something went wrong',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    WidgetRef ref,
    List<Task> tasks,
  ) {
    if (tasks.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    final pendingTasks = tasks.where((t) => t.status != TaskStatus.completed).toList();
    final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          if (pendingTasks.isNotEmpty) ...[
            _buildSectionHeader('Pending', pendingTasks.length),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex--;
                // Just visual reorder for now
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final double elevation = Tween<double>(begin: 0, end: 6).evaluate(animation);
                    return Material(
                      elevation: elevation,
                      color: Colors.transparent,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              children: pendingTasks.map((task) {
                final projects = ref.watch(projectsProvider).valueOrNull ?? [];
                final defaultProject = projects.firstWhere(
                  (p) => p.isDefault,
                  orElse: () => Project(id: 'default-project', name: 'Default', color: '#808080', icon: 'folder', createdAt: DateTime.now()),
                );
                final projectName = projects.firstWhere(
                  (p) => p.id == task.projectId,
                  orElse: () => defaultProject,
                ).name;
                return _TaskCard(
                  key: ValueKey(task.id),
                  task: task,
                  projectName: projectName,
                  onTap: () => _showTaskDialog(context, ref, task),
                  onToggle: () =>
                      ref.read(tasksProvider.notifier).toggleTaskStatus(task.id),
                  onDelete: () => _confirmDelete(context, ref, task),
                );
              }).toList(),
            ),
          ],
          if (completedTasks.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Completed', completedTasks.length),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex--;
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final double elevation = Tween<double>(begin: 0, end: 6).evaluate(animation);
                    return Material(
                      elevation: elevation,
                      color: Colors.transparent,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              children: completedTasks.map((task) {
                final projects = ref.watch(projectsProvider).valueOrNull ?? [];
                final defaultProject = projects.firstWhere(
                  (p) => p.isDefault,
                  orElse: () => Project(id: 'default-project', name: 'Default', color: '#808080', icon: 'folder', createdAt: DateTime.now()),
                );
                final projectName = projects.firstWhere(
                  (p) => p.id == task.projectId,
                  orElse: () => defaultProject,
                ).name;
                return _TaskCard(
                  key: ValueKey(task.id),
                  task: task,
                  projectName: projectName,
                  onTap: () => _showTaskDialog(context, ref, task),
                  onToggle: () =>
                      ref.read(tasksProvider.notifier).toggleTaskStatus(task.id),
                  onDelete: () => _confirmDelete(context, ref, task),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No Tasks Yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Create your first task to get started',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showTaskDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create Task'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Task task) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Task?'),
        content: Text(
          'Are you sure you want to delete "${task.title}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(tasksProvider.notifier).deleteTask(task.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTaskDialog(BuildContext context, WidgetRef ref, [Task? task]) {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    final isEditing = task != null;
    Priority selectedPriority = task?.priority ?? Priority.medium;
    DateTime? startDate = task?.startDate;
    DateTime? dueDate = task?.dueDate;
    String selectedProjectId = task?.projectId ?? 'default-project';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setState) {
            final projectsAsync = ref.watch(projectsProvider);
            return Dialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEditing ? 'Edit Task' : 'New Task',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: titleController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Task Title',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          hintText: 'What needs to be done?',
                        ),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          hintText: 'Add more details...',
                        ),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Project',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      projectsAsync.when(
                        data: (projects) => _ProjectSelector(
                          projects: projects,
                          selectedProjectId: selectedProjectId,
                          onChanged: (projectId) => setState(() => selectedProjectId = projectId),
                        ),
                        loading: () => const CircularProgressIndicator(color: AppColors.primary),
                        error: (_, __) => const Text('Failed to load projects', style: TextStyle(color: AppColors.error)),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Priority',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PrioritySelector(
                        selectedPriority: selectedPriority,
                        onChanged: (priority) {
                          setState(() => selectedPriority = priority);
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Start Date',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DateTimePickerField(
                        date: startDate,
                        hintText: 'Select start date',
                        onChanged: (date) => setState(() => startDate = date),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Due Date',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DateTimePickerField(
                        date: dueDate,
                        hintText: 'Select due date',
                        onChanged: (date) => setState(() => dueDate = date),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (titleController.text.isNotEmpty) {
                                if (isEditing) {
                                  ref.read(tasksProvider.notifier).updateTask(
                                    task.copyWith(
                                      projectId: selectedProjectId,
                                      title: titleController.text,
                                      description: descController.text,
                                      priority: selectedPriority,
                                      startDate: startDate,
                                      dueDate: dueDate,
                                    ),
                                  );
                                } else {
                                  ref.read(tasksProvider.notifier).createTask(
                                    projectId: selectedProjectId,
                                    title: titleController.text,
                                    description: descController.text,
                                    priority: selectedPriority,
                                    startDate: startDate,
                                    dueDate: dueDate,
                                  );
                                }
                                Navigator.pop(dialogContext);
                              }
                            },
                            child: Text(isEditing ? 'Save' : 'Create'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final String projectName;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskCard({
    super.key,
    required this.task,
    required this.projectName,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  Color get _priorityColor {
    switch (task.priority) {
      case Priority.low:
        return AppColors.secondary;
      case Priority.medium:
        return AppColors.warning;
      case Priority.high:
        return Colors.orange;
      case Priority.urgent:
        return AppColors.error;
    }
  }

  String get _priorityLabel {
    switch (task.priority) {
      case Priority.low:
        return 'Low';
      case Priority.medium:
        return 'Medium';
      case Priority.high:
        return 'High';
      case Priority.urgent:
        return 'Urgent';
    }
  }

  bool get _isOverdue {
    if (task.dueDate == null) return false;
    return task.dueDate!.isBefore(DateTime.now());
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted ? AppColors.border.withValues(alpha: 0.5) : AppColors.border,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.success.withValues(alpha: 0.15)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted ? AppColors.success : AppColors.textMuted,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, color: AppColors.success, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.border : _priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      color: isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _DateChip(
                      icon: Icons.folder,
                      label: projectName,
                      color: AppColors.primary,
                      fontSize: 11,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _priorityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _priorityLabel,
                        style: TextStyle(
                          color: _priorityColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (task.startDate != null) ...[
                      const SizedBox(width: 6),
                      _DateChip(
                        icon: Icons.play_arrow,
                        label: _formatDateTime(task.startDate!),
                        color: AppColors.secondary,
                        fontSize: 11,
                      ),
                    ],
                    if (task.dueDate != null) ...[
                      const SizedBox(width: 6),
                      _DateChip(
                        icon: Icons.schedule,
                        label: _formatDateTime(task.dueDate!),
                        color: _isOverdue ? AppColors.error : AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double fontSize;

  const _DateChip({
    required this.icon,
    required this.label,
    required this.color,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimePickerField extends StatelessWidget {
  final DateTime? date;
  final String hintText;
  final ValueChanged<DateTime?> onChanged;

  const _DateTimePickerField({
    required this.date,
    required this.hintText,
    required this.onChanged,
  });

  Future<void> _selectDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && context.mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(date ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                surface: AppColors.surface,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        final combined = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          _roundToHalfHour(pickedTime.minute),
        );
        onChanged(combined);
      } else {
        onChanged(pickedDate);
      }
    }
  }

  int _roundToHalfHour(int minute) {
    if (minute < 15) {
      return 0;
    } else if (minute < 45) {
      return 30;
    } else {
      return 0;
    }
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $hour:$minute';
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
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: date != null ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                date != null ? _formatDateTime(date!) : hintText,
                style: TextStyle(
                  color: date != null ? AppColors.textPrimary : AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  final Priority selectedPriority;
  final ValueChanged<Priority> onChanged;

  const _PrioritySelector({
    required this.selectedPriority,
    required this.onChanged,
  });

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.low:
        return AppColors.secondary;
      case Priority.medium:
        return AppColors.warning;
      case Priority.high:
        return Colors.orange;
      case Priority.urgent:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: Priority.values.map((priority) {
        final isSelected = priority == selectedPriority;
        final color = _getPriorityColor(priority);

        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(priority),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _getPriorityIcon(priority),
                    color: isSelected ? color : AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPriorityLabel(priority),
                    style: TextStyle(
                      color: isSelected ? color : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getPriorityIcon(Priority priority) {
    switch (priority) {
      case Priority.low:
        return Icons.arrow_downward;
      case Priority.medium:
        return Icons.remove;
      case Priority.high:
        return Icons.arrow_upward;
      case Priority.urgent:
        return Icons.priority_high;
    }
  }

  String _getPriorityLabel(Priority priority) {
    switch (priority) {
      case Priority.low:
        return 'Low';
      case Priority.medium:
        return 'Medium';
      case Priority.high:
        return 'High';
      case Priority.urgent:
        return 'Urgent';
    }
  }
}

class _ProjectSelector extends StatelessWidget {
  final List<Project> projects;
  final String selectedProjectId;
  final ValueChanged<String> onChanged;

  const _ProjectSelector({
    required this.projects,
    required this.selectedProjectId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Build project list with a default option
    final projectItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: 'default',
        child: Text('Default', style: TextStyle(color: AppColors.textPrimary)),
      ),
      ...projects.map((project) {
        return DropdownMenuItem<String>(
          value: project.id,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _parseColor(project.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                project.name,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        );
      }),
    ];

    // Ensure selectedProjectId is valid or default to 'default'
    final effectiveProjectId = projectItems.any((item) => item.value == selectedProjectId)
        ? selectedProjectId
        : 'default';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveProjectId,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          items: projectItems,
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
