import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            backgroundColor: const Color(0xFF1a1a2e),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: Text('Projects'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.task_outlined),
                selectedIcon: Icon(Icons.task),
                label: Text('Tasks'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.timer_outlined),
                selectedIcon: Icon(Icons.timer),
                label: Text('Time'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const ProjectsView();
      case 1:
        return const TasksView();
      case 2:
        return const TimeTrackingView();
      default:
        return const ProjectsView();
    }
  }
}

class ProjectsView extends StatelessWidget {
  const ProjectsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Projects', style: TextStyle(fontSize: 24)));
  }
}

class TasksView extends StatelessWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Tasks', style: TextStyle(fontSize: 24)));
  }
}

class TimeTrackingView extends StatelessWidget {
  const TimeTrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Time Tracking', style: TextStyle(fontSize: 24)));
  }
}