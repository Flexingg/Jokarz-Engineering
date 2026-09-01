import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/activity_log.dart';
import '../../providers/project_provider.dart';
import '../widgets/inbox_quick_capture_modal.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectProvider);

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
              child: const Icon(Icons.flash_on_rounded, color: AppTheme.accentAmber),
            ),
            tooltip: 'Quick-Capture Inbox (${state.unprocessedInboxCount} pending)',
            onPressed: () => context.push('/inbox'),
          ),
          IconButton(
            icon: const Icon(Icons.precision_manufacturing_rounded, color: AppTheme.primaryCyan),
            tooltip: 'Plant Machines Hub',
            onPressed: () => context.push('/machines'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.accentAmber),
            tooltip: 'Maintenance Task Calendar',
            onPressed: () => context.push('/calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_rounded, color: AppTheme.primaryCyan),
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
        backgroundColor: AppTheme.accentAmber,
        foregroundColor: Colors.black87,
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
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
                      child: const Icon(Icons.flash_on_rounded, size: 16, color: AppTheme.accentAmber),
                    ),
                    label: const Text('Triage Inbox', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/machines'),
                    icon: const Icon(Icons.precision_manufacturing_rounded, size: 16, color: AppTheme.primaryCyan),
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
                    icon: const Icon(Icons.storefront_rounded, size: 16, color: AppTheme.accentEmerald),
                    label: const Text('Vendors', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
              _KpiCard(label: 'Tasks Added (7d)', value: tasksAddedWeek, icon: Icons.add_task_rounded, color: AppTheme.primaryCyan),
              const SizedBox(width: 12),
              _KpiCard(label: 'Tasks Closed (7d)', value: tasksClosedWeek, icon: Icons.task_alt_rounded, color: AppTheme.accentEmerald),
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
                        context.push('/projects/${e.project.id}?tab=orders'),
                  )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}


class _KpiCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ]),
      ),
    );
  }
}

class _TodayTile extends StatelessWidget {
  final DateTime today;
  final int taskCount;
  final VoidCallback onTap;
  const _TodayTile({
    required this.today,
    required this.taskCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [AppTheme.primaryBlue.withValues(alpha: 0.28), AppTheme.darkSurface]
                  : [AppTheme.primaryBlue.withValues(alpha: 0.08), AppTheme.lightSurface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryCyan),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(today),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      taskCount == 1
                          ? '1 task due today • tap to open calendar'
                          : '$taskCount tasks due today • tap to open calendar',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryCyan),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactSummary extends StatelessWidget {
  final int activeCount;
  final int maintenance;
  final int kaizen;
  final int capital;
  final double openPoValue;
  final Project? topProject;
  final VoidCallback? onTapTop;
  final VoidCallback? onTapProjects;
  final VoidCallback? onTapOrders;

  const _CompactSummary({
    required this.activeCount,
    required this.maintenance,
    required this.kaizen,
    required this.capital,
    required this.openPoValue,
    required this.topProject,
    this.onTapTop,
    this.onTapProjects,
    this.onTapOrders,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppTheme.primaryBlue.withValues(alpha: 0.25),
                  AppTheme.darkSurface,
                ]
              : [
                  AppTheme.primaryBlue.withValues(alpha: 0.08),
                  AppTheme.lightSurface,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: compact counts + open PO spend
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTapProjects,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  child: Text(
                    '$activeCount Active • $maintenance Maint • $kaizen Kaizen • $capital Capital',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: onTapOrders,
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                child: Text(
                  '${currency.format(openPoValue)} open PO',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Line 2: #1 priority project
          Row(
            children: [
              const Icon(Icons.flag_rounded, size: 14, color: AppTheme.accentCoral),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: onTapTop,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  child: Text(
                    topProject != null ? '#1: ${topProject!.title}' : 'No active projects',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (topProject != null)
                TextButton(
                  onPressed: onTapTop,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Open', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader(this.title, {this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('View All', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint(this.message);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: 16, color: isDark ? Colors.grey : Colors.black38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final Project p;
  final VoidCallback onTap;

  const _ProjectRow({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = p.priority == 1
        ? AppTheme.accentCoral
        : (p.priority <= 3 ? AppTheme.accentAmber : AppTheme.primaryCyan);
    final nextTask = p.nextPendingTask;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 30,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                border: Border.all(color: priorityColor.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text(
                  '#${p.priority}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: priorityColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (nextTask != null)
                    Text(
                      'Next: ${nextTask.description}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (p.machine.isNotEmpty)
                    Text(
                      p.machine,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final Project p;
  final VoidCallback onTap;

  const _QueueRow({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final days = p.daysSinceLastAction;
    final col = days >= 7
        ? Colors.red.shade400
        : (days >= 3 ? AppTheme.accentAmber : Colors.grey);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(Icons.history_rounded, size: 14, color: col),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    days == 1
                        ? 'Last touched 1 day ago • #${p.priority}'
                        : 'Last touched $days days ago • #${p.priority}',
                    style: TextStyle(fontSize: 11, color: col, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final OpenOrderEntry entry;
  final VoidCallback onTap;

  const _OrderRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final order = entry.order;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            _EtaBadge(order.eta!),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.description.isEmpty ? 'Parts / Material Order' : order.description,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${entry.project.title} • PO: ${order.po.isNotEmpty ? order.po : "—"}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              currency.format(order.price),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtaBadge extends StatelessWidget {
  final DateTime eta;
  const _EtaBadge(this.eta);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final etaDate = DateTime(eta.year, eta.month, eta.day);
    final days = etaDate.difference(today).inDays;

    String label;
    Color col;
    if (days < 0) {
      label = '⚠ ${days.abs()}d overdue';
      col = AppTheme.accentCoral;
    } else if (days == 0) {
      label = 'Arriving Today';
      col = AppTheme.accentEmerald;
    } else if (days == 1) {
      label = 'Arriving Tomorrow';
      col = AppTheme.primaryCyan;
    } else {
      label = 'in $days days';
      col = AppTheme.primaryCyan;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        border: Border.all(color: col.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: col,
        ),
      ),
    );
  }
}
