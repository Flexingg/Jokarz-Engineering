part of '../dashboard_screen.dart';

class _KpiCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final AppSection section;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.section});

  @override
  Widget build(BuildContext context) {
    final c = sectionColors(context, section);
    final base = AppTheme.of(context);
    // A card washed with its section's colour from the corner, a colourful
    // tile, and the number in the colour's readable shade.
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(c.primaryFill.withValues(alpha: 0.20), base.surface),
              base.surface,
            ],
            stops: const [0, 0.75],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: c.primaryFill.withValues(alpha: 0.30)),
        ),
        child: Row(children: [
          SectionTile(hue: c.primaryFill, icon: icon, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$value',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.primary)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: base.textSecondary),
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
    final cal = sectionColors(context, AppSection.calendar);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.alphaBlend(cal.primaryFill.withValues(alpha: 0.20), AppTheme.of(context).surface),
                AppTheme.of(context).surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: cal.primaryFill.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              SectionTile(hue: cal.primaryFill, icon: Icons.calendar_month_rounded, size: 34),
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
                      style: TextStyle(fontSize: 11, color: AppTheme.of(context).textSecondary),
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
          // Projects' violet, washed in from the corner.
          colors: [
            Color.alphaBlend(
              sectionColors(context, AppSection.projects).primaryFill.withValues(alpha: 0.20),
              AppTheme.of(context).surface,
            ),
            AppTheme.of(context).surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: sectionColors(context, AppSection.projects).primaryFill.withValues(alpha: 0.3)),
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
