part of '../dashboard_screen.dart';

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader(this.title, {this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
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
                color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
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
        ? AppTheme.of(context).coral
        : (p.priority <= 3 ? AppTheme.of(context).amber : AppTheme.of(context).primary);
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
                        color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
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
        : (days >= 3 ? AppTheme.of(context).amber : Colors.grey);

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
      col = AppTheme.of(context).coral;
    } else if (days == 0) {
      label = 'Arriving Today';
      col = AppTheme.of(context).emerald;
    } else if (days == 1) {
      label = 'Arriving Tomorrow';
      col = AppTheme.of(context).primary;
    } else {
      label = 'in $days days';
      col = AppTheme.of(context).primary;
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
