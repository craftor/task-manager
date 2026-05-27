import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/master_detail_layout.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/entities/project.dart';
import '../providers/tasks_provider.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../widgets/task_detail_panel.dart';

enum TaskFilter { all, pending, completed, highPriority, overdue }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TaskFilter _filter = TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Tasks'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          PopupMenuButton<TaskFilter>(
            icon: const Icon(Icons.filter_list, color: AppColors.textPrimary),
            color: AppColors.surface,
            onSelected: (filter) => setState(() => _filter = filter),
            itemBuilder: (context) => [
              PopupMenuItem(value: TaskFilter.all, child: _FilterMenuItem(icon: Icons.list, label: 'All Tasks', isSelected: _filter == TaskFilter.all)),
              PopupMenuItem(value: TaskFilter.pending, child: _FilterMenuItem(icon: Icons.pending_actions, label: 'Pending', isSelected: _filter == TaskFilter.pending)),
              PopupMenuItem(value: TaskFilter.completed, child: _FilterMenuItem(icon: Icons.check_circle, label: 'Completed', isSelected: _filter == TaskFilter.completed)),
              PopupMenuItem(value: TaskFilter.highPriority, child: _FilterMenuItem(icon: Icons.priority_high, label: 'High Priority', isSelected: _filter == TaskFilter.highPriority)),
              PopupMenuItem(value: TaskFilter.overdue, child: _FilterMenuItem(icon: Icons.warning, label: 'Overdue', isSelected: _filter == TaskFilter.overdue)),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: IconButton(icon: const Icon(Icons.add, color: AppColors.primary), onPressed: () => _showTaskDialog(context, ref)),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isDesktop = screenWidth >= AppConstants.sidebarBreakpoint;
          final selectedTaskId = ref.watch(selectedTaskIdProvider);

          final taskList = _buildTaskList(context, ref, tasks);

          if (isDesktop) {
            return MasterDetailLayout(
              masterPane: taskList,
              detailPane: selectedTaskId != null
                  ? TaskDetailPanel(selectedTaskId: selectedTaskId)
                  : null,
              onCloseDetail: () => ref.read(selectedTaskIdProvider.notifier).state = null,
            );
          }
          return taskList;
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, stack) => _buildErrorState(error),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.error_outline, size: 48, color: AppColors.error)),
      const SizedBox(height: 24),
      const Text('Something went wrong', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(error.toString(), style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]));
  }

  Widget _buildTaskList(BuildContext context, WidgetRef ref, List<Task> tasks) {
    final now = DateTime.now();
    final filteredTasks = tasks.where((t) {
      switch (_filter) {
        case TaskFilter.all: return true;
        case TaskFilter.pending: return t.status != TaskStatus.completed;
        case TaskFilter.completed: return t.status == TaskStatus.completed;
        case TaskFilter.highPriority: return t.priority == Priority.high || t.priority == Priority.urgent;
        case TaskFilter.overdue: return t.dueDate != null && t.dueDate!.isBefore(now) && t.status != TaskStatus.completed;
      }
    }).toList();

    if (filteredTasks.isEmpty) return _buildEmptyState(context, ref);

    final pendingTasks = filteredTasks.where((t) => t.status != TaskStatus.completed).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final completedTasks = filteredTasks.where((t) => t.status == TaskStatus.completed).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return SingleChildScrollView(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [
      if (pendingTasks.isNotEmpty) ...[
        _buildSectionHeader('Pending', pendingTasks.length),
        ReorderableListView(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) { ref.read(tasksProvider.notifier).reorderTasks(pendingTasks, oldIndex, newIndex); },
          proxyDecorator: (child, index, animation) {
            final double elevation = Tween<double>(begin: 0, end: 6).evaluate(animation);
            return Material(elevation: elevation, color: Colors.transparent, shadowColor: AppColors.primary.withValues(alpha: 0.3), child: child);
          },
          children: pendingTasks.map((task) {
            final projects = ref.watch(projectsProvider).valueOrNull ?? [];
            final defaultProject = projects.firstWhere((p) => p.isDefault, orElse: () => Project(id: AppConstants.defaultProjectId, name: 'Default', color: '#808080', icon: 'folder', createdAt: DateTime.now()));
            final projectName = projects.firstWhere((p) => p.id == task.projectId, orElse: () => defaultProject).name;
            return _TaskCard(key: ValueKey(task.id), task: task, projectName: projectName,
                onTap: () {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isDesktop = screenWidth >= AppConstants.sidebarBreakpoint;
                  if (isDesktop) {
                    ref.read(selectedTaskIdProvider.notifier).state = task.id;
                  } else {
                    _showTaskDialog(context, ref, task);
                  }
                },
                onToggle: () => ref.read(tasksProvider.notifier).toggleTaskStatus(task.id),
                onDelete: () => _confirmDelete(context, ref, task));
          }).toList(),
        ),
      ],
      if (completedTasks.isNotEmpty) ...[
        const SizedBox(height: 24),
        _buildSectionHeader('Completed', completedTasks.length),
        ReorderableListView(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) { ref.read(tasksProvider.notifier).reorderTasks(completedTasks, oldIndex, newIndex); },
          proxyDecorator: (child, index, animation) {
            final double elevation = Tween<double>(begin: 0, end: 6).evaluate(animation);
            return Material(elevation: elevation, color: Colors.transparent, shadowColor: AppColors.primary.withValues(alpha: 0.3), child: child);
          },
          children: completedTasks.map((task) {
            final projects = ref.watch(projectsProvider).valueOrNull ?? [];
            final defaultProject = projects.firstWhere((p) => p.isDefault, orElse: () => Project(id: AppConstants.defaultProjectId, name: 'Default', color: '#808080', icon: 'folder', createdAt: DateTime.now()));
            final projectName = projects.firstWhere((p) => p.id == task.projectId, orElse: () => defaultProject).name;
            return _TaskCard(key: ValueKey(task.id), task: task, projectName: projectName,
                onTap: () {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isDesktop = screenWidth >= AppConstants.sidebarBreakpoint;
                  if (isDesktop) {
                    ref.read(selectedTaskIdProvider.notifier).state = task.id;
                  } else {
                    _showTaskDialog(context, ref, task);
                  }
                },
                onToggle: () => ref.read(tasksProvider.notifier).toggleTaskStatus(task.id),
                onDelete: () => _confirmDelete(context, ref, task));
          }).toList(),
        ),
      ],
      const SizedBox(height: 80),
    ]));
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Row(children: [
      Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
      const SizedBox(width: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(count.toString(), style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600))),
    ]));
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    String message = 'Create your first task to get started';
    switch (_filter) {
      case TaskFilter.all: message = 'Create your first task to get started'; break;
      case TaskFilter.pending: message = 'No pending tasks'; break;
      case TaskFilter.completed: message = 'No completed tasks'; break;
      case TaskFilter.highPriority: message = 'No high priority tasks'; break;
      case TaskFilter.overdue: message = 'No overdue tasks'; break;
    }
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 120, height: 120, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(_getEmptyIcon(), size: 64, color: AppColors.primary)),
      const SizedBox(height: 32),
      const Text('No Tasks Yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
      const SizedBox(height: 32),
      ElevatedButton.icon(onPressed: () => _showTaskDialog(context, ref), icon: const Icon(Icons.add), label: const Text('Create Task')),
    ]));
  }

  IconData _getEmptyIcon() {
    switch (_filter) {
      case TaskFilter.all: return Icons.task_alt;
      case TaskFilter.pending: return Icons.pending_actions;
      case TaskFilter.completed: return Icons.check_circle;
      case TaskFilter.highPriority: return Icons.priority_high;
      case TaskFilter.overdue: return Icons.warning;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Task task) {
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: AppColors.surface,
      title: const Text('Delete Task?'),
      content: Text('Are you sure you want to delete "${task.title}"?', style: const TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); ref.read(tasksProvider.notifier).deleteTask(task.id); },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), child: const Text('Delete')),
      ]));
  }

  void _showTaskDialog(BuildContext context, WidgetRef ref, [Task? task]) {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    final isEditing = task != null;
    Priority selectedPriority = task?.priority ?? Priority.medium;
    DateTime? startDate = task?.startDate ?? DateTime.now();
    DateTime? dueDate = task?.dueDate;
    String selectedProjectId = task?.projectId ?? AppConstants.defaultProjectId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (st, setSt) {
      final projectsAsync = ref.watch(projectsProvider);
      return Dialog(backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(isEditing ? 'Edit Task' : 'New Task', style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w600)),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 24),
            TextField(controller: titleController, autofocus: true,
              decoration: const InputDecoration(labelText: 'Task Title', labelStyle: TextStyle(color: AppColors.textSecondary), hintText: 'What needs to be done?'),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(controller: descController, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description (optional)', labelStyle: TextStyle(color: AppColors.textSecondary), hintText: 'Add more details...'),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
            const SizedBox(height: 24),
            const Text('Project', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            projectsAsync.when(
              data: (projects) => _ProjectSelector(projects: projects, selectedProjectId: selectedProjectId, onChanged: (projectId) => setSt(() => selectedProjectId = projectId)),
              loading: () => const CircularProgressIndicator(color: AppColors.primary),
              error: (_, __) => const Text('Failed to load projects', style: TextStyle(color: AppColors.error))),
            const SizedBox(height: 24),
            const Text('Priority', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            _PrioritySelector(selectedPriority: selectedPriority, onChanged: (priority) => setSt(() => selectedPriority = priority)),
            const SizedBox(height: 24),
            const Text('Start Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            _DateTimePickerField(date: startDate, hintText: 'Select start date', onChanged: (date) => setSt(() => startDate = date)),
            const SizedBox(height: 24),
            const Text('Due Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            _DateTimePickerField(date: dueDate, hintText: 'Select due date', onChanged: (date) => setSt(() => dueDate = date)),
            const SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: () {
                if (titleController.text.isNotEmpty) {
                  if (isEditing) {
                    ref.read(tasksProvider.notifier).updateTask(task.copyWith(projectId: selectedProjectId, title: titleController.text, description: descController.text, priority: selectedPriority, startDate: startDate, dueDate: dueDate));
                  } else {
                    ref.read(tasksProvider.notifier).createTask(projectId: selectedProjectId, title: titleController.text, description: descController.text, priority: selectedPriority, startDate: startDate, dueDate: dueDate);
                  }
                  Navigator.pop(ctx);
                }
              }, child: Text(isEditing ? 'Save' : 'Create')),
            ]),
          ])),
        ),
      );
    }));
  }
}

// ─── Adaptive TaskCard ───
class _TaskCard extends StatelessWidget {
  final Task task;
  final String projectName;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskCard({super.key, required this.task, required this.projectName, required this.onTap, required this.onToggle, required this.onDelete});

  Color get _priorityColor { switch (task.priority) { case Priority.low: return AppColors.secondary; case Priority.medium: return AppColors.warning; case Priority.high: return Colors.orange; case Priority.urgent: return AppColors.error; } }
  String get _priorityFull { switch (task.priority) { case Priority.low: return 'Low'; case Priority.medium: return 'Medium'; case Priority.high: return 'High'; case Priority.urgent: return 'Urgent'; } }
  String get _priorityAbbr { switch (task.priority) { case Priority.low: return 'L'; case Priority.medium: return 'M'; case Priority.high: return 'H'; case Priority.urgent: return 'U'; } }
  bool get _isOverdue => task.dueDate != null && task.dueDate!.isBefore(DateTime.now());
  String _fmtFull(DateTime dt) => '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext ctx) {
    final done = task.status == TaskStatus.completed;

    return Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(color: AppColors.surface, borderRadius: BorderRadius.circular(14),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: done ? AppColors.border.withValues(alpha: 0.5) : AppColors.border)),
            child: LayoutBuilder(builder: (c, cs) {
                            final wide = cs.maxWidth > AppConstants.compactBreakpoint;

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Row 1: checkbox + color bar + title + (desktop: chips) + delete
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  GestureDetector(
                    onTap: onToggle,
                    child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 22, height: 22,
                      decoration: BoxDecoration(color: done ? AppColors.success.withValues(alpha: 0.15) : Colors.transparent, shape: BoxShape.circle,
                        border: Border.all(color: done ? AppColors.success : AppColors.textMuted, width: 2)),
                      child: done ? const Icon(Icons.check, color: AppColors.success, size: 14) : null)),
                  const SizedBox(width: 8),
                  Container(width: 3, height: 22, decoration: BoxDecoration(color: done ? AppColors.border : _priorityColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(task.title, style: TextStyle(color: done ? AppColors.textMuted : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600, decoration: done ? TextDecoration.lineThrough : null), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  // Desktop: inline chips
                  if (wide) ...[
                    const SizedBox(width: 8),
                    Text(projectName, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: _priorityColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                      child: Text(_priorityFull, style: TextStyle(color: _priorityColor, fontSize: 10, fontWeight: FontWeight.w600))),
                    if (task.startDate != null) ...[const SizedBox(width: 6), Text(_fmtFull(task.startDate!), style: const TextStyle(color: AppColors.secondary, fontSize: 10))],
                    if (task.dueDate != null) ...[const SizedBox(width: 6), Text(_fmtFull(task.dueDate!), style: TextStyle(color: _isOverdue ? AppColors.error : AppColors.textMuted, fontSize: 10))],
                  ],
                  const SizedBox(width: 4),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.textMuted), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ]),
                // Row 2 (mobile only): condensed info line
                if (!wide)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 38),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: projectName, style: const TextStyle(color: AppColors.primary, fontSize: 10)),
                      const TextSpan(text: ' · ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      TextSpan(text: _priorityAbbr, style: TextStyle(color: _priorityColor, fontSize: 10, fontWeight: FontWeight.w600)),
                      if (task.startDate != null) ...[
                        const TextSpan(text: ' · ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        TextSpan(text: _fmtFull(task.startDate!), style: const TextStyle(color: AppColors.secondary, fontSize: 10)),
                      ],
                      if (task.dueDate != null) ...[
                        const TextSpan(text: ' · ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        TextSpan(text: _fmtFull(task.dueDate!), style: TextStyle(color: _isOverdue ? AppColors.error : AppColors.textMuted, fontSize: 10)),
                      ],
                    ])),
                  ),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

class _DateTimePickerField extends StatelessWidget {
  final DateTime? date;
  final String hintText;
  final ValueChanged<DateTime?> onChanged;
  const _DateTimePickerField({required this.date, required this.hintText, required this.onChanged});

  Future<void> _selectDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(context: context, initialDate: date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface)), child: child!));

    if (pickedDate != null && context.mounted) {
      final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(date ?? DateTime.now()),
        builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface)), child: child!));

      if (pickedTime != null) {
        int adjustedHour = pickedTime.hour;
        int adjustedMinute = _roundToHalfHour(pickedTime.minute);
        if (adjustedMinute == 0 && pickedTime.minute >= 45) {
          adjustedHour = (adjustedHour + 1) % 24;
        }
        onChanged(DateTime(pickedDate.year, pickedDate.month, pickedDate.day, adjustedHour, adjustedMinute));
      } else {
        onChanged(pickedDate);
      }
    }
  }

  int _roundToHalfHour(int minute) { if (minute < 15) return 0; if (minute < 45) return 30; return 0; }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => _selectDateTime(context),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(Icons.calendar_today, size: 18, color: date != null ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(date != null ? _formatDateTime(date!) : hintText, style: TextStyle(color: date != null ? AppColors.textPrimary : AppColors.textMuted, fontSize: 14))),
          if (date != null) GestureDetector(onTap: () => onChanged(null), child: const Icon(Icons.close, size: 18, color: AppColors.textMuted)),
        ])));
  }
}

class _PrioritySelector extends StatelessWidget {
  final Priority selectedPriority;
  final ValueChanged<Priority> onChanged;
  const _PrioritySelector({required this.selectedPriority, required this.onChanged});

  Color _getPriorityColor(Priority priority) { switch (priority) { case Priority.low: return AppColors.secondary; case Priority.medium: return AppColors.warning; case Priority.high: return Colors.orange; case Priority.urgent: return AppColors.error; } }

  @override
  Widget build(BuildContext context) {
    return Row(children: Priority.values.map((priority) {
      final isSelected = priority == selectedPriority;
      final color = _getPriorityColor(priority);
      return Expanded(child: GestureDetector(onTap: () => onChanged(priority),
        child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : AppColors.border, width: isSelected ? 2 : 1)),
          child: Column(children: [
            Icon(_getPriorityIcon(priority), color: isSelected ? color : AppColors.textMuted, size: 20),
            const SizedBox(height: 4),
            Text(_getPriorityLabel(priority), style: TextStyle(color: isSelected ? color : AppColors.textMuted, fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ]))));
    }).toList());
  }

  IconData _getPriorityIcon(Priority priority) { switch (priority) { case Priority.low: return Icons.arrow_downward; case Priority.medium: return Icons.remove; case Priority.high: return Icons.arrow_upward; case Priority.urgent: return Icons.priority_high; } }
  String _getPriorityLabel(Priority priority) { switch (priority) { case Priority.low: return 'Low'; case Priority.medium: return 'Medium'; case Priority.high: return 'High'; case Priority.urgent: return 'Urgent'; } }
}

class _FilterMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  const _FilterMenuItem({required this.icon, required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 20, color: isSelected ? AppColors.primary : AppColors.textSecondary),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      if (isSelected) ...[const Spacer(), const Icon(Icons.check, size: 18, color: AppColors.primary)],
    ]);
  }
}

class _ProjectSelector extends StatelessWidget {
  final List<Project> projects;
  final String selectedProjectId;
  final ValueChanged<String> onChanged;
  const _ProjectSelector({required this.projects, required this.selectedProjectId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final projectItems = <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(value: AppConstants.defaultProjectId, child: const Text('Default', style: TextStyle(color: AppColors.textPrimary))),
      ...projects.map((project) => DropdownMenuItem<String>(value: project.id, child: Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: _parseColor(project.color), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(project.name, style: const TextStyle(color: AppColors.textPrimary)),
      ]))),
    ];

    final effectiveProjectId = projectItems.any((item) => item.value == selectedProjectId) ? selectedProjectId : AppConstants.defaultProjectId;

    return Container(padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: effectiveProjectId, isExpanded: true, dropdownColor: AppColors.surface, items: projectItems,
        onChanged: (value) { if (value != null) onChanged(value); })));
  }

  Color _parseColor(String colorStr) { try { return Color(int.parse(colorStr.replaceFirst('#', '0xFF'))); } catch (_) { return AppColors.primary; } }
}
