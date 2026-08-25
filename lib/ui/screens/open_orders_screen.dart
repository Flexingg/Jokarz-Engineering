import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/order_item.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';

class OpenOrdersScreen extends ConsumerStatefulWidget {
  const OpenOrdersScreen({super.key});

  @override
  ConsumerState<OpenOrdersScreen> createState() => _OpenOrdersScreenState();
}

class _OpenOrdersScreenState extends ConsumerState<OpenOrdersScreen> {
  int _filterTab = 0; // 0 = Open, 1 = Delivered / Past, 2 = All
  String _search = '';

  void _showEditOrderDialog(
    BuildContext context, {
    required String projectId,
    required OrderItem order,
  }) {
    final prCtrl = TextEditingController(text: order.pr);
    final poCtrl = TextEditingController(text: order.po);
    final descCtrl = TextEditingController(text: order.description);
    final priceCtrl = TextEditingController(
      text: order.price > 0 ? order.price.toStringAsFixed(2) : '',
    );
    DateTime? eta = order.eta;
    bool delivered = order.delivered;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final etaText =
              eta != null ? DateFormat('MMM d, y').format(eta!) : 'No ETA Date';

          return AlertDialog(
            title: const Text('Edit Purchase Order'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Part / Material Description *',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: prCtrl,
                          decoration: const InputDecoration(
                            labelText: 'PR (Requisition)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: poCtrl,
                          decoration: const InputDecoration(
                            labelText: 'PO Number',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price / Cost (\$)',
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded,
                        color: AppTheme.primaryCyan),
                    title: Text(
                      etaText,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Estimated Delivery (ETA)',
                        style: TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (eta != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setDialogState(() => eta = null),
                          ),
                        ElevatedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate:
                                  eta ?? DateTime.now().add(const Duration(days: 3)),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDialogState(() => eta = picked);
                            }
                          },
                          child: const Text('Set ETA'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Marked as Delivered',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Part has arrived at plant/crib',
                        style: TextStyle(fontSize: 11)),
                    value: delivered,
                    activeColor: AppTheme.accentEmerald,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => delivered = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                  final updated = order.copyWith(
                    pr: prCtrl.text.trim(),
                    po: poCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    price: price,
                    eta: eta,
                    clearEta: eta == null,
                    delivered: delivered,
                  );
                  await ref
                      .read(projectProvider.notifier)
                      .updateOrder(projectId, updated);
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Update Order'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    // Collect all orders paired with their project
    final allOrderEntries = <({Project project, OrderItem order})>[];
    for (final project in state.projects) {
      for (final order in project.orders) {
        allOrderEntries.add((project: project, order: order));
      }
    }

    final openCount =
        allOrderEntries.where((e) => !e.order.delivered).length;
    final deliveredCount =
        allOrderEntries.where((e) => e.order.delivered).length;

    // Filter by tab
    List<({Project project, OrderItem order})> filtered = [];
    if (_filterTab == 0) {
      filtered = allOrderEntries.where((e) => !e.order.delivered).toList();
      // Sort open orders by ETA
      filtered.sort((a, b) {
        if (a.order.eta == null && b.order.eta == null) return 0;
        if (a.order.eta == null) return 1;
        if (b.order.eta == null) return -1;
        return a.order.eta!.compareTo(b.order.eta!);
      });
    } else if (_filterTab == 1) {
      filtered = allOrderEntries.where((e) => e.order.delivered).toList();
    } else {
      filtered = allOrderEntries;
    }

    // Filter by search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((e) {
        final matchesPr = e.order.pr.toLowerCase().contains(q);
        final matchesPo = e.order.po.toLowerCase().contains(q);
        final matchesDesc = e.order.description.toLowerCase().contains(q);
        final matchesProj = e.project.title.toLowerCase().contains(q);
        final matchesMachine = e.project.machine.toLowerCase().contains(q);
        return matchesPr || matchesPo || matchesDesc || matchesProj || matchesMachine;
      }).toList();
    }

    final totalDisplayValue = filtered.fold(
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
              'Purchase Orders & Parts',
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
      body: Column(
        children: [
          // Filter Tabs & Search Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Segmented Tabs
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<int>(
                        segments: [
                          ButtonSegment(
                            value: 0,
                            label: Text('Open ($openCount)', style: const TextStyle(fontSize: 12)),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text('Delivered ($deliveredCount)', style: const TextStyle(fontSize: 12)),
                          ),
                          ButtonSegment(
                            value: 2,
                            label: Text('All (${allOrderEntries.length})', style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                        selected: {_filterTab},
                        onSelectionChanged: (val) =>
                            setState(() => _filterTab = val.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search PR, PO, vendor, description, machine...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _search = val),
                ),
              ],
            ),
          ),

          // Spend Summary Banner
          if (filtered.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceVariant
                    : AppTheme.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _filterTab == 0
                        ? 'TOTAL OPEN PO SPEND'
                        : _filterTab == 1
                            ? 'TOTAL DELIVERED PO VALUE'
                            : 'TOTAL PO VALUE',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    currency.format(totalDisplayValue),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _filterTab == 0
                          ? AppTheme.primaryCyan
                          : AppTheme.accentEmerald,
                    ),
                  ),
                ],
              ),
            ),

          // Orders List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _filterTab == 0
                              ? Icons.done_all_rounded
                              : Icons.inbox_outlined,
                          size: 48,
                          color: _filterTab == 0
                              ? AppTheme.accentEmerald
                              : Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _filterTab == 0
                              ? 'No Open Orders Pending'
                              : _filterTab == 1
                                  ? 'No Delivered Orders'
                                  : 'No Orders Found',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add purchase orders inside any project under the Orders tab.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final project = entry.project;
                      final order = entry.order;

                      return ExpressiveCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        isGlowing: !order.delivered &&
                            order.eta != null &&
                            order.eta!.isBefore(DateTime.now()),
                        glowColor: AppTheme.accentCoral,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Project context & Edit Button
                            Row(
                              children: [
                                InkWell(
                                  onTap: () =>
                                      context.push('/projects/${project.id}'),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.precision_manufacturing_outlined,
                                        size: 14,
                                        color: AppTheme.primaryCyan,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        project.title,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryCyan,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (project.machine.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  ExpressiveBadge(
                                    label: project.machine,
                                    color: AppTheme.accentAmber,
                                    fontSize: 10,
                                  ),
                                ],
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 16, color: AppTheme.primaryCyan),
                                  tooltip: 'Edit Order',
                                  onPressed: () => _showEditOrderDialog(
                                    context,
                                    projectId: project.id,
                                    order: order,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 12),

                            // Order Description & Price
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Checkbox for delivery toggle
                                Checkbox(
                                  value: order.delivered,
                                  activeColor: AppTheme.accentEmerald,
                                  onChanged: (_) {
                                    notifier.toggleOrderDelivered(
                                        project.id, order.id);
                                  },
                                ),
                                const SizedBox(width: 4),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.description.isNotEmpty
                                            ? order.description
                                            : 'Parts / Material Order',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          decoration: order.delivered
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (order.po.isNotEmpty)
                                            ExpressiveBadge(
                                              label: 'PO: ${order.po}',
                                              color: AppTheme.primaryCyan,
                                              fontSize: 10,
                                            ),
                                          if (order.pr.isNotEmpty)
                                            ExpressiveBadge(
                                              label: 'PR: ${order.pr}',
                                              color: AppTheme.accentAmber,
                                              fontSize: 10,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Price Pill
                                Text(
                                  currency.format(order.price),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Bottom Row: ETA countdown & Delivery Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (order.eta != null)
                                  _buildEtaBadge(order.eta!)
                                else
                                  Text(
                                    'No ETA specified',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.lightTextSecondary,
                                    ),
                                  ),
                                if (order.delivered)
                                  const ExpressiveBadge(
                                    label: '✓ Delivered',
                                    color: AppTheme.accentEmerald,
                                    fontSize: 10,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtaBadge(DateTime eta) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final etaDate = DateTime(eta.year, eta.month, eta.day);
    final days = etaDate.difference(today).inDays;

    String label;
    Color col;

    if (days < 0) {
      label = '⚠️ Overdue (${days.abs()}d ago)';
      col = AppTheme.accentCoral;
    } else if (days == 0) {
      label = '🚚 Arriving Today';
      col = AppTheme.accentEmerald;
    } else if (days == 1) {
      label = '📦 Arriving Tomorrow';
      col = AppTheme.primaryCyan;
    } else {
      label = 'ETA in $days days (${DateFormat("MMM d").format(eta)})';
      col = AppTheme.primaryCyan;
    }

    return ExpressiveBadge(
      label: label,
      color: col,
      fontSize: 11,
    );
  }
}
