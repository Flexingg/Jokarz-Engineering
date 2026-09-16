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
import '../adaptive/breakpoints.dart';
import '../adaptive/master_detail.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = Breakpoints.isExpanded(screenWidth);

    final projects = state.filteredProjects;

    // Drag-to-reorder is only meaningful on the unfiltered priority list.
    final isFiltering = state.searchQuery.isNotEmpty ||
        state.selectedCategory != null ||
        state.selectedPhase != null ||
        state.selectedMachine != null;

    void selectProject(String id) {
      if (isDesktop) {
        setState(() => _selectedProjectId = id);
      } else {
        context.push('/projects/$id');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Engineering Projects',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
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
      body: AdaptiveMasterDetail(
        masterWidth: 420,
        list: Column(
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
                        itemBuilder: (context, index) => _ProjectCard(
                                key: ValueKey(projects[index].id),
                                project: projects[index],
                                onTap: () => selectProject(projects[index].id),
                              ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: projects.length,
                        onReorder: (oldIndex, newIndex) {
                          notifier.reorderProjects(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) => _ProjectCard(
                                key: ValueKey(projects[index].id),
                                project: projects[index],
                                onTap: () => selectProject(projects[index].id),
                              ),
                      )),
          ),
        ],
        ),
        detailBuilder: (ctx) {
          final effectiveId = _selectedProjectId ?? (projects.isNotEmpty ? projects.first.id : null);
          if (effectiveId == null) {
            return const Center(child: Text('Select a project to view details'));
          }
          return ProjectDetailScreen(projectId: effectiveId);
        },
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

/// A single project list card (used on mobile and when expanded card view is toggled).
class _ProjectCard extends ConsumerWidget {
  final Project project;
  final VoidCallback onTap;
  const _ProjectCard({super.key, required this.project, required this.onTap});

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
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Priority & Category & Editable Phase
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                    ExpressiveBadge(
                      label: project.category.label,
                      color: AppTheme.of(context).primary,
                      fontSize: 10,
                    ),
                    _EditablePhaseBadge(project: project),
                  ],
                ),
              ),
              if (project.totalProjectCost > 0) ...[
                const SizedBox(width: 6),
                Text(
                  currency.format(project.totalProjectCost),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
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
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(Icons.checklist_rounded, size: 14, color: isDark ? Colors.grey : Colors.black45),
                    Text(
                      '${project.completedTasksCount}/${project.tasks.length} Tasks',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                      ),
                    ),
                    if (project.orders.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.local_shipping_outlined, size: 14, color: isDark ? Colors.grey : Colors.black45),
                      Text(
                        '${project.orders.length} Orders (${project.undeliveredOrdersCount} open)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (project.completedAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  'Closed ${dateFormat.format(project.completedAt!)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.of(context).emerald,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
