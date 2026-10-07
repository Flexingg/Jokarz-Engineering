part of '../dashboard_screen.dart';

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
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$value',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
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
                  ? [AppTheme.of(context).primaryBlue.withValues(alpha: 0.28), AppTheme.of(context).surface]
                  : [AppTheme.of(context).primaryBlue.withValues(alpha: 0.08), AppTheme.of(context).surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.of(context).primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: AppTheme.of(context).primary),
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
              Icon(Icons.chevron_right_rounded, color: AppTheme.of(context).primary),
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
                  AppTheme.of(context).primaryBlue.withValues(alpha: 0.25),
                  AppTheme.of(context).surface,
                ]
              : [
                  AppTheme.of(context).primaryBlue.withValues(alpha: 0.08),
                  AppTheme.of(context).surface,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.of(context).primary.withValues(alpha: 0.3)),
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.of(context).amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Line 2: #1 priority project
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 14, color: AppTheme.of(context).coral),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: onTapTop,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  child: Text(
                    topProject != null ? '#1: ${topProject!.title}' : 'No active projects',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
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
