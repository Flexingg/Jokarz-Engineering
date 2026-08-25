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
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    final filtered = state.filteredProjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Engineering Projects & Builds',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primaryCyan),
            onPressed: () => context.push('/projects/new'),
            tooltip: 'New Project',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
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
              children: [
                // Search Input
                TextField(
                  onChanged: notifier.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search CAD files, parts, tags, descriptions...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: state.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => notifier.setSearchQuery(''),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),

                // Category Filter Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Categories'),
                        selected: state.selectedCategory == null,
                        onSelected: (_) => notifier.filterCategory(null),
                      ),
                      const SizedBox(width: 6),
                      ...ProjectCategory.values.map(
                        (cat) => Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: FilterChip(
                            label: Text(cat.label),
                            selected: state.selectedCategory == cat,
                            onSelected: (sel) =>
                                notifier.filterCategory(sel ? cat : null),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Project List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          state.searchQuery.isNotEmpty || state.selectedCategory != null
                              ? 'No projects match your filter'
                              : 'No engineering projects yet',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/projects/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create New Project'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final project = filtered[index];
                      return _buildProjectCard(context, project, currency, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    Project project,
    NumberFormat currency,
    bool isDark,
  ) {
    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 14),
      onTap: () => context.push('/projects/${project.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExpressiveBadge(
                label: project.category.label,
                color: AppTheme.primaryCyan,
                fontSize: 11,
              ),
              const SizedBox(width: 8),
              ExpressiveBadge(
                label: project.status.label,
                color: project.status == ProjectStatus.complete
                    ? AppTheme.accentEmerald
                    : AppTheme.accentAmber,
                fontSize: 11,
              ),
              const Spacer(),
              if (project.priority == ProjectPriority.critical)
                const ExpressiveBadge(
                  label: 'CRITICAL',
                  color: AppTheme.accentCoral,
                  fontSize: 10,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            project.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: 4),
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
          const SizedBox(height: 12),

          // Chips for Estimated print hours & BOM Count
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (project.estimatedPrintHours > 0)
                _buildInfoChip(
                  Icons.timer_outlined,
                  '${project.estimatedPrintHours}h print',
                  AppTheme.primaryCyan,
                  isDark,
                ),
              if (project.estimatedFilamentGrams > 0)
                _buildInfoChip(
                  Icons.scale_outlined,
                  '${project.estimatedFilamentGrams}g filament',
                  AppTheme.accentPurple,
                  isDark,
                ),
              _buildInfoChip(
                Icons.receipt_outlined,
                '${project.bom.length} BOM parts (${currency.format(project.totalBOMCost)})',
                AppTheme.accentEmerald,
                isDark,
              ),
              _buildInfoChip(
                Icons.notes_rounded,
                '${project.logs.length} logs',
                AppTheme.accentAmber,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sourcing Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: project.bomCompletionRatio,
                    backgroundColor: isDark ? AppTheme.darkSurfaceHighlight : AppTheme.lightSurfaceHighlight,
                    color: AppTheme.accentEmerald,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(project.bomCompletionRatio * 100).toStringAsFixed(0)}% Sourced',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceHighlight : AppTheme.lightSurfaceHighlight,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
