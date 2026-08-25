import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';

class OpenOrdersScreen extends ConsumerWidget {
  const OpenOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, y');

    final openOrders = state.openOrders;
    final totalOpenValue = openOrders.fold(
      0.0,
      (prev, entry) => prev + entry.order.price,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_shipping_outlined, color: AppTheme.primaryCyan),
            SizedBox(width: 8),
            Text(
              'Open Purchase Orders',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.grey),
            tooltip: 'Orders & Requisition Guide',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, color: AppTheme.primaryCyan),
                      SizedBox(width: 8),
                      Text('Orders Guide'),
                    ],
                  ),
                  content: const SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('📦 PR vs PO Tracking', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCyan)),
                        SizedBox(height: 4),
                        Text('• PR (Purchase Requisition): Internal plant requisition number prior to approval.\n• PO (Purchase Order): Official vendor purchasing order number.\n• Delivered: Check the box to mark parts as arrived at the plant crib/bench.', style: TextStyle(fontSize: 12)),
                        SizedBox(height: 10),
                        Text('⏳ ETA Countdown', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentAmber)),
                        SizedBox(height: 4),
                        Text('Orders with an assigned ETA date will show relative delivery status ("Arriving Today", "Overdue", or "In X days") sorted chronologically.', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: openOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.done_all_rounded,
                      size: 56,
                      color: AppTheme.accentEmerald,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All Purchase Orders Delivered!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No open parts requisitions or pending shipments.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Summary Metric Card
                ExpressiveCard(
                  isGlowing: true,
                  glowColor: AppTheme.primaryCyan,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL OPEN ORDERS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppTheme.primaryCyan,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currency.format(totalOpenValue),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Pending Delivery',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          ExpressiveBadge(
                            label: '${openOrders.length} Open Shipments',
                            color: AppTheme.accentAmber,
                            fontSize: 12,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Orders Stream
                ...openOrders.map((entry) {
                  final project = entry.project;
                  final order = entry.order;

                  String etaText = 'ETA: Unscheduled';
                  Color etaColor = Colors.grey;
                  if (order.eta != null) {
                    final daysUntil = order.eta!.difference(DateTime.now()).inDays;
                    if (daysUntil < 0) {
                      etaText = 'Overdue (${dateFormat.format(order.eta!)})';
                      etaColor = AppTheme.accentCoral;
                    } else if (daysUntil == 0) {
                      etaText = 'Arriving Today!';
                      etaColor = AppTheme.accentAmber;
                    } else {
                      etaText = 'ETA: in $daysUntil days (${dateFormat.format(order.eta!)})';
                      etaColor = AppTheme.primaryCyan;
                    }
                  }

                  return ExpressiveCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PR / PO & Price Header
                        Row(
                          children: [
                            if (order.po.isNotEmpty)
                              ExpressiveBadge(
                                label: 'PO: ${order.po}',
                                color: AppTheme.primaryCyan,
                                fontSize: 11,
                              ),
                            if (order.pr.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              ExpressiveBadge(
                                label: 'PR: ${order.pr}',
                                color: AppTheme.primaryBlue,
                                isOutlined: true,
                                fontSize: 11,
                              ),
                            ],
                            const Spacer(),
                            Text(
                              currency.format(order.price),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Order Description
                        Text(
                          order.description.isEmpty
                              ? 'Unspecified Order Item'
                              : order.description,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ETA & Project Links Row
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 14, color: etaColor),
                            const SizedBox(width: 4),
                            Text(
                              etaText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: etaColor,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Bottom Project Link & Mark Delivered Button
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => context.push('/projects/${project.id}'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project.title,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryCyan,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (project.machine.isNotEmpty)
                                      Text(
                                        'Machine: ${project.machine}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentEmerald,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () {
                                notifier.toggleOrderDelivered(project.id, order.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Marked "${order.description}" as Delivered!'),
                                    backgroundColor: AppTheme.accentEmerald,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Delivered', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
