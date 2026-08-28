import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/order_item.dart';
import '../../models/standalone_order.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';

class OpenOrdersScreen extends ConsumerStatefulWidget {
  const OpenOrdersScreen({super.key});

  @override
  ConsumerState<OpenOrdersScreen> createState() => _OpenOrdersScreenState();
}

class _OpenOrdersScreenState extends ConsumerState<OpenOrdersScreen> {
  int _filterTab = 0; // 0=Open, 1=Delivered, 2=All, 3=Unlinked
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
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'PR (Requisition)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: poCtrl,
                          keyboardType: TextInputType.number,
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
    final dateFormat = DateFormat('MMM d, y');

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
                          ButtonSegment(
                            value: 3,
                            label: Text('Unlinked (${state.standaloneOrders.length})', style: const TextStyle(fontSize: 12)),
                            icon: const Icon(Icons.link_off_rounded, size: 14),
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

          // Spend Summary Banner (not for Unlinked tab)
          if (filtered.isNotEmpty && _filterTab != 3)
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
            child: _filterTab == 3
                ? _buildUnlinkedOrdersList(context, state, isDark, currency, dateFormat)
                : (filtered.isEmpty
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
                  )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStandaloneOrderDialog(context),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Unlinked Order'),
        backgroundColor: AppTheme.accentAmber,
        foregroundColor: Colors.black87,
      ),
    );
  }

  Widget _buildUnlinkedOrdersList(BuildContext context, EngineeringState state, bool isDark, NumberFormat currency, DateFormat dateFormat) {
    final orders = state.standaloneOrders;
    final projects = state.activeProjects;

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No Unlinked Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Tap + Unlinked Order to add a purchase order\nnot yet tied to a project.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final o = orders[index];
        return ExpressiveCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link_off_rounded, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      o.description.isEmpty ? '(No description)' : o.description,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'edit') {
                        _showEditStandaloneOrderDialog(context, o);
                      } else if (val == 'attach') {
                        _showAttachToProjectDialog(context, o, projects);
                      } else if (val == 'delete') {
                        await ref.read(projectProvider.notifier).deleteStandaloneOrder(o.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                      const PopupMenuItem(value: 'attach', child: ListTile(leading: Icon(Icons.link_rounded, color: AppTheme.accentEmerald), title: Text('Attach to Project'))),
                      const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete'))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                if (o.pr.isNotEmpty) ExpressiveBadge(label: 'PR: ${o.pr}', color: AppTheme.primaryCyan, fontSize: 10),
                if (o.po.isNotEmpty) ExpressiveBadge(label: 'PO: ${o.po}', color: AppTheme.accentEmerald, fontSize: 10),
                if (o.price > 0) ExpressiveBadge(label: currency.format(o.price), color: AppTheme.accentAmber, fontSize: 10),
                if (o.eta != null) ExpressiveBadge(label: 'ETA: ${dateFormat.format(o.eta!)}', color: AppTheme.accentCoral, fontSize: 10),
                if (o.delivered) const ExpressiveBadge(label: '✓ Delivered', color: AppTheme.accentEmerald, fontSize: 10),
              ]),
              if (o.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(o.notes, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showAttachToProjectDialog(context, o, projects),
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('Attach to Project', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentEmerald,
                  side: const BorderSide(color: AppTheme.accentEmerald),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddStandaloneOrderDialog(BuildContext context) {
    final descCtrl = TextEditingController();
    final prCtrl = TextEditingController();
    final poCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime? eta;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Add Unlinked Order'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description *')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: prCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PR #'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: poCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PO #'))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (\$)', prefixText: '\$ ')),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(eta != null ? 'ETA: ${DateFormat('MMM d, y').format(eta!)}' : 'No ETA', style: const TextStyle(fontSize: 13)),
                trailing: ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 3)), firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (picked != null) setDialogState(() => eta = picked);
                  },
                  child: const Text('Pick ETA'),
                ),
              ),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final desc = descCtrl.text.trim();
                if (desc.isEmpty) return;
                ref.read(projectProvider.notifier).addStandaloneOrder(StandaloneOrder(
                  description: desc,
                  pr: prCtrl.text.trim(),
                  po: poCtrl.text.trim(),
                  price: double.tryParse(priceCtrl.text) ?? 0.0,
                  eta: eta,
                  notes: notesCtrl.text.trim(),
                ));
                Navigator.pop(ctx);
                setState(() => _filterTab = 3);
              },
              child: const Text('Add'),
            ),
          ],
        );
      }),
    );
  }

  void _showEditStandaloneOrderDialog(BuildContext context, StandaloneOrder o) {
    final descCtrl = TextEditingController(text: o.description);
    final prCtrl = TextEditingController(text: o.pr);
    final poCtrl = TextEditingController(text: o.po);
    final priceCtrl = TextEditingController(text: o.price > 0 ? o.price.toStringAsFixed(2) : '');
    final notesCtrl = TextEditingController(text: o.notes);
    DateTime? eta = o.eta;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Edit Unlinked Order'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description *')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: prCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PR #'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: poCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PO #'))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (\$)', prefixText: '\$ ')),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(eta != null ? 'ETA: ${DateFormat('MMM d, y').format(eta!)}' : 'No ETA', style: const TextStyle(fontSize: 13)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (eta != null) IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setDialogState(() => eta = null)),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(context: ctx, initialDate: eta ?? DateTime.now().add(const Duration(days: 3)), firstDate: DateTime(2020), lastDate: DateTime(2035));
                      if (picked != null) setDialogState(() => eta = picked);
                    },
                    child: const Text('Pick ETA'),
                  ),
                ]),
              ),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ref.read(projectProvider.notifier).updateStandaloneOrder(o.copyWith(
                  description: descCtrl.text.trim(),
                  pr: prCtrl.text.trim(),
                  po: poCtrl.text.trim(),
                  price: double.tryParse(priceCtrl.text) ?? 0.0,
                  eta: eta,
                  clearEta: eta == null,
                  notes: notesCtrl.text.trim(),
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  void _showAttachToProjectDialog(BuildContext context, StandaloneOrder o, List<Project> projects) {
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active projects to attach to.')));
      return;
    }
    String? selectedProjectId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Attach to Project'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Move "${o.description.isEmpty ? "(order)" : o.description}" to a project\'s Orders tab:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedProjectId,
              hint: const Text('Select project'),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.engineering_rounded)),
              items: projects.map((p) => DropdownMenuItem(value: p.id, child: Text('#${p.priority} ${p.title}', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) => setDialogState(() => selectedProjectId = val),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedProjectId == null ? null : () async {
                await ref.read(projectProvider.notifier).linkOrderToProject(o.id, selectedProjectId!);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order linked to project!'), backgroundColor: AppTheme.accentEmerald));
                  setState(() => _filterTab = 0);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald, foregroundColor: Colors.white),
              child: const Text('Attach'),
            ),
          ],
        );
      }),
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
