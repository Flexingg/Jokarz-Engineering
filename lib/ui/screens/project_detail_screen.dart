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
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/voice_memo_modal.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

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
    _tabController = TabController(length: 3, vsync: this);
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
                await ref.read(projectProvider.notifier).deleteProject(project.id);
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
          // Badges Row
          Row(
            children: [
              // Category
              ExpressiveBadge(
                label: project.category.label,
                color: AppTheme.primaryCyan,
                fontSize: 11,
              ),
              const SizedBox(width: 8),

              // Priority
              if (isTerminal)
                ExpressiveBadge(
                  label: 'Lifetime #${project.priority} (Closed)',
                  color: Colors.grey,
                  fontSize: 11,
                )
              else
                ExpressiveBadge(
                  label: 'Priority #${project.priority}',
                  color: project.priority == 1
                      ? AppTheme.accentCoral
                      : (project.priority <= 3
                          ? AppTheme.accentAmber
                          : AppTheme.primaryCyan),
                  fontSize: 11,
                ),
              const SizedBox(width: 8),

              // Phase
              ExpressiveBadge(
                label: project.phase,
                color: project.phase.toLowerCase() == 'complete'
                    ? AppTheme.accentEmerald
                    : (project.phase.toLowerCase() == 'cancelled'
                        ? AppTheme.accentCoral
                        : AppTheme.accentAmber),
                fontSize: 11,
              ),

              const Spacer(),

              // Cost
              if (project.cost > 0)
                Text(
                  'Cost: ${currency.format(project.cost)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
            ],
          ),

          // Machine & Sub-Assembly Row
          if (project.machine.isNotEmpty || project.subAssembly.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (project.machine.isNotEmpty) ...[
                  const Icon(Icons.precision_manufacturing_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    project.machine,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
                if (project.machine.isNotEmpty && project.subAssembly.isNotEmpty)
                  const Text('  ▸  ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                if (project.subAssembly.isNotEmpty) ...[
                  const Icon(Icons.account_tree_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    project.subAssembly,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
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

          // Description & Tags
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
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: project.tasks.length,
                  itemBuilder: (context, index) {
                    final task = project.tasks[index];
                    final dateText = task.scheduledDate != null
                        ? DateFormat('MMM d, y').format(task.scheduledDate!)
                        : null;

                    return ExpressiveCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: task.isCompleted,
                            activeColor: AppTheme.accentEmerald,
                            onChanged: (_) {
                              ref
                                  .read(projectProvider.notifier)
                                  .toggleTaskCompleted(project.id, task.id);
                            },
                          ),
                          const SizedBox(width: 6),
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
                ),
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
              ElevatedButton.icon(
                onPressed: () => _showAddOrderDialog(context),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                label: const Text('Add Order'),
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
                      child: Row(
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
                    );
                  },
                ),
        ),
      ],
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
