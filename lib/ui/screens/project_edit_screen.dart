import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';

class ProjectEditScreen extends ConsumerStatefulWidget {
  final String? projectId; // null for creating new project

  const ProjectEditScreen({super.key, this.projectId});

  @override
  ConsumerState<ProjectEditScreen> createState() => _ProjectEditScreenState();
}

class _ProjectEditScreenState extends ConsumerState<ProjectEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _budgetController;
  late TextEditingController _printHoursController;
  late TextEditingController _filamentGramsController;
  late TextEditingController _tagsController;

  ProjectCategory _category = ProjectCategory.threeDPrinting;
  ProjectStatus _status = ProjectStatus.planning;
  ProjectPriority _priority = ProjectPriority.medium;

  Project? _existingProject;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _budgetController = TextEditingController(text: '0.00');
    _printHoursController = TextEditingController(text: '0.0');
    _filamentGramsController = TextEditingController(text: '0.0');
    _tagsController = TextEditingController();

    if (widget.projectId != null) {
      _existingProject = ref
          .read(projectProvider.notifier)
          .getProjectById(widget.projectId!);
      if (_existingProject != null) {
        _titleController.text = _existingProject!.title;
        _descController.text = _existingProject!.description;
        _budgetController.text = _existingProject!.budget.toStringAsFixed(2);
        _printHoursController.text =
            _existingProject!.estimatedPrintHours.toString();
        _filamentGramsController.text =
            _existingProject!.estimatedFilamentGrams.toString();
        _tagsController.text = _existingProject!.tags.join(', ');
        _category = _existingProject!.category;
        _status = _existingProject!.status;
        _priority = _existingProject!.priority;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    _printHoursController.dispose();
    _filamentGramsController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (_existingProject != null) {
      final updated = _existingProject!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _category,
        status: _status,
        priority: _priority,
        budget: double.tryParse(_budgetController.text.trim()) ?? 0.0,
        estimatedPrintHours:
            double.tryParse(_printHoursController.text.trim()) ?? 0.0,
        estimatedFilamentGrams:
            double.tryParse(_filamentGramsController.text.trim()) ?? 0.0,
        tags: tags,
      );
      await ref.read(projectProvider.notifier).updateProject(updated);
    } else {
      final newProject = Project(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _category,
        status: _status,
        priority: _priority,
        budget: double.tryParse(_budgetController.text.trim()) ?? 0.0,
        estimatedPrintHours:
            double.tryParse(_printHoursController.text.trim()) ?? 0.0,
        estimatedFilamentGrams:
            double.tryParse(_filamentGramsController.text.trim()) ?? 0.0,
        tags: tags,
      );
      await ref.read(projectProvider.notifier).addProject(newProject);
    }

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.projectId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isNew ? 'New Engineering Project' : 'Edit Project',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.primaryCyan),
            onPressed: _saveProject,
            tooltip: 'Save Project',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Project Title *',
                hintText: 'e.g. Jokarz 3D Printed Dial Indicator Fixture',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            // Category & Status Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ProjectCategory>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Discipline / Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: ProjectCategory.values
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ProjectStatus>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status Phase',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: ProjectStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _status = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Priority & Budget Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ProjectPriority>(
                    value: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority Level',
                      prefixIcon: Icon(Icons.priority_high),
                    ),
                    items: ProjectPriority.values
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _priority = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _budgetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Budget Target (\$ USD)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Project Description & Engineering Goals',
                hintText: 'Describe CAD specs, materials, tolerances, electronics...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Print Estimates
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _printHoursController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Est. Print Hours',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _filamentGramsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Filament (Grams)',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tags
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (Comma separated)',
                hintText: 'e.g. 3D Print, PETG, CNC, ESP32, Sorter',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 28),

            // Save Button
            ElevatedButton.icon(
              onPressed: _saveProject,
              icon: const Icon(Icons.save_rounded),
              label: Text(isNew ? 'Create Engineering Project' : 'Save Changes'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
