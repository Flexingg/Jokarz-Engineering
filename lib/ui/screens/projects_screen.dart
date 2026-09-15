import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/bamm_chip.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  bool _denseView = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    final projects = state.filteredProjects;

    // Drag-to-reorder is only meaningful on the unfiltered priority list.
    final isFiltering = state.searchQuery.isNotEmpty ||
        state.selectedCategory != null ||
        state.selectedPhase != null ||
        state.selectedMachine != null;

    final showDense = isDesktop && _denseView;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Engineering Projects',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isDesktop)
            IconButton(
              icon: Icon(
                _denseView ? Icons.view_agenda_outlined : Icons.table_rows_rounded,
                color: AppTheme.of(context).primary,
              ),
              tooltip: _denseView ? 'Switch to Card View' : 'Switch to Compact Desktop Rows',
              onPressed: () => setState(() => _denseView = !_denseView),
            ),
          IconButton(
            icon: Icon(Icons.calendar_month_rounded, color: AppTheme.of(context).amber),
            tooltip: 'Maintenance Task Calendar',
            onPressed: () => context.push('/calendar'),
          ),
          IconButton(
            icon: Icon(Icons.queue_play_next_rounded, color: AppTheme.of(context).emerald),
            tooltip: 'What\'s Next? Priority Queue',
            onPressed: () => context.push('/projects/queue'),
          ),
          IconButton(
            icon: Icon(Icons.print_rounded, color: AppTheme.of(context).amber),
            tooltip: 'Daily Walk-Around Report',
            onPressed: () => context.push('/report'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search projects, machines, subassemblies...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => notifier.setSearchQuery(''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => notifier.setSearchQuery(val),
            ),
          ),

          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Category Filter
                FilterChip(
                  label: const Text('All Categories'),
                  selected: state.selectedCategory == null,
                  onSelected: (_) => notifier.filterCategory(null),
                ),
                const SizedBox(width: 8),
                ...ProjectCategory.values.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat.label),
                      selected: state.selectedCategory == cat,
                      onSelected: (selected) =>
                          notifier.filterCategory(selected ? cat : null),
                    ),
                  ),
                ),
                const VerticalDivider(width: 16),

                // Phase Filter
                FilterChip(
                  label: const Text('All Phases'),
                  selected: state.selectedPhase == null,
                  onSelected: (_) => notifier.filterPhase(null),
                ),
                const SizedBox(width: 8),
                ...state.availablePhases.map(
                  (ph) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(ph),
                      selected: state.selectedPhase?.toLowerCase() == ph.toLowerCase(),
                      onSelected: (selected) =>
                          notifier.filterPhase(selected ? ph : null),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Projects List
          Expanded(
            child: projects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.engineering_outlined,
                          size: 56,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No engineering projects found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.searchQuery.isNotEmpty
                              ? 'No matches — create it now?'
                              : 'Tap + to create a new project',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (state.searchQuery.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () => context.push(
                              '/projects/new',
                              extra: {'initialTitle': state.searchQuery},
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: Text('Create "${state.searchQuery}"'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.of(context).primary,
                              foregroundColor: Colors.white,
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () => context.push('/projects/new'),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Project'),
                          ),
                      ],
                    ),
                  )
                : (isFiltering
                    ? ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: projects.length,
                        itemBuilder: (context, index) => showDense
                            ? _DesktopProjectRow(
                                key: ValueKey(projects[index].id),
                                project: projects[index],
                                index: index,
                                canReorder: false,
                              )
                            : _ProjectCard(
                                key: ValueKey(projects[index].id),
                                project: projects[index],
                              ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: projects.length,
                        onReorder: (oldIndex, newIndex) {
                          notifier.reorderProjects(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) => showDense
                            ? _DesktopProjectRow(
                                key: ValueKey(projects[index].id),
                                project: projects[index],
                                index: index,
                                canReorder: true,
                              )
                            : _ProjectCard(
                                key: ValueKey(projects[index].id),
                                project: projects[index],
                              ),
                      )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }
}

/// Interactive Status/Phase Selector Badge.
/// Allows instant status updating directly from overview in 1 click!
class _EditablePhaseBadge extends ConsumerWidget {
  final Project project;

  const _EditablePhaseBadge({required this.project});

  Color _getPhaseColor(BuildContext context, String phase) {
    final lower = phase.trim().toLowerCase();
    if (lower == 'complete' || lower == 'completed') {
      return AppTheme.of(context).emerald;
    } else if (lower == 'cancelled' || lower == 'canceled') {
      return AppTheme.of(context).coral;
    } else if (lower == 'validation') {
      return Colors.tealAccent.shade700;
    } else if (lower == 'installation') {
      return AppTheme.of(context).primary;
    } else if (lower == 'pending') {
      return AppTheme.of(context).amber;
    } else if (lower == 'idea') {
      return Colors.orangeAccent;
    }
    return AppTheme.of(context).amber;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availablePhases = ref.watch(projectProvider).availablePhases;
    final phaseColor = _getPhaseColor(context, project.phase);

    return Tooltip(
      message: 'Click to change status',
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: PopupMenuButton<String>(
          tooltip: 'Change project status',
          padding: EdgeInsets.zero,
          initialValue: project.phase,
          onSelected: (newPhase) async {
            if (newPhase == project.phase) return;
            await ref.read(projectProvider.notifier).updateProject(
                  project.copyWith(phase: newPhase),
                );
          },
          itemBuilder: (context) {
            return availablePhases.map((phase) {
              final color = _getPhaseColor(context, phase);
              final isSelected = phase.toLowerCase() == project.phase.toLowerCase();
              return PopupMenuItem<String>(
                value: phase,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        phase,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? color : null,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_rounded, size: 16, color: color),
                  ],
                ),
              );
            }).toList();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: phaseColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: phaseColor.withValues(alpha: 0.6), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: phaseColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  project.phase,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: phaseColor,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 16,
                  color: phaseColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Optimized Desktop Row: Shows 12-15 projects at once with next action easily visible,
/// editable status, drag-and-drop handle, and detailed engineering stats.
class _DesktopProjectRow extends ConsumerWidget {
  final Project project;
  final int index;
  final bool canReorder;

  const _DesktopProjectRow({
    super.key,
    required this.project,
    required this.index,
    required this.canReorder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final isTerminal = project.isCompletedOrCancelled;
    final nextTask = project.nextPendingTask;

    return ExpressiveCard(
      key: ValueKey(project.id),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onTap: () => context.push('/projects/${project.id}'),
      child: Row(
        children: [
          // Drag Grip Handle (re-prioritization)
          if (canReorder)
            ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 4),

          // Priority Badge
          if (isTerminal)
            const ExpressiveBadge(
              label: 'Done',
              color: Colors.grey,
              fontSize: 10,
            )
          else
            ExpressiveBadge(
              label: '#${project.priority}',
              color: project.priority == 1
                  ? AppTheme.of(context).coral
                  : (project.priority <= 3
                      ? AppTheme.of(context).amber
                      : AppTheme.of(context).primary),
              fontSize: 11,
            ),
          const SizedBox(width: 10),

          // Project Title & Machine/SubAssembly (Flexible width)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        project.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isTerminal ? Colors.grey : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ExpressiveBadge(
                      label: project.category.label,
                      color: AppTheme.of(context).primary,
                      fontSize: 9,
                    ),
                    if (project.bammWorkOrders.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      ...project.bammWorkOrders.take(2).map((wo) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: BammChip(worNo: wo, isDense: true),
                          )),
                      if (project.bammWorkOrders.length > 2)
                        Text(
                          '+${project.bammWorkOrders.length - 2}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (project.machine.isNotEmpty) ...[
                      Icon(Icons.precision_manufacturing_outlined, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          project.machine,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (project.subAssembly.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('•', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          project.subAssembly,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // NEXT ACTION SECTION (Prominently visible!)
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (nextTask != null && !isTerminal)
                    ? AppTheme.of(context).amber.withValues(alpha: 0.12)
                    : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: (nextTask != null && !isTerminal)
                      ? AppTheme.of(context).amber.withValues(alpha: 0.35)
                      : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    (nextTask != null && !isTerminal)
                        ? Icons.pending_actions_rounded
                        : (isTerminal ? Icons.check_circle_outline_rounded : Icons.task_alt_rounded),
                    size: 14,
                    color: (nextTask != null && !isTerminal)
                        ? AppTheme.of(context).amber
                        : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isTerminal
                          ? 'Project Complete / Closed'
                          : (nextTask != null
                              ? 'Next: ${nextTask.description}'
                              : 'No pending actions'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: (nextTask != null && !isTerminal)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: (nextTask != null && !isTerminal)
                            ? (isDark ? Colors.amber.shade200 : Colors.amber.shade900)
                            : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (nextTask != null && nextTask.pendingReason.isNotEmpty && !isTerminal) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.of(context).coral.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⏳ ${nextTask.pendingReason}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.of(context).coral,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Stats: Tasks & Orders
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.checklist_rounded, size: 14, color: isDark ? Colors.grey : Colors.black45),
              const SizedBox(width: 4),
              Text(
                '${project.completedTasksCount}/${project.tasks.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              if (project.orders.isNotEmpty) ...[
                Icon(Icons.local_shipping_outlined, size: 14, color: isDark ? Colors.grey : Colors.black45),
                const SizedBox(width: 4),
                Text(
                  '${project.orders.length}${project.undeliveredOrdersCount > 0 ? " (${project.undeliveredOrdersCount} open)" : ""}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: project.undeliveredOrdersCount > 0
                        ? AppTheme.of(context).amber
                        : (isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),

          // Total Project Cost
          if (project.totalProjectCost > 0) ...[
            SizedBox(
              width: 75,
              child: Text(
                currency.format(project.totalProjectCost),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),
          ] else ...[
            const SizedBox(width: 12),
          ],

          // EDITABLE STATUS BADGE
          _EditablePhaseBadge(project: project),
          const SizedBox(width: 6),

          // Navigate Arrow
          Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

/// A single project list card (used on mobile and when expanded card view is toggled).
class _ProjectCard extends ConsumerWidget {
  final Project project;
  const _ProjectCard({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, y');
    final isTerminal = project.isCompletedOrCancelled;
    final nextTask = project.nextPendingTask;

    return ExpressiveCard(
      key: ValueKey(project.id),
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push('/projects/${project.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Priority & Category & Editable Phase
          Row(
            children: [
              if (isTerminal)
                ExpressiveBadge(
                  label: 'Prev #${project.priority}',
                  color: Colors.grey,
                  fontSize: 10,
                )
              else
                ExpressiveBadge(
                  label: '#${project.priority}',
                  color: project.priority == 1
                      ? AppTheme.of(context).coral
                      : (project.priority <= 3
                          ? AppTheme.of(context).amber
                          : AppTheme.of(context).primary),
                  fontSize: 11,
                ),
              const SizedBox(width: 6),
              ExpressiveBadge(
                label: project.category.label,
                color: AppTheme.of(context).primary,
                fontSize: 10,
              ),
              const SizedBox(width: 6),
              _EditablePhaseBadge(project: project),
              const Spacer(),
              if (project.totalProjectCost > 0)
                Text(
                  currency.format(project.totalProjectCost),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            project.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isTerminal
                  ? (isDark ? Colors.grey : Colors.black54)
                  : null,
            ),
          ),
          const SizedBox(height: 4),

          // Machine chips (split on /) + Sub-Assembly
          if (project.machine.isNotEmpty || project.subAssembly.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 2,
                children: [
                  const Icon(Icons.precision_manufacturing_outlined, size: 13, color: Colors.grey),
                  ...project.machineList.map((m) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.of(context).primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.of(context).primary.withValues(alpha: 0.4), width: 0.6),
                    ),
                    child: Text(m, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                  )),
                  if (project.subAssembly.isNotEmpty) ...[
                    const Icon(Icons.account_tree_outlined, size: 13, color: Colors.grey),
                    Text(project.subAssembly, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),

          // BAMM Work Orders
          if (project.bammWorkOrders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: project.bammWorkOrders
                    .map((wo) => BammChip(worNo: wo, isDense: true))
                    .toList(),
              ),
            ),

          // Last action badge (only active projects)
          if (!isTerminal && project.daysSinceLastAction > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 12,
                    color: project.daysSinceLastAction >= 7
                        ? Colors.red.shade400
                        : project.daysSinceLastAction >= 3
                            ? AppTheme.of(context).amber
                            : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    project.daysSinceLastAction == 1
                        ? 'Last action: 1 day ago'
                        : 'Last action: ${project.daysSinceLastAction}d ago',
                    style: TextStyle(
                      fontSize: 10,
                      color: project.daysSinceLastAction >= 7
                          ? Colors.red.shade400
                          : project.daysSinceLastAction >= 3
                              ? AppTheme.of(context).amber
                              : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

          // Next Pending Task Banner
          if (nextTask != null && !isTerminal)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.of(context).amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.of(context).amber.withValues(alpha: 0.3), width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.pending_actions_rounded, size: 14, color: AppTheme.of(context).amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Next: ${nextTask.description}${nextTask.pendingReason.isNotEmpty ? " • ${nextTask.pendingReason}" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.of(context).amber,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 6),

          // Footer: Tasks count, Orders count, CompletedAt
          Row(
            children: [
              Icon(Icons.checklist_rounded, size: 14, color: isDark ? Colors.grey : Colors.black45),
              const SizedBox(width: 4),
              Text(
                '${project.completedTasksCount}/${project.tasks.length} Tasks',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                ),
              ),
              const SizedBox(width: 14),

              if (project.orders.isNotEmpty) ...[
                Icon(Icons.local_shipping_outlined, size: 14, color: isDark ? Colors.grey : Colors.black45),
                const SizedBox(width: 4),
                Text(
                  '${project.orders.length} Orders (${project.undeliveredOrdersCount} open)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
              ],

              const Spacer(),

              if (project.completedAt != null)
                Text(
                  'Closed ${dateFormat.format(project.completedAt!)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.of(context).emerald,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
