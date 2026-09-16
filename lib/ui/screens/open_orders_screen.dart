import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/order_item.dart';
import '../../models/standalone_order.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/order_dialogs.dart';
import '../widgets/bamm_chip.dart';
import '../widgets/bamm_assign_dialog.dart';

/// Unified view of a purchase order that is either attached to a project or
/// standalone/unlinked.
class _OrderEntry {
  final Project? project;
  final OrderItem? order;
  final StandaloneOrder? standalone;
  const _OrderEntry({this.project, this.order, this.standalone});

  bool get isStandalone => standalone != null;
  String get description => order?.description ?? standalone?.description ?? '';
  String get pr => order?.pr ?? standalone?.pr ?? '';
  String get po => order?.po ?? standalone?.po ?? '';
  double get price => order?.price ?? standalone?.price ?? 0;
  DateTime? get eta => order?.eta ?? standalone?.eta;
  bool get delivered => order?.delivered ?? standalone?.delivered ?? false;
  bool get addToStores => order?.addToStores ?? standalone?.addToStores ?? false;
  bool get storeRequested => order?.storeRequested ?? standalone?.storeRequested ?? false;
  String get storeRequestNumber => order?.storeRequestNumber ?? standalone?.storeRequestNumber ?? '';
  String get vendorName => order?.vendorName ?? standalone?.vendorName ?? '';
  String get vendorQuoteNumber => order?.vendorQuoteNumber ?? standalone?.vendorQuoteNumber ?? '';
  String get trackingUrl => order?.trackingUrl ?? standalone?.trackingUrl ?? '';
  String get projectTitle => project?.title ?? 'Unlinked';
  String get machine => project?.machine ?? '';
  List<String> get bammWorkOrders => order?.bammWorkOrders ?? standalone?.bammWorkOrders ?? const [];
}


class OpenOrdersScreen extends ConsumerStatefulWidget {
  final String? targetOrderId;
  const OpenOrdersScreen({super.key, this.targetOrderId});

  @override
  ConsumerState<OpenOrdersScreen> createState() => _OpenOrdersScreenState();
}

class _OpenOrdersScreenState extends ConsumerState<OpenOrdersScreen> {
  int _filterTab = 0; // 0=Open,1=Delivered,2=All,3=Pending,4=Unlinked
  String _search = '';
  bool _handledTargetOrder = false;
  bool _denseView = true;

  @override
  void initState() {
    super.initState();
    if (widget.targetOrderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleTargetOrder();
      });
    }
  }

  @override
  void didUpdateWidget(covariant OpenOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetOrderId != null && widget.targetOrderId != oldWidget.targetOrderId) {
      _handledTargetOrder = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleTargetOrder();
      });
    }
  }

  void _handleTargetOrder() {
    if (!mounted || _handledTargetOrder || widget.targetOrderId == null) return;
    _handledTargetOrder = true;
    final state = ref.read(projectProvider);
    final standalone = state.standaloneOrders.where((o) => o.id == widget.targetOrderId).firstOrNull;
    if (standalone != null) {
      setState(() {
        _filterTab = 4; // Unlinked
      });
      _showEditStandaloneOrderDialog(context, standalone);
      return;
    }
    for (final p in state.projects) {
      final o = p.orders.where((ord) => ord.id == widget.targetOrderId).firstOrNull;
      if (o != null) {
        setState(() {
          _filterTab = 2; // All
        });
        _showEditOrderDialog(context, _OrderEntry(project: p, order: o));
        return;
      }
    }
  }

  void _showEditOrderDialog(BuildContext context, _OrderEntry entry) {
    final projectId = entry.project!.id;
    final order = entry.order!;
    final prCtrl = TextEditingController(text: order.pr);
    final poCtrl = TextEditingController(text: order.po);
    final descCtrl = TextEditingController(text: order.description);
    final quoteCtrl = TextEditingController(text: order.vendorQuoteNumber);
    final trackingCtrl = TextEditingController(text: order.trackingUrl);
    final priceCtrl =
        TextEditingController(text: order.price > 0 ? order.price.toStringAsFixed(2) : '');
    String? selectedVendorId = order.vendorId;
    String selectedVendorName = order.vendorName;
    DateTime? eta = order.eta;
    bool delivered = order.delivered;
    List<String> bammWorkOrders = List.from(order.bammWorkOrders);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final vendors = ref.read(projectProvider).vendors;
          final etaText = eta != null ? DateFormat('MMM d, y').format(eta!) : 'No ETA Date';
          return AlertDialog(
            title: const Text('Edit Purchase Order'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Part / Material Description *')),
                  const SizedBox(height: 12),
                  if (vendors.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: vendors.any((v) => v.id == selectedVendorId) ? selectedVendorId : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Vendor / Supplier',
                        prefixIcon: Icon(Icons.storefront_rounded, size: 18),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None / Unspecified')),
                        ...vendors.map((v) => DropdownMenuItem(
                              value: v.id,
                              child: Text(v.name),
                            )),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedVendorId = val;
                          final v = vendors.where((vend) => vend.id == val).firstOrNull;
                          selectedVendorName = v?.name ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(children: [
                    Expanded(child: TextField(controller: prCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PR (Requisition)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: poCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PO Number'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price / Cost (\$)', prefixText: '\$ '))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: quoteCtrl, decoration: const InputDecoration(labelText: 'Quote #'))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: trackingCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Tracking Link / URL',
                      prefixIcon: Icon(Icons.track_changes_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.calendar_today_rounded, color: AppTheme.of(context).primary),
                    title: Text(etaText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Estimated Delivery (ETA)', style: TextStyle(fontSize: 11)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (eta != null)
                        IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setDialogState(() => eta = null)),
                      ElevatedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(context: ctx, initialDate: eta ?? DateTime.now().add(const Duration(days: 3)), firstDate: DateTime(2020), lastDate: DateTime(2035));
                          if (picked != null) setDialogState(() => eta = picked);
                        },
                        child: const Text('Set ETA'),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.build_circle_rounded, size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 6),
                      Text(
                        'BAMM Work Orders',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final selected = await showDialog<List<String>>(
                            context: ctx,
                            builder: (c) => BammAssignDialog(
                              initialSelected: bammWorkOrders,
                              title: 'Assign BAMM to Order',
                            ),
                          );
                          if (selected != null) {
                            setDialogState(() {
                              bammWorkOrders = selected;
                            });
                          }
                        },
                        icon: const Icon(Icons.add_link_rounded, size: 16),
                        label: const Text('Assign BAMM'),
                      ),
                    ],
                  ),
                  if (bammWorkOrders.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: bammWorkOrders.map((wo) {
                          return BammChip(
                            workOrderNo: wo,
                            onDeleted: () {
                              setDialogState(() {
                                bammWorkOrders = bammWorkOrders.where((w) => w != wo).toList();
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Marked as Delivered', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Part has arrived at plant/crib', style: TextStyle(fontSize: 11)),
                    value: delivered,
                    activeColor: AppTheme.of(context).emerald,
                    onChanged: (val) { if (val != null) setDialogState(() => delivered = val); },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                    vendorId: selectedVendorId,
                    clearVendorId: selectedVendorId == null,
                    vendorName: selectedVendorName,
                    vendorQuoteNumber: quoteCtrl.text.trim(),
                    trackingUrl: trackingCtrl.text.trim(),
                    bammWorkOrders: bammWorkOrders,
                  );
                  await ref.read(projectProvider.notifier).updateOrder(projectId, updated);
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

    final linked = <_OrderEntry>[
      for (final project in state.projects)
        for (final order in project.orders) _OrderEntry(project: project, order: order),
    ];
    final standalone = [
      for (final o in state.standaloneOrders) _OrderEntry(standalone: o),
    ];
    final allEntries = [...linked, ...standalone];

    final openCount = allEntries.where((e) => !e.delivered).length;
    final deliveredCount = allEntries.where((e) => e.delivered).length;
    final pendingCount = allEntries.where((e) => e.pr.isEmpty && e.po.isEmpty).length;

    List<_OrderEntry> filtered = allEntries;
    if (_filterTab == 0) {
      filtered = allEntries.where((e) => !e.delivered).toList()
        ..sort((a, b) {
          if (a.eta == null && b.eta == null) return 0;
          if (a.eta == null) return 1;
          if (b.eta == null) return -1;
          return a.eta!.compareTo(b.eta!);
        });
    } else if (_filterTab == 1) {
      filtered = allEntries.where((e) => e.delivered).toList();
    } else if (_filterTab == 2) {
      filtered = allEntries;
    } else if (_filterTab == 3) {
      filtered = allEntries.where((e) => e.pr.isEmpty && e.po.isEmpty).toList();
    } else if (_filterTab == 4) {
      filtered = standalone;
    }

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((e) {
        return e.pr.toLowerCase().contains(q) ||
            e.po.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q) ||
            e.projectTitle.toLowerCase().contains(q) ||
            e.machine.toLowerCase().contains(q);
      }).toList();
    }

    final totalDisplayValue = filtered.fold(0.0, (prev, e) => prev + e.price);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final showDense = isDesktop && _denseView;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.local_shipping_outlined, color: AppTheme.of(context).primary),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Purchase Orders & Parts',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        actions: [
          if (isDesktop)
            IconButton(
              icon: Icon(
                _denseView ? Icons.view_agenda_outlined : Icons.table_rows_rounded,
                color: AppTheme.of(context).primary,
              ),
              tooltip: _denseView ? 'Switch to Cards View' : 'Switch to Compact Rows',
              onPressed: () => setState(() => _denseView = !_denseView),
            ),
          IconButton(
            icon: Icon(Icons.storefront_rounded, color: AppTheme.of(context).primary),
            tooltip: 'Vendor Directory',
            onPressed: () => context.push('/vendors'),
          ),
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: AppTheme.of(context).amber),
            tooltip: 'Order Workflow Guide',
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Row(children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.of(context).primary),
                  const SizedBox(width: 8),
                  const Text('PO vs PR & Delivery Info'),
                ]),
                content: const SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('📦 PR vs PO Tracking', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('• PR (Purchase Requisition): Internal plant requisition number prior to approval.\n• PO (Purchase Order): Official vendor purchasing order number.\n• Pending: orders that have neither a PO nor a PR yet.\n• Delivered: Check the box to mark parts as arrived at the plant crib/bench.', style: TextStyle(fontSize: 12)),
                    SizedBox(height: 10),
                    Text('⏳ ETA Countdown', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Orders with an assigned ETA date will show relative delivery status ("Arriving Today", "Overdue", or "In X days") sorted chronologically.', style: TextStyle(fontSize: 12)),
                  ]),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Toolbar: Desktop responsive row vs Mobile column
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 0, label: Text('Open ($openCount)', style: const TextStyle(fontSize: 12))),
                          ButtonSegment(value: 1, label: Text('Delivered ($deliveredCount)', style: const TextStyle(fontSize: 12))),
                          ButtonSegment(value: 2, label: Text('All (${allEntries.length})', style: const TextStyle(fontSize: 12))),
                          ButtonSegment(value: 3, label: Text('Pending ($pendingCount)', style: const TextStyle(fontSize: 12)), icon: const Icon(Icons.hourglass_empty_rounded, size: 14)),
                          ButtonSegment(value: 4, label: Text('Unlinked (${standalone.length})', style: const TextStyle(fontSize: 12)), icon: const Icon(Icons.link_off_rounded, size: 14)),
                        ],
                        selected: {_filterTab},
                        onSelectionChanged: (val) => setState(() => _filterTab = val.first),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search description, PO, PR, vendor, machine...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () => setState(() => _search = ''))
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (val) => setState(() => _search = val),
                    ),
                  ),
                  if (filtered.isNotEmpty && _filterTab <= 2) ...[
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.of(context).surfaceVariant : AppTheme.of(context).surfaceVariant,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: AppTheme.of(context).primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _filterTab == 0 ? 'OPEN PO: ' : _filterTab == 1 ? 'DELIVERED: ' : 'TOTAL PO: ',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                          Text(
                            currency.format(totalDisplayValue),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _filterTab == 0 ? AppTheme.of(context).primary : AppTheme.of(context).emerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    onPressed: () => _showAddStandaloneOrderDialog(context),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                    label: const Text('Unlinked Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.of(context).amber,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text('Open ($openCount)', style: const TextStyle(fontSize: 12))),
                      ButtonSegment(value: 1, label: Text('Delivered ($deliveredCount)', style: const TextStyle(fontSize: 12))),
                      ButtonSegment(value: 2, label: Text('All (${allEntries.length})', style: const TextStyle(fontSize: 12))),
                      ButtonSegment(value: 3, label: Text('Pending ($pendingCount)', style: const TextStyle(fontSize: 12)), icon: const Icon(Icons.hourglass_empty_rounded, size: 14)),
                      ButtonSegment(value: 4, label: Text('Unlinked (${standalone.length})', style: const TextStyle(fontSize: 12)), icon: const Icon(Icons.link_off_rounded, size: 14)),
                    ],
                    selected: {_filterTab},
                    onSelectionChanged: (val) => setState(() => _filterTab = val.first),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search orders, PO, PR, machine...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _search = ''))
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _search = val),
                ),
              ]),
            ),
            if (filtered.isNotEmpty && _filterTab <= 2)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.of(context).surfaceVariant : AppTheme.of(context).surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_filterTab == 0 ? 'TOTAL OPEN PO SPEND' : _filterTab == 1 ? 'TOTAL DELIVERED PO VALUE' : 'TOTAL PO VALUE',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  Text(currency.format(totalDisplayValue),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                          color: _filterTab == 0 ? AppTheme.of(context).primary : AppTheme.of(context).emerald)),
                ]),
              ),
          ],

          Expanded(
            child: filtered.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No Orders Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_filterTab == 4
                        ? 'Tap + Unlinked Order to add a purchase order not yet tied to a project.'
                        : 'No orders match this filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => showDense
                        ? _buildDesktopOrderRow(context, filtered[index], currency, dateFormat, isDark, notifier)
                        : _buildOrderCard(context, filtered[index], currency, dateFormat, isDark, notifier),
                  ),
          ),
        ],
      ),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddStandaloneOrderDialog(context),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Unlinked Order'),
              backgroundColor: AppTheme.of(context).amber,
              foregroundColor: Colors.black87,
            ),
    );
  }

  Widget _buildDesktopOrderRow(
    BuildContext context,
    _OrderEntry e,
    NumberFormat currency,
    DateFormat dateFormat,
    bool isDark,
    dynamic notifier,
  ) {
    final isStandalone = e.isStandalone;
    final isOverdue = !e.delivered && e.eta != null && e.eta!.isBefore(DateTime.now());

    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      isGlowing: isOverdue,
      glowColor: AppTheme.of(context).coral,
      onTap: () {
        if (isStandalone) {
          _showEditStandaloneOrderDialog(context, e.standalone!);
        } else {
          _showEditOrderDialog(context, e);
        }
      },
      child: Row(
        children: [
          // Checkbox: Delivery status
          Checkbox(
            value: e.delivered,
            activeColor: AppTheme.of(context).emerald,
            visualDensity: VisualDensity.compact,
            onChanged: (_) {
              if (isStandalone) {
                notifier.updateStandaloneOrder(e.standalone!.copyWith(delivered: !e.delivered));
              } else {
                notifier.toggleOrderDelivered(e.project!.id, e.order!.id);
              }
            },
          ),
          const SizedBox(width: 4),

          // Status & ETA Badge
          SizedBox(
            width: 110,
            child: e.delivered
                ? ExpressiveBadge(
                    label: '✓ Delivered',
                    color: AppTheme.of(context).emerald,
                    fontSize: 10,
                  )
                : (e.eta != null
                    ? _buildEtaBadge(e.eta!)
                    : Text(
                        'No ETA',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        ),
                      )),
          ),
          const SizedBox(width: 8),

          // Description & Track Button (Flexible)
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    e.description.isEmpty ? 'Parts / Material Order' : e.description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      decoration: e.delivered ? TextDecoration.lineThrough : null,
                      color: e.delivered ? Colors.grey : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (e.trackingUrl.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      var url = e.trackingUrl.trim();
                      if (!url.startsWith('http://') && !url.startsWith('https://')) {
                        url = 'https://$url';
                      }
                      final uri = Uri.tryParse(url);
                      if (uri != null) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.of(context).primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.of(context).primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.track_changes_rounded, size: 11, color: AppTheme.of(context).primary),
                          const SizedBox(width: 3),
                          Text('Track', style: TextStyle(fontSize: 10, color: AppTheme.of(context).primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // PO / PR badges
          SizedBox(
            width: 140,
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (e.po.isNotEmpty)
                  ExpressiveBadge(label: 'PO: ${e.po}', color: AppTheme.of(context).primary, fontSize: 10),
                if (e.pr.isNotEmpty)
                  ExpressiveBadge(label: 'PR: ${e.pr}', color: AppTheme.of(context).amber, fontSize: 10),
                ...e.bammWorkOrders.map((wo) => BammChip(worNo: wo, isDense: true)),
                if (e.po.isEmpty && e.pr.isEmpty && e.bammWorkOrders.isEmpty)
                  const Text('—', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Vendor badge
          SizedBox(
            width: 120,
            child: e.vendorName.isNotEmpty
                ? ExpressiveBadge(
                    label: e.vendorName,
                    color: Colors.purpleAccent,
                    icon: Icons.storefront_rounded,
                    fontSize: 10,
                  )
                : const Text('—', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          const SizedBox(width: 8),

          // Project / Machine Link
          SizedBox(
            width: 140,
            child: !isStandalone
                ? InkWell(
                    onTap: () => context.push('/projects/${e.project!.id}'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.precision_manufacturing_outlined, size: 13, color: AppTheme.of(context).primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            e.projectTitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.of(context).primary,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_off_rounded, size: 13, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Unlinked',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),

          // Stores Badge
          SizedBox(
            width: 90,
            child: e.addToStores
                ? (e.storeRequestNumber.isNotEmpty
                    ? ExpressiveBadge(label: 'Stores #${e.storeRequestNumber} ✓', color: AppTheme.of(context).emerald, fontSize: 9)
                    : e.storeRequested
                        ? ExpressiveBadge(label: 'Stores: Req', color: AppTheme.of(context).amber, fontSize: 9)
                        : ExpressiveBadge(label: 'Stores: Pend', color: AppTheme.of(context).amber, fontSize: 9))
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),

          // Price
          SizedBox(
            width: 85,
            child: Text(
              currency.format(e.price),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),

          // Actions: Edit / Attach
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 16, color: AppTheme.of(context).primary),
                tooltip: 'Edit Order',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  if (isStandalone) {
                    _showEditStandaloneOrderDialog(context, e.standalone!);
                  } else {
                    _showEditOrderDialog(context, e);
                  }
                },
              ),
              if (isStandalone)
                IconButton(
                  icon: Icon(Icons.link_rounded, size: 16, color: AppTheme.of(context).emerald),
                  tooltip: 'Attach to Project',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _showAttachToProjectDialog(context, e),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, _OrderEntry e, NumberFormat currency, DateFormat dateFormat, bool isDark, dynamic notifier) {
    final isStandalone = e.isStandalone;
    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 12),
      isGlowing: !e.delivered && e.eta != null && e.eta!.isBefore(DateTime.now()),
      glowColor: AppTheme.of(context).coral,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: project context (or Unlinked) + edit/delete
        Row(children: [
          if (!isStandalone)
            InkWell(
              onTap: () => context.push('/projects/${e.project!.id}'),
              child: Row(children: [
                Icon(Icons.precision_manufacturing_outlined, size: 14, color: AppTheme.of(context).primary),
                const SizedBox(width: 6),
                Text(e.projectTitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.of(context).primary, decoration: TextDecoration.underline)),
              ]),
            )
          else ...[
            const Icon(Icons.link_off_rounded, size: 14, color: Colors.orange),
            const SizedBox(width: 6),
            const Text('Unlinked', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
          ],
          if (e.machine.isNotEmpty) ...[
            const SizedBox(width: 8),
            ExpressiveBadge(label: e.machine, color: AppTheme.of(context).amber, fontSize: 10),
          ],
          const Spacer(),
          if (isStandalone)
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 16, color: AppTheme.of(context).primary),
              tooltip: 'Edit Order',
              onPressed: () => _showEditStandaloneOrderDialog(context, e.standalone!),
            )
          else
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 16, color: AppTheme.of(context).primary),
              tooltip: 'Edit Order',
              onPressed: () => _showEditOrderDialog(context, e),
            ),
        ]),
        const Divider(height: 12),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: e.delivered,
            activeColor: AppTheme.of(context).emerald,
            onChanged: (_) {
              if (isStandalone) {
                notifier.updateStandaloneOrder(e.standalone!.copyWith(delivered: !e.delivered));
              } else {
                notifier.toggleOrderDelivered(e.project!.id, e.order!.id);
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.description.isEmpty ? 'Parts / Material Order' : e.description,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    decoration: e.delivered ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (e.po.isNotEmpty) ExpressiveBadge(label: 'PO: ${e.po}', color: AppTheme.of(context).primary, fontSize: 10),
              if (e.pr.isNotEmpty) ExpressiveBadge(label: 'PR: ${e.pr}', color: AppTheme.of(context).amber, fontSize: 10),
              ...e.bammWorkOrders.map((wo) => BammChip(worNo: wo, isDense: true)),
              if (e.vendorName.isNotEmpty)
                ExpressiveBadge(label: e.vendorName, color: Colors.purpleAccent, icon: Icons.storefront_rounded, fontSize: 10),
              if (e.vendorQuoteNumber.isNotEmpty)
                ExpressiveBadge(label: 'Quote #${e.vendorQuoteNumber}', color: Colors.blueGrey, fontSize: 10),
              if (e.addToStores)
                e.storeRequestNumber.isNotEmpty
                    ? ExpressiveBadge(label: 'Stores #${e.storeRequestNumber} ✓', color: AppTheme.of(context).emerald, fontSize: 10)
                    : e.storeRequested
                        ? ExpressiveBadge(label: 'Stores: Requested', color: AppTheme.of(context).amber, fontSize: 10)
                        : e.po.isNotEmpty
                            ? ExpressiveBadge(label: 'Stores: Pending', color: AppTheme.of(context).amber, fontSize: 10)
                            : const ExpressiveBadge(label: 'Add to Stores', color: Colors.grey, fontSize: 10),
            ]),
            if (e.trackingUrl.isNotEmpty) ...[
              const SizedBox(height: 4),
              ActionChip(
                avatar: Icon(Icons.track_changes_rounded, size: 12, color: AppTheme.of(context).primary),
                label: Text('Track Shipment', style: TextStyle(fontSize: 10, color: AppTheme.of(context).primary)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  var url = e.trackingUrl.trim();
                  if (!url.startsWith('http://') && !url.startsWith('https://')) {
                    url = 'https://$url';
                  }
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],

          ])),
          Text(currency.format(e.price), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ]),

        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          if (e.eta != null) _buildEtaBadge(e.eta!)
          else Text('No ETA specified', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary)),
          if (e.delivered) ExpressiveBadge(label: '✓ Delivered', color: AppTheme.of(context).emerald, fontSize: 10),
        ]),

        // Stores workflow
        _buildStoresSection(e, notifier),

        // Attach to project (standalone only)
        if (isStandalone) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showAttachToProjectDialog(context, e),
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('Attach to Project', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.of(context).emerald,
              side: BorderSide(color: AppTheme.of(context).emerald),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildStoresSection(_OrderEntry e, dynamic notifier) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 16),
      Row(children: [
        Icon(Icons.warehouse_outlined, size: 16, color: e.addToStores ? AppTheme.of(context).emerald : Colors.grey),
        const SizedBox(width: 8),
        const Expanded(child: Text('Add to Stores', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        Switch(
          value: e.addToStores,
          activeColor: AppTheme.of(context).emerald,
          onChanged: (v) {
            if (e.isStandalone) {
              notifier.setStandaloneOrderAddToStores(e.standalone!.id, v);
            } else {
              notifier.setOrderAddToStores(e.project!.id, e.order!.id, v);
            }
          },
        ),
      ]),
      if (e.addToStores) ...[
        const SizedBox(height: 6),
        if (e.po.isEmpty)
          Padding(padding: const EdgeInsets.only(left: 2), child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.of(context).amber),
            const SizedBox(width: 6),
            Expanded(child: Text('Add a PO number, then request from storeroom.',
                style: TextStyle(fontSize: 11, color: AppTheme.of(context).amber, fontStyle: FontStyle.italic))),
          ]))
        else if (!e.storeRequested)
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Request for Stores?'),
                content: Text('Send "${e.description}" to the storeroom?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request')),
                ],
              ));
              if (confirm == true) {
                if (e.isStandalone) {
                  notifier.markStandaloneOrderStoreRequested(e.standalone!.id);
                } else {
                  notifier.markOrderStoreRequested(e.project!.id, e.order!.id);
                }
              }
            },
            icon: const Icon(Icons.warehouse_rounded, size: 16),
            label: const Text('Request for Stores'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.of(context).emerald, side: BorderSide(color: AppTheme.of(context).emerald)),
          ))
        else if (e.storeRequestNumber.isEmpty)
          Row(children: [
            const Expanded(child: Text('Requested — add store request #', style: TextStyle(fontSize: 11))),
            OutlinedButton.icon(
              onPressed: () => _showStoreNumberDialog(e),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Add #'),
            ),
          ])
        else
          ExpressiveBadge(label: 'Stores #${e.storeRequestNumber} ✓ Requested', icon: Icons.warehouse_rounded, color: AppTheme.of(context).emerald, fontSize: 10),
      ],
    ]);
  }

  Future<void> _showStoreNumberDialog(_OrderEntry e) async {
    final ctrl = TextEditingController(text: e.storeRequestNumber);
    final num = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Store Request Number'),
      content: TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Store request #')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
      ],
    ));
    if (num == null || num.isEmpty) return;
    if (e.isStandalone) {
      await ref.read(projectProvider.notifier).setStandaloneOrderStoreRequestNumber(e.standalone!.id, num);
    } else {
      await ref.read(projectProvider.notifier).setOrderStoreRequestNumber(e.project!.id, e.order!.id, num);
    }
  }

  void _showAddStandaloneOrderDialog(BuildContext context) {
    showStandaloneOrderDialog(context, ref, onAdded: () {
      if (mounted) setState(() => _filterTab = 4);
    });
  }

  void _showEditStandaloneOrderDialog(BuildContext context, StandaloneOrder o) {
    final descCtrl = TextEditingController(text: o.description);
    final prCtrl = TextEditingController(text: o.pr);
    final poCtrl = TextEditingController(text: o.po);
    final priceCtrl = TextEditingController(text: o.price > 0 ? o.price.toStringAsFixed(2) : '');
    final notesCtrl = TextEditingController(text: o.notes);
    DateTime? eta = o.eta;
    List<String> bammWorkOrders = List.from(o.bammWorkOrders);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Edit Unlinked Order'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
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
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.build_circle_rounded, size: 16, color: AppTheme.primaryBlue),
                const SizedBox(width: 6),
                Text(
                  'BAMM Work Orders',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final selected = await showDialog<List<String>>(
                      context: ctx,
                      builder: (c) => BammAssignDialog(
                        initialSelected: bammWorkOrders,
                        title: 'Assign BAMM to Order',
                      ),
                    );
                    if (selected != null) {
                      setDialogState(() {
                        bammWorkOrders = selected;
                      });
                    }
                  },
                  icon: const Icon(Icons.add_link_rounded, size: 16),
                  label: const Text('Assign BAMM'),
                ),
              ],
            ),
            if (bammWorkOrders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: bammWorkOrders.map((wo) {
                    return BammChip(
                      workOrderNo: wo,
                      onDeleted: () {
                        setDialogState(() {
                          bammWorkOrders = bammWorkOrders.where((w) => w != wo).toList();
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ref.read(projectProvider.notifier).updateStandaloneOrder(o.copyWith(
                  description: descCtrl.text.trim(), pr: prCtrl.text.trim(), po: poCtrl.text.trim(),
                  price: double.tryParse(priceCtrl.text) ?? 0.0, eta: eta, clearEta: eta == null, notes: notesCtrl.text.trim(),
                  bammWorkOrders: bammWorkOrders,
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

  /// Type-ahead attach dialog: matches projects as you type and shows a card list.
  void _showAttachToProjectDialog(BuildContext context, _OrderEntry e) {
    final projects = ref.read(projectProvider).activeProjects;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active projects to attach to.')));
      return;
    }
    final searchCtrl = TextEditingController();
    String? selectedId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        final q = searchCtrl.text.trim().toLowerCase();
        final matches = q.isEmpty
            ? projects
            : projects.where((p) =>
                p.title.toLowerCase().contains(q) ||
                p.machine.toLowerCase().contains(q) ||
                p.tags.any((t) => t.toLowerCase().contains(q))).toList();
        return AlertDialog(
          title: const Text('Attach to Project'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Move "${e.description.isEmpty ? '(order)' : e.description}" to a project:',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: searchCtrl,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(labelText: 'Search project', hintText: 'Type to filter...', prefixIcon: Icon(Icons.search_rounded), isDense: true),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: matches.isEmpty
                    ? const Padding(padding: EdgeInsets.all(12), child: Text('No matching projects', style: TextStyle(fontSize: 12, color: Colors.grey)))
                    : ListView(
                        shrinkWrap: true,
                        children: matches.map((p) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          color: selectedId == p.id ? AppTheme.of(context).emerald.withValues(alpha: 0.15) : null,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.engineering_rounded, size: 20, color: AppTheme.of(context).primary),
                            title: Text('#${p.priority} ${p.title}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            subtitle: p.machine.isNotEmpty ? Text(p.machine, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis) : null,
                            onTap: () => setDialogState(() => selectedId = p.id),
                          ),
                        )).toList(),
                      ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      await ref.read(projectProvider.notifier).linkOrderToProject(e.standalone!.id, selectedId!);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Order linked to project!'), backgroundColor: AppTheme.of(context).emerald));
                        setState(() => _filterTab = 0);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.of(context).emerald, foregroundColor: Colors.white),
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
      col = AppTheme.of(context).coral;
    } else if (days == 0) {
      label = '🚚 Arriving Today';
      col = AppTheme.of(context).emerald;
    } else if (days == 1) {
      label = '📦 Arriving Tomorrow';
      col = AppTheme.of(context).primary;
    } else {
      label = 'ETA in $days days (${DateFormat("MMM d").format(eta)})';
      col = AppTheme.of(context).primary;
    }
    return ExpressiveBadge(label: label, color: col, fontSize: 11);
  }
}
