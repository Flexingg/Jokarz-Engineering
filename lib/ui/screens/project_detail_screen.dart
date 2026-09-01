import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/task_item.dart';
import '../../models/order_item.dart';
import '../../models/project_log.dart';
import '../../providers/project_provider.dart';
import '../../services/sync_service.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/voice_memo_modal.dart';
import '../widgets/template_dialogs.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String? initialTab;

  const ProjectDetailScreen({super.key, required this.projectId, this.initialTab});

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab == 'orders' ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? photo =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (photo != null) {
        await ref
            .read(projectProvider.notifier)
            .addProjectPhoto(widget.projectId, photo.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo attached to project!'),
              backgroundColor: AppTheme.accentEmerald,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showAddTaskDialog(BuildContext context, {TaskItem? existingTask}) {
    final descCtrl = TextEditingController(text: existingTask?.description ?? '');
    final pendingCtrl = TextEditingController(text: existingTask?.pendingReason ?? '');
    DateTime? scheduled = existingTask?.scheduledDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dateText = scheduled != null
              ? DateFormat('MMM d, y').format(scheduled!)
              : 'No Date Scheduled';

          return AlertDialog(
            title: Text(existingTask == null ? 'Add Project Task' : 'Edit Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Task Description *',
                      hintText: 'e.g. Machine UHMW starwheel guide plates',
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
                    leading: const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryCyan),
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
                    );
                    await ref
                        .read(projectProvider.notifier)
                        .updateTask(widget.projectId, updated);
                  } else {
                    final newTask = TaskItem(
                      description: descCtrl.text.trim(),
                      pendingReason: pendingCtrl.text.trim(),
                      scheduledDate: scheduled,
                    );
                    await ref
                        .read(projectProvider.notifier)
                        .addTask(widget.projectId, newTask);
                  }
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Task'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddOrderDialog(BuildContext context, {OrderItem? existingOrder}) {
    final prCtrl = TextEditingController(text: existingOrder?.pr ?? '');
    final poCtrl = TextEditingController(text: existingOrder?.po ?? '');
    final descCtrl = TextEditingController(text: existingOrder?.description ?? '');
    final priceCtrl = TextEditingController(
      text: existingOrder != null && existingOrder.price > 0
          ? existingOrder.price.toStringAsFixed(2)
          : '',
    );
    DateTime? eta = existingOrder?.eta;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final etaText = eta != null
              ? DateFormat('MMM d, y').format(eta!)
              : 'Unscheduled ETA';

          return AlertDialog(
            title: Text(existingOrder == null ? 'Add Order / Requisition' : 'Edit Order'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: prCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'PR (Requisition)',
                            hintText: 'PR-48901',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: poCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'PO (Purchase Order)',
                            hintText: 'PO-9921004',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Order Description',
                      hintText: 'e.g. SKF 6205 Bearings, UHMW Sheet',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price (\$ USD)',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_shipping_outlined, color: AppTheme.primaryCyan),
                    title: Text(
                      etaText,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Estimated Delivery Date (ETA)', style: TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (eta != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setDialogState(() => eta = null);
                            },
                          ),
                        ElevatedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: eta ?? DateTime.now().add(const Duration(days: 3)),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDialogState(() => eta = picked);
                            }
                          },
                          child: const Text('Set ETA'),
                        ),
                      ],
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
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                  if (existingOrder != null) {
                    final updated = existingOrder.copyWith(
                      pr: prCtrl.text.trim(),
                      po: poCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      price: price,
                      eta: eta,
                      clearEta: eta == null,
                    );
                    await ref
                        .read(projectProvider.notifier)
                        .updateOrder(widget.projectId, updated);
                  } else {
                    final newOrder = OrderItem(
                      pr: prCtrl.text.trim(),
                      po: poCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      price: price,
                      eta: eta,
                    );
                    await ref
                        .read(projectProvider.notifier)
                        .addOrder(widget.projectId, newOrder);
                  }
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Order'),
              ),
            ],
          );
        },
      ),
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
        title: const Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: AppTheme.accentAmber),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final project = state.projects.cast<Project?>().firstWhere(
          (p) => p?.id == widget.projectId,
          orElse: () => null,
        );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Project not found or deleted.'),
        ),
      );
    }

    final isTerminal = project.isCompletedOrCancelled;
    final nextTask = project.nextPendingTask;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          project.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: AppTheme.accentAmber),
            tooltip: 'Dictate Field Log for Project',
            onPressed: () => VoiceMemoModal.show(
              context,
              preselectedProjectId: project.id,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy_rounded, color: AppTheme.primaryCyan),
            tooltip: 'Save as Reusable Template',
            onPressed: () => TemplateDialogs.showSaveAsTemplateDialog(context, ref, project),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryCyan),
            tooltip: 'Edit Project Details',
            onPressed: () => context.push('/projects/${project.id}/edit'),
          ),

          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.accentCoral),
            tooltip: 'Delete Project',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Project?'),
                  content: Text('Are you sure you want to delete "${project.title}"? This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCoral),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await ref
                    .read(syncStatusProvider.notifier)
                    .deleteProjectEverywhere(project.id);
                if (context.mounted) {
                  context.pop();
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryCyan,
          tabs: [
            Tab(
              icon: const Icon(Icons.checklist_rounded),
              text: 'Tasks (${project.completedTasksCount}/${project.tasks.length})',
            ),
            Tab(
              icon: const Icon(Icons.local_shipping_outlined),
              text: 'Orders (${project.orders.length})',
            ),
            Tab(
              icon: const Icon(Icons.history_edu_outlined),
              text: 'Logs & Photos (${project.logs.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Project Meta Info Header Card
          _buildProjectHeader(context, project, currency, dateFormat, isDark, isTerminal),

          // Next Pending Task Banner
          if (nextTask != null && !isTerminal)
            _buildNextPendingBanner(context, nextTask, isDark),

          // Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTasksTab(context, project, isDark),
                _buildOrdersTab(context, project, currency, isDark),
                _buildLogsAndPhotosTab(context, project, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectHeader(
    BuildContext context,
    Project project,
    NumberFormat currency,
    DateFormat dateFormat,
    bool isDark,
    bool isTerminal,
  ) {
    final priorityColor = project.priority == 1
        ? AppTheme.accentCoral
        : (project.priority <= 3 ? AppTheme.accentAmber : AppTheme.primaryCyan);
    final phaseColor = project.phase.toLowerCase() == 'complete'
        ? AppTheme.accentEmerald
        : (project.phase.toLowerCase() == 'cancelled'
            ? AppTheme.accentCoral
            : AppTheme.accentAmber);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tappable Badges Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Category
              Tooltip(
                message: 'Tap to change category',
                child: InkWell(
                  onTap: () => _showEditCategoryDialog(context, project),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  child: ExpressiveBadge(
                    label: '${project.category.label} ✎',
                    color: AppTheme.primaryCyan,
                    fontSize: 11,
                  ),
                ),
              ),

              // Priority
              if (isTerminal)
                ExpressiveBadge(
                  label: 'Lifetime #${project.priority} (Closed)',
                  color: Colors.grey,
                  fontSize: 11,
                )
              else
                Tooltip(
                  message: 'Tap to change priority',
                  child: InkWell(
                    onTap: () => _showEditPriorityDialog(context, project),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                    child: ExpressiveBadge(
                      label: 'Priority #${project.priority} ✎',
                      color: priorityColor,
                      fontSize: 11,
                    ),
                  ),
                ),

              // Phase / Status
              Tooltip(
                message: 'Tap to change phase / status',
                child: InkWell(
                  onTap: () => _showEditPhaseDialog(context, project),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  child: ExpressiveBadge(
                    label: '${project.phase} ✎',
                    color: phaseColor,
                    fontSize: 11,
                  ),
                ),
              ),

              // Cost
              if (project.cost > 0)
                Tooltip(
                  message: 'Tap to edit cost',
                  child: InkWell(
                    onTap: () => _showEditCostDialog(context, project),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Cost: ${currency.format(project.cost)} ✎',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Machine & Sub-Assembly Row (tappable)
          if (project.machine.isNotEmpty || project.subAssembly.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (project.machine.isNotEmpty)
                  Tooltip(
                    message: 'Tap to edit machine / line',
                    child: InkWell(
                      onTap: () => _showEditMachineDialog(context, project),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.precision_manufacturing_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${project.machine} ✎',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (project.subAssembly.isNotEmpty)
                  Tooltip(
                    message: 'Tap to edit sub-assembly',
                    child: InkWell(
                      onTap: () => _showEditSubAssemblyDialog(context, project),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_tree_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${project.subAssembly} ✎',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Completed at indicator
          if (project.completedAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.accentEmerald),
                const SizedBox(width: 4),
                Text(
                  'Completed at: ${dateFormat.format(project.completedAt!)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.accentEmerald, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],

          // Description
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ],

          // Tags (tappable to edit)
          if (project.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Tooltip(
              message: 'Tap to edit tags',
              child: InkWell(
                onTap: () => _showEditTagsDialog(context, project),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: project.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ],

          // Project Notes (editable)
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppTheme.accentAmber),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Project Notes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentAmber,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showEditNotesDialog(context, project),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: Text(
                  project.notes.isEmpty ? 'Add' : 'Edit',
                  style: const TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppTheme.accentAmber,
                ),
              ),
            ],
          ),
          if (project.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: AppTheme.accentAmber.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                project.notes,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextPendingBanner(
    BuildContext context,
    TaskItem task,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.accentAmber.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.pending_actions_rounded, size: 18, color: AppTheme.accentAmber),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                children: [
                  const TextSpan(
                    text: 'NEXT PENDING: ',
                    style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.accentAmber),
                  ),
                  TextSpan(
                    text: task.description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (task.pendingReason.isNotEmpty)
                    TextSpan(
                      text: ' (${task.pendingReason})',
                      style: const TextStyle(fontStyle: FontStyle.italic, color: AppTheme.accentAmber),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTab(BuildContext context, Project project, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tasks (${project.completedTasksCount} of ${project.tasks.length} Complete)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddTaskDialog(context),
                icon: const Icon(Icons.add_task_rounded, size: 16),
                label: const Text('Add Task'),
              ),
            ],
          ),
        ),
        Expanded(
          child: project.tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.checklist_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No tasks created for this project yet',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddTaskDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Task'),
                      ),
                    ],
                  ),
                )
              : Builder(builder: (ctx) {
                  // Sort: incomplete by sortOrder first, then completed
                  final incomplete = project.tasks
                      .where((t) => !t.isCompleted)
                      .toList()
                    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                  final completed = project.tasks
                      .where((t) => t.isCompleted)
                      .toList();
                  final sorted = [...incomplete, ...completed];

                  return ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: sorted.length,
                    onReorder: (oldIndex, newIndex) {
                      // Only allow reordering within incomplete tasks
                      if (oldIndex < incomplete.length) {
                        ref.read(projectProvider.notifier)
                            .reorderTasks(project.id, oldIndex, newIndex);
                      }
                    },
                    itemBuilder: (context, index) {
                      final task = sorted[index];
                      final dateText = task.scheduledDate != null
                          ? DateFormat('MMM d, y').format(task.scheduledDate!)
                          : null;
                      final canDrag = !task.isCompleted;

                      return ExpressiveCard(
                        key: ValueKey(task.id),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Drag handle (incomplete tasks only)
                            if (canDrag)
                              const Icon(Icons.drag_handle_rounded, size: 20, color: Colors.grey)
                            else
                              const SizedBox(width: 20),
                            Checkbox(
                              value: task.isCompleted,
                              activeColor: AppTheme.accentEmerald,
                              onChanged: (_) {
                                ref
                                    .read(projectProvider.notifier)
                                    .toggleTaskCompleted(project.id, task.id);
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.description,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (task.pendingReason.isNotEmpty)
                                        ExpressiveBadge(
                                          label: task.pendingReason,
                                          icon: Icons.hourglass_empty_rounded,
                                          color: AppTheme.accentAmber,
                                          fontSize: 10,
                                        ),
                                      if (dateText != null)
                                        ExpressiveBadge(
                                          label: 'Scheduled: $dateText',
                                          icon: Icons.calendar_today_rounded,
                                          color: AppTheme.primaryCyan,
                                          fontSize: 10,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                              onPressed: () => _showAddTaskDialog(context, existingTask: task),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              onPressed: () => ref
                                  .read(projectProvider.notifier)
                                  .deleteTask(project.id, task.id),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
        ),
      ],
    );
  }

  Widget _buildOrdersTab(
    BuildContext context,
    Project project,
    NumberFormat currency,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Orders: ${currency.format(project.totalOrdersCost)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${project.undeliveredOrdersCount} Undelivered',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showAddOrderDialog(context),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                    label: const Text('Add Order'),
                  ),
                  TextButton.icon(
                    onPressed: () => _showLinkUnlinkedOrderDialog(context, project),
                    icon: const Icon(Icons.link_rounded, size: 14, color: AppTheme.accentEmerald),
                    label: const Text('Link Unlinked',
                        style: TextStyle(fontSize: 12, color: AppTheme.accentEmerald)),
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: project.orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No purchase orders created for this build',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddOrderDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Order'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: project.orders.length,
                  itemBuilder: (context, index) {
                    final order = project.orders[index];
                    final etaText = order.eta != null
                        ? DateFormat('MMM d, y').format(order.eta!)
                        : 'Unscheduled ETA';

                    return ExpressiveCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: order.delivered,
                                activeColor: AppTheme.accentEmerald,
                                onChanged: (_) {
                                  ref
                                      .read(projectProvider.notifier)
                                      .toggleOrderDelivered(project.id, order.id);
                                },
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (order.po.isNotEmpty)
                                          ExpressiveBadge(
                                            label: 'PO: ${order.po}',
                                            color: AppTheme.primaryCyan,
                                            fontSize: 10,
                                          ),
                                        if (order.pr.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          ExpressiveBadge(
                                            label: 'PR: ${order.pr}',
                                            color: AppTheme.primaryBlue,
                                            isOutlined: true,
                                            fontSize: 10,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order.description,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        decoration: order.delivered
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ETA: $etaText',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currency.format(order.price),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    order.delivered ? 'Delivered' : 'Pending',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: order.delivered
                                          ? AppTheme.accentEmerald
                                          : AppTheme.accentAmber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                onPressed: () => _showAddOrderDialog(context, existingOrder: order),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                onPressed: () => ref
                                    .read(projectProvider.notifier)
                                    .deleteOrder(project.id, order.id),
                              ),
                            ],
                          ),
                          _buildOrderStoresSection(context, project, order, isDark),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Search standalone (unlinked) orders and link one to this project.
  Future<void> _showLinkUnlinkedOrderDialog(BuildContext context, Project project) async {
    final standalone = ref.read(projectProvider).standaloneOrders;
    if (standalone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No unlinked orders available to link.')));
      return;
    }
    final searchCtrl = TextEditingController();
    String? selectedId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        final q = searchCtrl.text.trim().toLowerCase();
        final matches = q.isEmpty
            ? standalone
            : standalone
                .where((o) => o.description.toLowerCase().contains(q) ||
                    o.pr.toLowerCase().contains(q) ||
                    o.po.toLowerCase().contains(q))
                .toList();
        return AlertDialog(
          title: const Text('Link Unlinked Order'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: searchCtrl,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Search order',
                    hintText: 'Type to filter...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: matches.isEmpty
                    ? const Padding(padding: EdgeInsets.all(12), child: Text('No matching unlinked orders', style: TextStyle(fontSize: 12, color: Colors.grey)))
                    : ListView(
                        shrinkWrap: true,
                        children: matches.map((o) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          color: selectedId == o.id ? AppTheme.accentEmerald.withValues(alpha: 0.15) : null,
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.link_off_rounded, size: 20, color: Colors.orange),
                            title: Text(o.description.isEmpty ? '(No description)' : o.description,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            subtitle: Text('PO ${o.po.isEmpty ? '—' : o.po} • PR ${o.pr.isEmpty ? '—' : o.pr}',
                                style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                            onTap: () => setDialogState(() => selectedId = o.id),
                          ),
                        )).toList(),
                      ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      await ref.read(projectProvider.notifier).linkOrderToProject(selectedId!, project.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order linked to project!'), backgroundColor: AppTheme.accentEmerald));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald, foregroundColor: Colors.white),
              child: const Text('Link'),
            ),
          ],
        );
      }),
    );
  }

  /// Storeroom tracking controls for an order card: "Add to Stores" toggle and
  /// the request workflow (PO-gated request button → store request number).
  Widget _buildOrderStoresSection(
    BuildContext context,
    Project project,
    OrderItem order,
    bool isDark,
  ) {
    final notifier = ref.read(projectProvider.notifier);
    final storesColor = order.addToStores
        ? AppTheme.accentEmerald
        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16),
        InkWell(
          onTap: () =>
              notifier.setOrderAddToStores(project.id, order.id, !order.addToStores),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Row(
            children: [
              Icon(Icons.warehouse_outlined, size: 16, color: storesColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add to Stores',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: storesColor,
                  ),
                ),
              ),
              Switch(
                value: order.addToStores,
                activeColor: AppTheme.accentEmerald,
                onChanged: (v) =>
                    notifier.setOrderAddToStores(project.id, order.id, v),
              ),
            ],
          ),
        ),
        if (order.addToStores) ...[
          const SizedBox(height: 6),
          if (order.po.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppTheme.accentAmber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Add a PO number, then request from storeroom.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.accentAmber,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!order.storeRequested)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Request from Stores?'),
                      content: Text(
                        'Send a storeroom request for "${order.description}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Request'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await notifier.markOrderStoreRequested(project.id, order.id);
                  }
                },
                icon: const Icon(Icons.warehouse_rounded, size: 16),
                label: const Text('Request for Stores'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentEmerald,
                  side: const BorderSide(color: AppTheme.accentEmerald),
                ),
              ),
            )
          else if (order.storeRequestNumber.isEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Store request sent — add the request #:',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showStoreRequestNumberDialog(context, project, order),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Add #'),
                ),
              ],
            )
          else
            ExpressiveBadge(
              label: 'Stores #${order.storeRequestNumber} ✓ Requested',
              icon: Icons.warehouse_rounded,
              color: AppTheme.accentEmerald,
              fontSize: 10,
            ),
        ],
      ],
    );
  }

  void _showStoreRequestNumberDialog(
    BuildContext context,
    Project project,
    OrderItem order,
  ) {
    final ctrl = TextEditingController(text: order.storeRequestNumber);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Store Request Number'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Store Request #',
            hintText: 'e.g. 80231',
            prefixIcon: Icon(Icons.warehouse_rounded),
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
                  .setOrderStoreRequestNumber(project.id, order.id, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsAndPhotosTab(BuildContext context, Project project, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo Inspections Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Inspection Photos & Schematics',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Attach Photo'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (project.photoPaths.isEmpty)
            ExpressiveCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 24, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('No photos attached yet. Tap Attach Photo to upload.'),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: project.photoPaths.length,
                itemBuilder: (context, idx) {
                  final path = project.photoPaths[idx];
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, _, __) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),

          // Engineering Field Logs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Engineering Logs (${project.logs.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddLogDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Log Entry'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (project.logs.isEmpty)
            ExpressiveCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_edu_outlined, size: 24, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('No field logs recorded yet.'),
                    ],
                  ),
                ),
              ),
            )
          else
            ...project.logs.map((log) {
              return ExpressiveCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ExpressiveBadge(
                          label: log.type.label,
                          color: log.type == LogType.voice
                              ? AppTheme.accentAmber
                              : (log.type == LogType.milestone
                                  ? AppTheme.accentEmerald
                                  : AppTheme.primaryCyan),
                          fontSize: 10,
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('MMM d, y • h:mm a').format(log.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                          onPressed: () {
                            ref
                                .read(projectProvider.notifier)
                                .deleteProjectLog(project.id, log.id);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      log.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (log.content.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        log.content,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
