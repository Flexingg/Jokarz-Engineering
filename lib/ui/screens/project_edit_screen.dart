import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';

class ProjectEditScreen extends ConsumerStatefulWidget {
  final String? projectId; // null for new project

  const ProjectEditScreen({super.key, this.projectId});

  @override
  ConsumerState<ProjectEditScreen> createState() => _ProjectEditScreenState();
}

class _ProjectEditScreenState extends ConsumerState<ProjectEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _costController;
  late TextEditingController _machineController;
  late TextEditingController _subAssemblyController;
  late TextEditingController _customPhaseController;
  late TextEditingController _tagsController;

  ProjectCategory _category = ProjectCategory.maintenance;
  String _selectedPhase = ProjectPhases.idea;
  bool _isCustomPhase = false;
  int _priority = 1;
  String? _nextPendingTaskId;

  Project? _existingProject;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _costController = TextEditingController(text: '');
    _machineController = TextEditingController();
    _subAssemblyController = TextEditingController();
    _customPhaseController = TextEditingController();
    _tagsController = TextEditingController();

    if (widget.projectId != null) {
      _existingProject = ref
          .read(projectProvider.notifier)
          .getProjectById(widget.projectId!);
      if (_existingProject != null) {
        _titleController.text = _existingProject!.title;
        _descController.text = _existingProject!.description;
        _costController.text = _existingProject!.cost > 0
            ? _existingProject!.cost.toStringAsFixed(2)
            : '';
        _machineController.text = _existingProject!.machine;
        _subAssemblyController.text = _existingProject!.subAssembly;
        _tagsController.text = _existingProject!.tags.join(', ');
        _category = _existingProject!.category;
        _selectedPhase = _existingProject!.phase;
        _priority = _existingProject!.priority;
        _nextPendingTaskId = _existingProject!.nextPendingTaskId;
      }
    } else {
      final activeCount = ref
          .read(projectProvider)
          .activeProjects
          .length;
      _priority = activeCount + 1;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _costController.dispose();
    _machineController.dispose();
    _subAssemblyController.dispose();
    _customPhaseController.dispose();
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

    final finalPhase = _isCustomPhase && _customPhaseController.text.trim().isNotEmpty
        ? _customPhaseController.text.trim()
        : _selectedPhase;

    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;

    if (_existingProject != null) {
      final updated = _existingProject!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _category,
        phase: finalPhase,
        priority: _priority,
        cost: cost,
        machine: _machineController.text.trim(),
        subAssembly: _subAssemblyController.text.trim(),
        nextPendingTaskId: _nextPendingTaskId,
        clearNextPendingTask: _nextPendingTaskId == null,
        tags: tags,
      );
      await ref.read(projectProvider.notifier).updateProject(updated);
    } else {
      final newProject = Project(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _category,
        phase: finalPhase,
        priority: _priority,
        cost: cost,
        machine: _machineController.text.trim(),
        subAssembly: _subAssemblyController.text.trim(),
        nextPendingTaskId: _nextPendingTaskId,
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
    final state = ref.watch(projectProvider);
    final isNew = widget.projectId == null;
    final activeCount = state.activeProjects.length + (isNew ? 1 : 0);

    final availablePhases = state.availablePhases;
    final availableMachines = state.availableMachines;
    final availableSubAssemblies = state.availableSubAssemblies;

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
            // Project Title (Only required field)
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Project Title *',
                hintText: 'e.g. Line 1 Filler Infeed Starwheel Jamming',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Project title is required' : null,
            ),
            const SizedBox(height: 16),

            // Category & Priority Row
            Row(
              children: [
                // Category
                Expanded(
                  child: DropdownButtonFormField<ProjectCategory>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: ProjectCategory.values
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.label),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Priority Selector (1..X)
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _priority.clamp(1, activeCount > 0 ? activeCount : 1),
                    decoration: const InputDecoration(
                      labelText: 'Priority Ranking',
                      prefixIcon: Icon(Icons.format_list_numbered_rounded),
                    ),
                    items: List.generate(
                      activeCount > 0 ? activeCount : 1,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          '#${index + 1}${index == 0 ? " (Top Urgent)" : ""}',
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      if (val != null) setState(() => _priority = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Phase Selector (Dropdown with existing + custom add option)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _isCustomPhase
                        ? '__custom__'
                        : (availablePhases.contains(_selectedPhase)
                            ? _selectedPhase
                            : availablePhases.first),
                    decoration: const InputDecoration(
                      labelText: 'Phase',
                      prefixIcon: Icon(Icons.flag_rounded),
                    ),
                    items: [
                      ...availablePhases.map(
                        (ph) => DropdownMenuItem(
                          value: ph,
                          child: Text(ph),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: '__custom__',
                        child: Text('➕ + Add Custom Phase...'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == '__custom__') {
                        setState(() {
                          _isCustomPhase = true;
                        });
                      } else if (val != null) {
                        setState(() {
                          _isCustomPhase = false;
                          _selectedPhase = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_isCustomPhase) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _customPhaseController,
                decoration: const InputDecoration(
                  labelText: 'Custom Phase Name',
                  hintText: 'e.g. Fabrication, Factory Acceptance Test, CapEx Review',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Machine & Sub-Assembly
            Row(
              children: [
                // Machine autocomplete / dropdown
                Expanded(
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: _machineController.text),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return availableMachines;
                      }
                      return availableMachines.where((m) =>
                          m.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (selection) {
                      _machineController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      _machineController = controller;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Machine / Line',
                          hintText: 'e.g. Line 1 Filler, Cell 621',
                          prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // SubAssembly autocomplete / dropdown
                Expanded(
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: _subAssemblyController.text),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return availableSubAssemblies;
                      }
                      return availableSubAssemblies.where((sa) =>
                          sa.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (selection) {
                      _subAssemblyController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      _subAssemblyController = controller;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Sub-Assembly',
                          hintText: 'e.g. Infeed Starwheel, Gearbox',
                          prefixIcon: Icon(Icons.account_tree_outlined),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cost (formerly Budget)
            TextFormField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cost (\$ USD)',
                hintText: 'e.g. 1250.00',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // Next Pending Task selector (if existing project has tasks)
            if (_existingProject != null && _existingProject!.tasks.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                value: _existingProject!.tasks.any((t) => t.id == _nextPendingTaskId)
                    ? _nextPendingTaskId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Next Pending Task',
                  prefixIcon: Icon(Icons.pending_actions_rounded),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Auto (First incomplete pending task)'),
                  ),
                  ..._existingProject!.tasks.map(
                    (t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(
                        '${t.description}${t.pendingReason.isNotEmpty ? " [${t.pendingReason}]" : ""}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() => _nextPendingTaskId = val);
                },
              ),
              const SizedBox(height: 16),
            ],

            // Description
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Root cause, mechanical issue, upgrade details, downtime notes...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (Comma separated)',
                hintText: '100, 621, Shutdown, Line 4, Mill, Hydraulics',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            const SizedBox(height: 28),

            // Save Action
            ElevatedButton.icon(
              onPressed: _saveProject,
              icon: const Icon(Icons.save_rounded),
              label: Text(isNew ? 'Create Project' : 'Save Changes'),
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
