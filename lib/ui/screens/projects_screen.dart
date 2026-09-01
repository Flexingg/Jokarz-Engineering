import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final projects = state.filteredProjects;

    // Drag-to-reorder is only meaningful on the unfiltered priority list.
    final isFiltering = state.searchQuery.isNotEmpty ||
        state.selectedCategory != null ||
        state.selectedPhase != null ||
        state.selectedMachine != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Engineering Projects',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.accentAmber),
            tooltip: 'Maintenance Task Calendar',
            onPressed: () => context.push('/calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.queue_play_next_rounded, color: AppTheme.accentEmerald),
            tooltip: 'What\'s Next? Priority Queue',
            onPressed: () => context.push('/projects/queue'),
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded, color: AppTheme.accentAmber),
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
                hintText: 'Search',
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
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Search→Create: if search has text and no results, offer to create with that title
                        if (state.searchQuery.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () => context.push(
                              '/projects/new',
                              extra: {'initialTitle': state.searchQuery},
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: Text('Create "${state.searchQuery}"'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryCyan,
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
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: projects.length,
                        onReorder: (oldIndex, newIndex) {
                          ref
                              .read(projectProvider.notifier)
                              .reorderProjects(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) => _ProjectCard(
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

/// A single project list card. Has a `ValueKey` so it can be used inside a
/// `ReorderableListView` for drag-and-drop priority reordering.
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
          // Top Row: Priority & Category & Phase
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
                      ? AppTheme.accentCoral
                      : (project.priority <= 3
                          ? AppTheme.accentAmber
                          : AppTheme.primaryCyan),
                  fontSize: 11,
                ),
              const SizedBox(width: 6),
              ExpressiveBadge(
                label: project.category.label,
                color: AppTheme.primaryCyan,
                fontSize: 10,
              ),
              const SizedBox(width: 6),
              ExpressiveBadge(
                label: project.phase,
                color: project.phase.toLowerCase() == 'complete'
                    ? AppTheme.accentEmerald
                    : (project.phase.toLowerCase() == 'cancelled'
                        ? AppTheme.accentCoral
                        : AppTheme.accentAmber),
                isOutlined: true,
                fontSize: 10,
              ),
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
              decoration: isTerminal && project.phase.toLowerCase() == 'complete'
                  ? TextDecoration.none
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
                      color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.4), width: 0.6),
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
                            ? AppTheme.accentAmber
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
                              ? AppTheme.accentAmber
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
                color: AppTheme.accentAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions_rounded, size: 14, color: AppTheme.accentAmber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Next: ${nextTask.description}${nextTask.pendingReason.isNotEmpty ? " • ${nextTask.pendingReason}" : ""}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentAmber,
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
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(width: 14),
              ],

              const Spacer(),

              if (project.completedAt != null)
                Text(
                  'Closed ${dateFormat.format(project.completedAt!)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.accentEmerald,
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
