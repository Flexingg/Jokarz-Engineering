part of '../bamm_detail_dialog.dart';

class _BammLinkSheet extends ConsumerStatefulWidget {
  final BammWorkOrder workOrder;
  final VoidCallback onLinked;

  const _BammLinkSheet({
    required this.workOrder,
    required this.onLinked,
  });

  @override
  ConsumerState<_BammLinkSheet> createState() => _BammLinkSheetState();
}

class _BammLinkSheetState extends ConsumerState<_BammLinkSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _projectSelfMatches(Project p, String q) {
    if (q.isEmpty) return true;
    return p.title.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q) ||
        p.machine.toLowerCase().contains(q) ||
        p.phase.toLowerCase().contains(q);
  }

  bool _taskMatches(TaskItem t, String q) {
    if (q.isEmpty) return true;
    return t.description.toLowerCase().contains(q) ||
        t.pendingReason.toLowerCase().contains(q);
  }

  bool _orderMatches(OrderItem o, String q) {
    if (q.isEmpty) return true;
    return o.description.toLowerCase().contains(q) ||
        o.po.toLowerCase().contains(q) ||
        o.pr.toLowerCase().contains(q) ||
        o.vendorName.toLowerCase().contains(q);
  }

  Future<void> _showCreateProjectDialog(BuildContext ctx) async {
    final titleCtrl = TextEditingController(text: widget.workOrder.displayTitle);
    final machineCtrl = TextEditingController(text: widget.workOrder.machine);
    final allTemplates = ref.read(projectProvider).allTemplates;
    ProjectTemplate? selectedTemplate;

    try {
      await showDialog(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Create & Link Project', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const Key('create_project_title_field'),
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Project Title *',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('create_project_machine_field'),
                        controller: machineCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Machine / Area',
                          isDense: true,
                        ),
                      ),
                      if (allTemplates.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ProjectTemplate?>(
                          key: const Key('create_project_template_dropdown'),
                          initialValue: selectedTemplate,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Template (Optional)',
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<ProjectTemplate?>(
                              value: null,
                              child: Text('None (Blank Project)'),
                            ),
                            ...allTemplates.map((t) => DropdownMenuItem<ProjectTemplate?>(
                              value: t,
                              child: Text(t.name),
                            )),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedTemplate = val;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    key: const Key('confirm_create_project_btn'),
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      final machine = machineCtrl.text.trim();

                      Project createdProject;
                      if (selectedTemplate != null) {
                        createdProject = await ref.read(projectProvider.notifier).createProjectFromTemplate(
                          selectedTemplate!,
                          customTitle: title,
                          customMachine: machine,
                        );
                      } else {
                        final newProject = Project(
                          title: title,
                          description: widget.workOrder.description,
                          machine: machine,
                          category: ProjectCategory.maintenance,
                          phase: ProjectPhases.idea,
                        );
                        await ref.read(projectProvider.notifier).addProject(newProject);
                        createdProject = newProject;
                      }

                      await ref.read(projectProvider.notifier).assignBammToProject(
                        createdProject.id,
                        widget.workOrder.worNoSeq,
                      );

                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      if (ctx.mounted) Navigator.pop(ctx);
                      widget.onLinked();
                    },
                    child: const Text('Create & Link'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      titleCtrl.dispose();
      machineCtrl.dispose();
    }
  }

  Future<void> _showCreateTaskDialog(BuildContext ctx, {String? preselectedProjectId}) async {
    final projects = ref.read(projectProvider).projects;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Please create a project first before adding a task.')),
      );
      return;
    }

    String targetProjectId = preselectedProjectId ?? projects.first.id;
    final descCtrl = TextEditingController(text: widget.workOrder.displayTitle);

    try {
      await showDialog(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Create & Link Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (preselectedProjectId == null && projects.length > 1) ...[
                        DropdownButtonFormField<String>(
                          key: const Key('create_task_project_dropdown'),
                          initialValue: targetProjectId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Project *',
                            isDense: true,
                          ),
                          items: projects.map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.title, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => targetProjectId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        key: const Key('create_task_desc_field'),
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Task Description *',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    key: const Key('confirm_create_task_btn'),
                    onPressed: () async {
                      final desc = descCtrl.text.trim();
                      if (desc.isEmpty) return;

                      final newTask = TaskItem(
                        description: desc,
                        scheduledDate: widget.workOrder.requiredDate,
                      );
                      await ref.read(projectProvider.notifier).addTask(targetProjectId, newTask);
                      await ref.read(projectProvider.notifier).assignBammToTask(
                        targetProjectId,
                        newTask.id,
                        widget.workOrder.worNoSeq,
                      );

                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      if (ctx.mounted) Navigator.pop(ctx);
                      widget.onLinked();
                    },
                    child: const Text('Create & Link'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      descCtrl.dispose();
    }
  }

  Future<void> _showCreateOrderDialog(BuildContext ctx, {String? preselectedProjectId}) async {
    final projects = ref.read(projectProvider).projects;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Please create a project first before adding an order.')),
      );
      return;
    }

    String targetProjectId = preselectedProjectId ?? projects.first.id;
    final descCtrl = TextEditingController(text: widget.workOrder.displayTitle);

    try {
      await showDialog(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Create & Link Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (preselectedProjectId == null && projects.length > 1) ...[
                        DropdownButtonFormField<String>(
                          key: const Key('create_order_project_dropdown'),
                          initialValue: targetProjectId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Project *',
                            isDense: true,
                          ),
                          items: projects.map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.title, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => targetProjectId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        key: const Key('create_order_desc_field'),
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Order Description *',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    key: const Key('confirm_create_order_btn'),
                    onPressed: () async {
                      final desc = descCtrl.text.trim();
                      if (desc.isEmpty) return;

                      final newOrder = OrderItem(
                        description: desc,
                      );
                      await ref.read(projectProvider.notifier).addOrder(targetProjectId, newOrder);
                      await ref.read(projectProvider.notifier).assignBammToOrder(
                        targetProjectId,
                        newOrder.id,
                        widget.workOrder.worNoSeq,
                      );

                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      if (ctx.mounted) Navigator.pop(ctx);
                      widget.onLinked();
                    },
                    child: const Text('Create & Link'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      descCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final engState = ref.watch(projectProvider);
    final projects = engState.projects;
    final q = _searchQuery.trim().toLowerCase();

    final filteredProjects = projects.where((p) {
      if (q.isEmpty) return true;
      if (_projectSelfMatches(p, q)) return true;
      if (p.tasks.any((t) => _taskMatches(t, q))) return true;
      if (p.orders.any((o) => _orderMatches(o, q))) return true;
      return false;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assign BAMM #${widget.workOrder.worNoSeq} to...',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('bamm_link_search_input'),
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search projects, tasks, orders...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      key: const Key('bamm_create_project_btn'),
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('New Project', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showCreateProjectDialog(ctx),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      key: const Key('bamm_create_task_btn'),
                      avatar: const Icon(Icons.add_task_rounded, size: 16),
                      label: const Text('New Task', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showCreateTaskDialog(ctx),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      key: const Key('bamm_create_order_btn'),
                      avatar: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                      label: const Text('New Order', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showCreateOrderDialog(ctx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Expanded(
                child: filteredProjects.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            projects.isEmpty
                                ? 'No projects yet. Tap "New Project" above to create one and link this BAMM work order.'
                                : 'No projects, tasks, or orders match "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: filteredProjects.length,
                        itemBuilder: (ctx, idx) {
                          final p = filteredProjects[idx];
                          final isAlreadyLinked = p.bammWorkOrders.contains(widget.workOrder.worNoSeq);
                          final isSelfMatch = _projectSelfMatches(p, q);
                          final displayedTasks = q.isEmpty
                              ? p.tasks
                              : (isSelfMatch
                                  ? p.tasks
                                  : p.tasks.where((t) => _taskMatches(t, q)).toList());
                          final displayedOrders = q.isEmpty
                              ? p.orders
                              : (isSelfMatch
                                  ? p.orders
                                  : p.orders.where((o) => _orderMatches(o, q)).toList());

                          return ExpansionTile(
                            key: ValueKey('${p.id}_${q.isNotEmpty}'),
                            initiallyExpanded: q.isNotEmpty,
                            leading: Icon(
                              isAlreadyLinked ? Icons.check_circle_rounded : Icons.folder_outlined,
                              color: isAlreadyLinked ? AppTheme.of(context).emerald : AppTheme.of(context).primary,
                            ),
                            title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${p.phase} • ${p.tasks.length} tasks • ${p.orders.length} orders'),
                            trailing: IconButton(
                              tooltip: isAlreadyLinked ? 'Unlink from Project' : 'Link to Project',
                              icon: Icon(
                                isAlreadyLinked ? Icons.link_off_rounded : Icons.add_link_rounded,
                                color: isAlreadyLinked ? Colors.red : AppTheme.of(context).primary,
                              ),
                              onPressed: () async {
                                if (isAlreadyLinked) {
                                  await ref.read(projectProvider.notifier).removeBammFromProject(p.id, widget.workOrder.worNoSeq);
                                } else {
                                  await ref.read(projectProvider.notifier).assignBammToProject(p.id, widget.workOrder.worNoSeq);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                widget.onLinked();
                              },
                            ),
                            children: [
                              // Tasks section
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Tasks in project:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    InkWell(
                                      key: Key('project_new_task_${p.id}'),
                                      onTap: () => _showCreateTaskDialog(ctx, preselectedProjectId: p.id),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add, size: 14, color: AppTheme.of(context).primary),
                                            const SizedBox(width: 2),
                                            Text('New Task', style: TextStyle(fontSize: 11, color: AppTheme.of(context).primary, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (displayedTasks.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(left: 32, top: 2, bottom: 6),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('(No tasks)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ),
                                ),
                              ...displayedTasks.map((t) {
                                final taskLinked = t.bammWorkOrders.contains(widget.workOrder.worNoSeq);
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                                  title: Text(t.description, style: const TextStyle(fontSize: 12)),
                                  trailing: IconButton(
                                    icon: Icon(
                                      taskLinked ? Icons.link_off_rounded : Icons.add_link_rounded,
                                      size: 18,
                                      color: taskLinked ? Colors.red : AppTheme.of(context).primary,
                                    ),
                                    onPressed: () async {
                                      if (taskLinked) {
                                        await ref.read(projectProvider.notifier).removeBammFromTask(p.id, t.id, widget.workOrder.worNoSeq);
                                      } else {
                                        await ref.read(projectProvider.notifier).assignBammToTask(p.id, t.id, widget.workOrder.worNoSeq);
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      widget.onLinked();
                                    },
                                  ),
                                );
                              }),
                              // Orders section
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Orders in project:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    InkWell(
                                      key: Key('project_new_order_${p.id}'),
                                      onTap: () => _showCreateOrderDialog(ctx, preselectedProjectId: p.id),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add, size: 14, color: AppTheme.of(context).primary),
                                            const SizedBox(width: 2),
                                            Text('New Order', style: TextStyle(fontSize: 11, color: AppTheme.of(context).primary, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (displayedOrders.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(left: 32, top: 2, bottom: 6),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('(No orders)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ),
                                ),
                              ...displayedOrders.map((o) {
                                final orderLinked = o.bammWorkOrders.contains(widget.workOrder.worNoSeq);
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                                  title: Text(o.description.isNotEmpty ? o.description : (o.po.isNotEmpty ? 'PO: ${o.po}' : 'PR: ${o.pr}'), style: const TextStyle(fontSize: 12)),
                                  trailing: IconButton(
                                    icon: Icon(
                                      orderLinked ? Icons.link_off_rounded : Icons.add_link_rounded,
                                      size: 18,
                                      color: orderLinked ? Colors.red : AppTheme.of(context).primary,
                                    ),
                                    onPressed: () async {
                                      if (orderLinked) {
                                        await ref.read(projectProvider.notifier).removeBammFromOrder(p.id, o.id, widget.workOrder.worNoSeq);
                                      } else {
                                        await ref.read(projectProvider.notifier).assignBammToOrder(p.id, o.id, widget.workOrder.worNoSeq);
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      widget.onLinked();
                                    },
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
