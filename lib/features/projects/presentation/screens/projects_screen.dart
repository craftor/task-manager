import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/project.dart';
import '../providers/projects_provider.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Projects'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showProjectDialog(context, ref),
          ),
        ],
      ),
      body: projectsAsync.when(
        data: (projects) => _buildProjectList(context, ref, projects),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildProjectList(
    BuildContext context,
    WidgetRef ref,
    List<Project> projects,
  ) {
    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_outlined, size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            const Text(
              'No projects yet',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showProjectDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create Project'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return _ProjectCard(
          project: project,
          onTap: () => _showProjectDialog(context, ref, project),
          onDelete: () => ref.read(projectsProvider.notifier).deleteProject(project.id),
        );
      },
    );
  }

  void _showProjectDialog(BuildContext context, WidgetRef ref, [Project? project]) {
    final nameController = TextEditingController(text: project?.name ?? '');
    final isEditing = project != null;
    String selectedColor = project?.color ?? '#00ff9f';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(isEditing ? 'Edit Project' : 'New Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                labelStyle: TextStyle(color: AppColors.textPrimary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) => _ColorPicker(
                selectedColor: selectedColor,
                onColorSelected: (color) {
                  setState(() => selectedColor = color);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                if (isEditing) {
                  ref.read(projectsProvider.notifier).updateProject(
                        project!.copyWith(name: nameController.text, color: selectedColor),
                      );
                } else {
                  ref.read(projectsProvider.notifier).createProject(
                        name: nameController.text,
                        color: selectedColor,
                        icon: 'folder',
                      );
                }
                Navigator.pop(dialogContext);
              }
            },
            child: Text(isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(int.parse(project.color.replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  project.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatefulWidget {
  final String selectedColor;
  final ValueChanged<String> onColorSelected;

  const _ColorPicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  late String _selectedColor;

  static const _colors = [
    '#00ff9f',
    '#00d4ff',
    '#ff4757',
    '#ffcc00',
    '#ff6b81',
    '#7bed9f',
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.selectedColor;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _colors.map((color) {
        final isSelected = color == _selectedColor;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedColor = color);
            widget.onColorSelected(color);
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}