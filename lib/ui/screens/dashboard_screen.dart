import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/voice_memo_modal.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    final activeProjects = state.activeProjects;
    final openOrders = state.openOrders;
    final maintenanceCount = activeProjects
        .where((p) => p.category == ProjectCategory.maintenance)
        .length;
    final kaizenCount = activeProjects
        .where((p) => p.category == ProjectCategory.kaizen)
        .length;
    final capitalCount = activeProjects
        .where((p) => p.category == ProjectCategory.capital)
        .length;

    final totalOpenOrderValue = openOrders.fold(
      0.0,
      (prev, entry) => prev + entry.order.price,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.precision_manufacturing_rounded, color: AppTheme.primaryCyan),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Jokarz Engineering',
                style: TextStyle(fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.accentAmber),
            tooltip: 'Maintenance Task Calendar',
            onPressed: () => context.push('/calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: AppTheme.accentAmber),
            tooltip: 'Record Field Memo',
            onPressed: () => VoiceMemoModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.primaryCyan),
            tooltip: 'New Project',
            onPressed: () => context.push('/projects/new'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Re-load data if needed
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Engineering Plant HUD Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppTheme.primaryBlue.withValues(alpha: 0.3),
                          AppTheme.darkSurface,
                        ]
                      : [
                          AppTheme.primaryBlue.withValues(alpha: 0.1),
                          AppTheme.lightSurface,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PLANT ENGINEERING WORKSPACE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppTheme.primaryCyan,
                        ),
                      ),
                      ExpressiveBadge(
                        label: 'Live Operations',
                        color: AppTheme.accentEmerald,
                        fontSize: 10,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${activeProjects.length} Active Ranked Projects',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$maintenanceCount Maintenance • $kaizenCount Kaizen • $capitalCount Capital',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metrics Cards Row
            Row(
              children: [
                // Open Orders Card
                Expanded(
                  child: ExpressiveCard(
                    onTap: () => context.go('/orders'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, color: AppTheme.accentAmber, size: 18),
                            Spacer(),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${openOrders.length}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accentAmber,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Open Orders',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          currency.format(totalOpenOrderValue),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Top Priority Project Card
                Expanded(
                  child: ExpressiveCard(
                    onTap: activeProjects.isNotEmpty
                        ? () => context.push('/projects/${activeProjects.first.id}')
                        : null,
                    isGlowing: activeProjects.isNotEmpty,
                    glowColor: AppTheme.accentCoral,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.flag_rounded, color: AppTheme.accentCoral, size: 18),
                            Spacer(),
                            ExpressiveBadge(
                              label: '#1 Urgent',
                              color: AppTheme.accentCoral,
                              fontSize: 9,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activeProjects.isNotEmpty
                              ? activeProjects.first.title
                              : 'No Active Projects',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeProjects.isNotEmpty
                              ? (activeProjects.first.machine.isNotEmpty
                                  ? activeProjects.first.machine
                                  : activeProjects.first.phase)
                              : 'All Complete',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Priority Projects Feed
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top Priority Projects',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go('/projects'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (activeProjects.isEmpty)
              ExpressiveCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 40, color: AppTheme.accentEmerald),
                        const SizedBox(height: 8),
                        const Text(
                          'No Active Engineering Projects',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create a project or log plant maintenance.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...activeProjects.take(3).map((project) {
                final nextTask = project.nextPendingTask;
                return ExpressiveCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  onTap: () => context.push('/projects/${project.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ExpressiveBadge(
                            label: '#${project.priority}',
                            color: project.priority == 1
                                ? AppTheme.accentCoral
                                : AppTheme.accentAmber,
                            fontSize: 10,
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
                            color: AppTheme.primaryBlue,
                            isOutlined: true,
                            fontSize: 10,
                          ),
                          const Spacer(),
                          if (project.machine.isNotEmpty)
                            Text(
                              project.machine,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        project.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (nextTask != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pending_actions_rounded, size: 13, color: AppTheme.accentAmber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Next: ${nextTask.description}${nextTask.pendingReason.isNotEmpty ? " • ${nextTask.pendingReason}" : ""}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.accentAmber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),

            const SizedBox(height: 16),

            // Open Purchase Orders Preview
            if (openOrders.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Open Purchase Orders',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => context.go('/orders'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...openOrders.take(2).map((entry) {
                return ExpressiveCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () => context.push('/projects/${entry.project.id}'),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: AppTheme.accentAmber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.order.description,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${entry.project.title} • PO: ${entry.order.po.isNotEmpty ? entry.order.po : "Pending"}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(entry.order.price),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => VoiceMemoModal.show(context),
        child: const Icon(Icons.mic_rounded),
      ),
    );
  }
}
