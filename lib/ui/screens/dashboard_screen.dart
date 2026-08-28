import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../widgets/voice_memo_modal.dart';
import '../widgets/sync_status_badge.dart';

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
          const SyncStatusBadge(compact: true),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.accentAmber),
            tooltip: 'Maintenance Task Calendar',
            onPressed: () => context.push('/calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppTheme.primaryCyan),
            tooltip: 'Search & Quick Add',
            onPressed: () => context.push('/search'),
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
          const SizedBox(width: 4),
        ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/search'),
        tooltip: 'Search & Quick Add',
        child: const Icon(Icons.search),
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
