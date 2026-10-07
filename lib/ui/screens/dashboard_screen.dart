import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/activity_log.dart';
import '../../providers/project_provider.dart';
import '../../providers/ui_prefs_provider.dart';
import '../motion/motion.dart';
import '../widgets/dashboard_customizer.dart';
import '../widgets/inbox_quick_capture_modal.dart';

part 'dashboard_parts/cards.dart';
part 'dashboard_parts/rows.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectProvider);
    final prefs = ref.watch(uiPrefsProvider);

    final activeProjects = state.activeProjects;
    final maintenanceCount = activeProjects
        .where((p) => p.category == ProjectCategory.maintenance)
        .length;
    final kaizenCount =
        activeProjects.where((p) => p.category == ProjectCategory.kaizen).length;
    final capitalCount =
        activeProjects.where((p) => p.category == ProjectCategory.capital).length;
    final totalOpenOrderValue = state.openOrders.fold(
      0.0,
      (prev, e) => prev + e.order.price,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int todayTaskCount = 0;
    for (final p in state.projects) {
      for (final t in p.tasks) {
        if (!t.isCompleted && t.scheduledDate != null &&
            DateUtils.isSameDay(t.scheduledDate!, today)) {
          todayTaskCount++;
        }
      }
    }
    final weekAgo = now.subtract(const Duration(days: 7));
    int tasksAddedWeek = 0, tasksClosedWeek = 0;
    for (final l in state.activityLog) {
      if (l.timestamp.isAfter(weekAgo)) {
        if (l.type == ActivityType.taskAdded) {
          tasksAddedWeek++;
        } else if (l.type == ActivityType.taskCompleted) {
          tasksClosedWeek++;
        }
      }
    }
    // Open orders due within the next 14 days (including overdue), by ETA.
    final dueOrders = state.openOrders
        .where((e) => e.order.eta != null)
        .where((e) {
          final eta = e.order.eta!;
          final days = DateTime(eta.year, eta.month, eta.day).difference(today).inDays;
          return days <= 14;
        })
        .toList();
    final queue = state.queuedProjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: state.unprocessedInboxCount > 0,
              label: Text('${state.unprocessedInboxCount}'),
              child: Icon(Icons.flash_on_rounded, color: AppTheme.of(context).amber),
            ),
            tooltip: 'Inbox (${state.unprocessedInboxCount} pending)',
            onPressed: () => context.push('/inbox'),
          ),
          IconButton(
            icon: Icon(Icons.precision_manufacturing_rounded, color: AppTheme.of(context).primary),
            tooltip: 'Plant Machines Hub',
            onPressed: () => context.push('/machines'),
          ),
          IconButton(
            icon: Icon(Icons.calendar_month_rounded, color: AppTheme.of(context).amber),
            tooltip: 'Maintenance Task Calendar',
            onPressed: () => context.push('/calendar'),
          ),
          IconButton(
            icon: Icon(Icons.view_timeline_rounded, color: AppTheme.of(context).primary),
            tooltip: 'Day Schedule (time blocking)',
            onPressed: () => context.push('/schedule'),
          ),
          if (MediaQuery.sizeOf(context).width >= 900)
            IconButton(
              icon: Icon(Icons.tune_rounded, color: AppTheme.of(context).textSecondary),
              tooltip: 'Customize dashboard',
              onPressed: () => showDashboardCustomizer(context),
            ),
          IconButton(
            icon: Icon(Icons.account_circle_rounded, color: AppTheme.of(context).primary),
            tooltip: 'Settings & Account',
            onPressed: () => context.go('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => InboxQuickCaptureModal.show(context),
        icon: const Icon(Icons.flash_on_rounded),
        label: const Text('Quick Dump'),
        backgroundColor: AppTheme.of(context).amber,
        foregroundColor: Colors.black87,
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            if (!isDesktop) {
              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Compact Plant Summary
                  _CompactSummary(
                    activeCount: activeProjects.length,
                    maintenance: maintenanceCount,
                    kaizen: kaizenCount,
                    capital: capitalCount,
                    openPoValue: totalOpenOrderValue,
                    topProject: activeProjects.isNotEmpty ? activeProjects.first : null,
                    onTapTop: activeProjects.isNotEmpty
                        ? () => context.push('/projects/${activeProjects.first.id}')
                        : null,
                    onTapProjects: () => context.go('/projects'),
                    onTapOrders: () => context.go('/orders'),
                  ),
                  const SizedBox(height: 12),

                  // Plant Hub Shortcuts Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/inbox'),
                          icon: Badge(
                            isLabelVisible: state.unprocessedInboxCount > 0,
                            label: Text('${state.unprocessedInboxCount}'),
                            child: Icon(Icons.flash_on_rounded, size: 16, color: AppTheme.of(context).amber),
                          ),
                          label: const Text('Inbox', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/machines'),
                          icon: Icon(Icons.precision_manufacturing_rounded, size: 16, color: AppTheme.of(context).primary),
                          label: const Text('Machines', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/vendors'),
                          icon: Icon(Icons.storefront_rounded, size: 16, color: AppTheme.of(context).emerald),
                          label: const Text('Vendors', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/bamm'),
                          icon: Icon(Icons.construction_rounded, size: 16, color: AppTheme.of(context).primary),
                          label: const Text('BAMM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _TodayTile(
                    today: today,
                    taskCount: todayTaskCount,
                    onTap: () => context.push('/calendar'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    _KpiCard(label: 'Tasks Added (7d)', value: tasksAddedWeek, icon: Icons.add_task_rounded, color: AppTheme.of(context).primary),
                    const SizedBox(width: 12),
                    _KpiCard(label: 'Tasks Closed (7d)', value: tasksClosedWeek, icon: Icons.task_alt_rounded, color: AppTheme.of(context).emerald),
                  ]),
                  const SizedBox(height: 20),

                  // Top Priority
                  _SectionHeader(
                    'Top Priority',
                    onViewAll: () => context.go('/projects'),
                  ),
                  const SizedBox(height: 4),
                  if (activeProjects.isEmpty)
                    const _EmptyHint(
                      'No active projects. Tap ＋ to create one.',
                    )
                  else
                    ...activeProjects.take(5).map((p) => _ProjectRow(
                          p: p,
                          onTap: () => context.push('/projects/${p.id}'),
                        )),
                  const SizedBox(height: 18),

                  // Needs Attention (queue: not worked on recently)
                  _SectionHeader(
                    'Needs Attention',
                    onViewAll: () => context.push('/projects/queue'),
                  ),
                  const SizedBox(height: 4),
                  if (queue.isEmpty)
                    const _EmptyHint('Nothing sitting untouched. Nice.')
                  else
                    ...queue.take(5).map((p) => _QueueRow(
                          p: p,
                          onTap: () => context.push('/projects/${p.id}'),
                        )),
                  const SizedBox(height: 18),

                  // Orders Due Soon
                  _SectionHeader(
                    'Orders Due Soon',
                    onViewAll: () => context.go('/orders'),
                  ),
                  const SizedBox(height: 4),
                  if (dueOrders.isEmpty)
                    const _EmptyHint('No orders due in the next 14 days.')
                  else
                    ...dueOrders.take(6).map((e) => _OrderRow(
                          entry: e,
                          onTap: () =>
                              context.push('/projects/${e.project.id}?tab=orders&orderId=${e.order.id}'),
                        )),
                  const SizedBox(height: 12),
                ],
              );
            }

            // Desktop: independent sections the user can reorder and hide
            // (Customize in the app bar). Two columns on wide windows.
            final ids = dashboardSectionIds
                .where((id) => !prefs.dashboardHidden.contains(id))
                .toList();
            final ordered = <String>[
              ...prefs.dashboardOrder.where(ids.contains),
              ...ids.where((id) => !prefs.dashboardOrder.contains(id)),
            ];

            Widget section(String id) {
              switch (id) {
                case 'summary':
                  return Column(
                    children: [
                      _CompactSummary(
                        activeCount: activeProjects.length,
                        maintenance: maintenanceCount,
                        kaizen: kaizenCount,
                        capital: capitalCount,
                        openPoValue: totalOpenOrderValue,
                        topProject: activeProjects.isNotEmpty ? activeProjects.first : null,
                        onTapTop: activeProjects.isNotEmpty
                            ? () => context.push('/projects/${activeProjects.first.id}')
                            : null,
                        onTapProjects: () => context.go('/projects'),
                        onTapOrders: () => context.go('/orders'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/inbox'),
                              icon: Badge(
                                isLabelVisible: state.unprocessedInboxCount > 0,
                                label: Text('${state.unprocessedInboxCount}'),
                                child: Icon(Icons.flash_on_rounded, size: 16, color: AppTheme.of(context).amber),
                              ),
                              label: const Text('Inbox'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/machines'),
                              icon: Icon(Icons.precision_manufacturing_rounded, size: 16, color: AppTheme.of(context).primary),
                              label: const Text('Machines'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/vendors'),
                              icon: Icon(Icons.storefront_rounded, size: 16, color: AppTheme.of(context).emerald),
                              label: const Text('Vendors'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/bamm'),
                              icon: Icon(Icons.construction_rounded, size: 16, color: AppTheme.of(context).primary),
                              label: const Text('BAMM'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                case 'today':
                  return Column(
                    children: [
                      _TodayTile(
                        today: today,
                        taskCount: todayTaskCount,
                        onTap: () => context.push('/calendar'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _KpiCard(label: 'Tasks Added (7d)', value: tasksAddedWeek, icon: Icons.add_task_rounded, color: AppTheme.of(context).primary),
                          const SizedBox(width: 10),
                          _KpiCard(label: 'Tasks Closed (7d)', value: tasksClosedWeek, icon: Icons.task_alt_rounded, color: AppTheme.of(context).emerald),
                        ],
                      ),
                    ],
                  );
                case 'priority':
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader('Top Priority Projects', onViewAll: () => context.go('/projects')),
                      const SizedBox(height: 6),
                      if (activeProjects.isEmpty)
                        const _EmptyHint('No active projects. Tap ＋ to create one.')
                      else
                        ...activeProjects.take(6).map((p) => _ProjectRow(
                              p: p,
                              onTap: () => context.push('/projects/${p.id}'),
                            )),
                    ],
                  );
                case 'attention':
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader('Needs Attention (Untouched)', onViewAll: () => context.push('/projects/queue')),
                      const SizedBox(height: 6),
                      if (queue.isEmpty)
                        const _EmptyHint('Nothing sitting untouched. Nice.')
                      else
                        ...queue.take(6).map((p) => _QueueRow(
                              p: p,
                              onTap: () => context.push('/projects/${p.id}'),
                            )),
                    ],
                  );
                default: // 'orders'
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader('Orders Due Soon (Next 14 Days)', onViewAll: () => context.go('/orders')),
                      const SizedBox(height: 6),
                      if (dueOrders.isEmpty)
                        const _EmptyHint('No orders due in the next 14 days.')
                      else
                        ...dueOrders.take(8).map((e) => _OrderRow(
                              entry: e,
                              onTap: () => context.push(
                                  '/projects/${e.project.id}?tab=orders&orderId=${e.order.id}'),
                            )),
                    ],
                  );
              }
            }

            return ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                if (ordered.isEmpty)
                  const _EmptyHint('Every dashboard section is hidden. Use Customize to bring some back.')
                else
                  LayoutBuilder(builder: (context, c) {
                    const gap = 20.0;
                    final half = (c.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: 24,
                      children: [
                        for (var i = 0; i < ordered.length; i++)
                          SizedBox(
                            key: ValueKey(ordered[i]),
                            width: half,
                            child: StaggerIn(index: i, child: section(ordered[i])),
                          ),
                      ],
                    );
                  }),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}

