part of '../project_detail_screen.dart';

extension _ProjectDetailDialogs on _ProjectDetailScreenState {
  void _showAddTaskDialog(BuildContext context, {TaskItem? existingTask}) {
    final descCtrl = TextEditingController(text: existingTask?.description ?? '');
    final pendingCtrl = TextEditingController(text: existingTask?.pendingReason ?? '');
    DateTime? scheduled = existingTask?.scheduledDate;
    List<String> taskBamms = List.from(existingTask?.bammWorkOrders ?? []);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dateText = scheduled != null
              ? DateFormat('MMM d, y').format(scheduled!)
              : 'No scheduled date';

          return AlertDialog(
            title: Text(existingTask == null ? 'Add Project Tasks' : 'Edit Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: descCtrl,
                    autofocus: existingTask == null,
                    textCapitalization: TextCapitalization.sentences,
                    // New tasks: one per line, so a whole list can be added at once.
                    minLines: existingTask == null ? 4 : 1,
                    maxLines: existingTask == null ? 10 : 3,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: existingTask == null
                          ? 'Tasks * (one per line)'
                          : 'Task Description *',
                      hintText: existingTask == null
                          ? 'Machine UHMW starwheel guide plates\nOrder bearings\nRe-align conveyor'
                          : 'e.g. Machine UHMW starwheel guide plates',
                      helperText: existingTask == null
                          ? 'Paste or type several - each line becomes its own task'
                          : null,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pendingCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pending Value / Reason',
                      hintText: 'e.g. Pending parts, Pending downtime, Pending email',
                      prefixIcon: Icon(Icons.hourglass_empty_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.calendar_today_rounded, color: AppTheme.of(context).primary),
                    title: Text(
                      dateText,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Scheduled Target Date', style: TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (scheduled != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setDialogState(() => scheduled = null);
                            },
                          ),
                        ElevatedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: scheduled ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDialogState(() => scheduled = picked);
                            }
                          },
                          child: const Text('Pick Date'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),
                  // BAMM Work Orders
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Assigned BAMMs:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () async {
                          final res = await BammAssignDialog.show(context, currentSelections: taskBamms);
                          if (res != null) {
                            setDialogState(() => taskBamms = res);
                          }
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Assign BAMM', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  if (taskBamms.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: taskBamms.map((wo) => BammChip(
                        worNo: wo,
                        onDeleted: () => setDialogState(() => taskBamms.remove(wo)),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (descCtrl.text.trim().isEmpty) return;
                  if (existingTask != null) {
                    final updated = existingTask.copyWith(
                      description: descCtrl.text.trim(),
                      pendingReason: pendingCtrl.text.trim(),
                      scheduledDate: scheduled,
                      clearScheduledDate: scheduled == null,
                      bammWorkOrders: taskBamms,
                    );
                    await ref
                        .read(projectProvider.notifier)
                        .updateTask(widget.projectId, updated);
                  } else {
                    // One task per non-empty line; strip pasted list bullets/numbers.
                    final lines = descCtrl.text
                        .split(RegExp(r'[\r\n]+'))
                        .map((l) => l.trim().replaceFirst(RegExp(r'^([-*\u2022]|\d+[.)])\s+'), '').trim())
                        .where((l) => l.isNotEmpty)
                        .toList();
                    for (final line in lines) {
                      await ref.read(projectProvider.notifier).addTask(
                            widget.projectId,
                            TaskItem(
                              description: line,
                              pendingReason: pendingCtrl.text.trim(),
                              scheduledDate: scheduled,
                              bammWorkOrders: List.of(taskBamms),
                            ),
                          );
                    }
                  }
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: Text(existingTask == null ? 'Add Tasks' : 'Save Task'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddOrderDialog(BuildContext context, {OrderItem? existingOrder}) {
    showOrderDialog(context, existingOrder: existingOrder,
      existingOrderProjectId: widget.projectId,
      fixedProjectId: widget.projectId,
    );
  }

  void _showAddLogDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    LogType selectedType = LogType.update;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Add Engineering Log Entry'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Log Title',
                      hintText: 'e.g. Tolerances measured on guide rails',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<LogType>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Log Type'),
                    items: LogType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes & Observations',
                      hintText: 'Record root cause, measurement findings, alignment data...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final log = ProjectLog(
                    title: titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
                    type: selectedType,
                  );
                  await ref
                      .read(projectProvider.notifier)
                      .addProjectLog(widget.projectId, log);
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Log'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditNotesDialog(BuildContext context, Project project) {
    final ctrl = TextEditingController(text: project.notes);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: AppTheme.of(context).amber),
            SizedBox(width: 8),
            Text('Project Notes'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 8,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Key observations, measurements, decisions, follow-ups...',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(projectProvider.notifier)
                  .updateProjectNotes(project.id, ctrl.text.trim());
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Notes'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Category'),
        content: DropdownButtonFormField<ProjectCategory>(
          value: project.category,
          items: ProjectCategory.values
              .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
              .toList(),
          onChanged: (val) {
            if (val == null || val == project.category) {
              Navigator.pop(ctx);
              return;
            }
            ref
                .read(projectProvider.notifier)
                .updateProject(project.copyWith(category: val));
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _showEditPriorityDialog(BuildContext context, Project project) {
    if (project.isCompletedOrCancelled) return;
    final activeCount = ref.read(projectProvider).activeProjects.length;
    final maxPriority = activeCount > 0 ? activeCount : 1;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Priority Ranking'),
        content: DropdownButtonFormField<int>(
          value: project.priority.clamp(1, maxPriority),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.format_list_numbered_rounded),
          ),
          items: List.generate(
            maxPriority,
            (index) => DropdownMenuItem(
              value: index + 1,
              child: Text(
                '#${index + 1}${index == 0 ? " (Top Urgent)" : ""}',
              ),
            ),
          ),
          onChanged: (val) {
            if (val == null || val == project.priority) {
              Navigator.pop(ctx);
              return;
            }
            ref
                .read(projectProvider.notifier)
                .updateProject(project.copyWith(priority: val));
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _showEditPhaseDialog(BuildContext context, Project project) {
    final availablePhases = ref.read(projectProvider).availablePhases;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Phase / Status'),
        content: DropdownButtonFormField<String>(
          value: availablePhases.contains(project.phase)
              ? project.phase
              : availablePhases.first,
          items: availablePhases
              .map((ph) => DropdownMenuItem(value: ph, child: Text(ph)))
              .toList(),
          onChanged: (val) {
            if (val == null || val == project.phase) {
              Navigator.pop(ctx);
              return;
            }
            ref
                .read(projectProvider.notifier)
                .updateProject(project.copyWith(phase: val));
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _showEditMachineDialog(BuildContext context, Project project) {
    final ctrl = TextEditingController(text: project.machine);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Machine / Line'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Machine / Line',
            hintText: 'Use / to add multiple machines',
            prefixIcon: Icon(Icons.precision_manufacturing_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(projectProvider.notifier)
                  .updateProject(project.copyWith(machine: ctrl.text.trim()));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditSubAssemblyDialog(BuildContext context, Project project) {
    final ctrl = TextEditingController(text: project.subAssembly);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Sub-Assembly'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Sub-Assembly',
            hintText: 'e.g. Infeed Starwheel, Gearbox',
            prefixIcon: Icon(Icons.account_tree_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(projectProvider.notifier)
                  .updateProject(
                      project.copyWith(subAssembly: ctrl.text.trim()));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditCostDialog(BuildContext context, Project project) {
    final ctrl = TextEditingController(
      text: project.cost > 0 ? project.cost.toStringAsFixed(2) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Cost'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cost (\$ USD)',
            prefixIcon: Icon(Icons.attach_money_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final cost = double.tryParse(ctrl.text.trim()) ?? 0.0;
              ref
                  .read(projectProvider.notifier)
                  .updateProject(project.copyWith(cost: cost));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditTagsDialog(BuildContext context, Project project) {
    final ctrl = TextEditingController(text: project.tags.join(', '));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Tags'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tags (Comma separated)',
            hintText: '100, 621, Shutdown, Line 4, Mill, Hydraulics',
            prefixIcon: Icon(Icons.tag_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final tags = ctrl.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();
              ref
                  .read(projectProvider.notifier)
                  .updateProject(project.copyWith(tags: tags));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
