import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../domain/entities/task.dart' show Priority;
import 'package:task_manager/features/tasks/presentation/screens/tasks_screen.dart';
import 'package:task_manager/features/tasks/presentation/providers/tasks_provider.dart';
import '../presentation/screens/projects_screen.dart';
import '../presentation/providers/projects_provider.dart';

class TasksProjectsScreen extends ConsumerStatefulWidget {
  const TasksProjectsScreen({super.key});

  @override
  ConsumerState<TasksProjectsScreen> createState() => _TasksProjectsScreenState();
}

class _TasksProjectsScreenState extends ConsumerState<TasksProjectsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 0,
        title: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Tasks'),
            Tab(text: 'Projects'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TasksScreen(tabIndex: _tabController.index),
          const ProjectsScreen(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              heroTag: 'tasks_fab',
              backgroundColor: AppColors.primary,
              onPressed: () => _showQuickAddTaskDialog(context),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : FloatingActionButton(
              heroTag: 'projects_fab',
              backgroundColor: AppColors.primary,
              onPressed: () => _showQuickAddProjectDialog(context),
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  void _showQuickAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Quick Add Task'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Task title...',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(ctx);
              _createTaskQuick(value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                Navigator.pop(ctx);
                _createTaskQuick(titleController.text);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showQuickAddProjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Quick Add Project'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Project name...',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(ctx);
              _createProjectQuick(value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(ctx);
                _createProjectQuick(nameController.text);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTaskQuick(String title) async {
    await ref.read(tasksProvider.notifier).createTask(
      projectId: AppConstants.defaultProjectId,
      title: title,
      description: '',
      priority: Priority.medium,
      startDate: DateTime.now(),
      dueDate: null,
    );
  }

  void _createProjectQuick(String name) {
    ref.read(projectsProvider.notifier).createProject(
      name: name,
      color: '#00ff9f',
      icon: 'folder',
    );
  }
}