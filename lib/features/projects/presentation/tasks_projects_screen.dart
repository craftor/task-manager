import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../tasks/presentation/screens/tasks_screen.dart';
import '../presentation/screens/projects_screen.dart';

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
  }

  @override
  void dispose() {
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
        children: const [
          TasksScreen(),
          ProjectsScreen(),
        ],
      ),
    );
  }
}
