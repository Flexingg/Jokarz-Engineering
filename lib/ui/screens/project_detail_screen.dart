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
import '../widgets/order_dialogs.dart';
import '../../models/project_log.dart';
import '../../providers/project_provider.dart';
import '../../services/sync_service.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/voice_memo_modal.dart';
import '../widgets/template_dialogs.dart';
import '../widgets/bamm_chip.dart';
import '../widgets/bamm_assign_dialog.dart';

part 'project_detail_parts/dialogs.dart';
part 'project_detail_parts/tabs.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String? initialTab;
  final String? targetOrderId;
  final String? targetTaskId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.initialTab,
    this.targetOrderId,
    this.targetTaskId,
  });

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
    int initialIdx = 0;
    if (widget.initialTab == 'orders' || widget.targetOrderId != null) {
      initialIdx = 1;
    } else if (widget.initialTab == 'logs') {
      initialIdx = 2;
    }
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIdx,
    );

    if (widget.targetOrderId != null || widget.targetTaskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final p = ref.read(projectProvider).projects.where((proj) => proj.id == widget.projectId).firstOrNull;
        if (p == null) return;
        if (widget.targetOrderId != null) {
          final order = p.orders.where((o) => o.id == widget.targetOrderId).firstOrNull;
          if (order != null) {
            _showAddOrderDialog(context, existingOrder: order);
          }
        } else if (widget.targetTaskId != null) {
          final task = p.tasks.where((t) => t.id == widget.targetTaskId).firstOrNull;
          if (task != null) {
            _showAddTaskDialog(context, existingTask: task);
          }
        }
      });
    }
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
            SnackBar(
              content: Text('Photo attached to project!'),
              backgroundColor: AppTheme.of(context).emerald,
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
            icon: Icon(Icons.mic, color: AppTheme.of(context).amber),
            tooltip: 'Dictate Field Log for Project',
            onPressed: () => VoiceMemoModal.show(
              context,
              preselectedProjectId: project.id,
            ),
          ),
          IconButton(
            icon: Icon(Icons.content_copy_rounded, color: AppTheme.of(context).primary),
            tooltip: 'Save as Reusable Template',
            onPressed: () => TemplateDialogs.showSaveAsTemplateDialog(context, ref, project),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: AppTheme.of(context).primary),
            tooltip: 'Edit Project Details',
            onPressed: () => context.push('/projects/${project.id}/edit'),
          ),

          IconButton(
            icon: Icon(Icons.delete_outline, color: AppTheme.of(context).coral),
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.of(context).coral),
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
          indicatorColor: AppTheme.of(context).primary,
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
        ? AppTheme.of(context).coral
        : (project.priority <= 3 ? AppTheme.of(context).amber : AppTheme.of(context).primary);
    final phaseColor = project.phase.toLowerCase() == 'complete'
        ? AppTheme.of(context).emerald
        : (project.phase.toLowerCase() == 'cancelled'
            ? AppTheme.of(context).coral
            : AppTheme.of(context).amber);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.of(context).surface : AppTheme.of(context).surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.of(context).border : AppTheme.of(context).border,
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
                    color: AppTheme.of(context).primary,
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

              // Cost (written cost + attached orders)
              if (project.totalProjectCost > 0)
                Tooltip(
                  message: 'Tap to edit cost',
                  child: InkWell(
                    onTap: () => _showEditCostDialog(context, project),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Cost: ${currency.format(project.totalProjectCost)} ✎',
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

          // Assigned BAMM Work Orders
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...project.bammWorkOrders.map((wo) => BammChip(
                worNo: wo,
                onDeleted: () => ref.read(projectProvider.notifier).removeBammFromProject(project.id, wo),
              )),
              InkWell(
                onTap: () async {
                  final res = await BammAssignDialog.show(context, currentSelections: project.bammWorkOrders);
                  if (res != null) {
                    await ref.read(projectProvider.notifier).setProjectBammWorkOrders(project.id, res);
                  }
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.of(context).primary.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 13, color: AppTheme.of(context).primary),
                      const SizedBox(width: 4),
                      Text(
                        project.bammWorkOrders.isEmpty ? '+ Assign BAMM' : '+ BAMM',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.of(context).primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Completed at indicator
          if (project.completedAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 14, color: AppTheme.of(context).emerald),
                const SizedBox(width: 4),
                Text(
                  'Completed at: ${dateFormat.format(project.completedAt!)}',
                  style: TextStyle(fontSize: 11, color: AppTheme.of(context).emerald, fontWeight: FontWeight.bold),
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
                color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
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
                      color: AppTheme.of(context).primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                      border: Border.all(
                        color: AppTheme.of(context).primaryBlue.withValues(alpha: 0.4),
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
              Icon(Icons.sticky_note_2_outlined, size: 14, color: AppTheme.of(context).amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Project Notes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.of(context).amber,
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
                  foregroundColor: AppTheme.of(context).amber,
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
                color: AppTheme.of(context).amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: AppTheme.of(context).amber.withValues(alpha: 0.3),
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
      color: AppTheme.of(context).amber.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.pending_actions_rounded, size: 18, color: AppTheme.of(context).amber),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: 'NEXT PENDING: ',
                    style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.of(context).amber),
                  ),
                  TextSpan(
                    text: task.description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (task.pendingReason.isNotEmpty)
                    TextSpan(
                      text: ' (${task.pendingReason})',
                      style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.of(context).amber),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
