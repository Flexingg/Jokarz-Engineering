import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../motion/motion.dart';

part 'open_orders_parts/dialogs.dart';
part 'open_orders_parts/rows.dart';
part 'open_orders_parts/table.dart';

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
  /// Stable id across project-attached and standalone orders.
  String get key => order?.id ?? standalone?.id ?? '';
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
  /// `setState` is protected, so the part-file extensions rebuild through this.
  void _rebuild(VoidCallback fn) => setState(fn);

  int _filterTab = 0; // 0=Open,1=Delivered,2=All,3=Pending,4=Unlinked
  String _search = '';
  bool _handledTargetOrder = false;
  bool _denseView = true;

  /// Desktop table state: view mode, sort, multi-select and the details drawer.
  bool _tableView = true;
  String? _sortKey;
  bool _sortAsc = true;
  final Set<String> _selected = {};
  String? _activeKey;
  _OrderEntry? _lastActive;

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6)),
                ),
                segments: const [
                  ButtonSegment(value: 0, icon: Icon(Icons.table_chart_outlined, size: 18), tooltip: 'Table'),
                  ButtonSegment(value: 1, icon: Icon(Icons.table_rows_rounded, size: 18), tooltip: 'Compact rows'),
                  ButtonSegment(value: 2, icon: Icon(Icons.view_agenda_outlined, size: 18), tooltip: 'Cards'),
                ],
                selected: {_tableView ? 0 : (_denseView ? 1 : 2)},
                onSelectionChanged: (v) => setState(() {
                  final m = v.first;
                  _tableView = m == 0;
                  _denseView = m == 1;
                }),
              ),
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
                    label: const Text('Add Order'),
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
                        ? 'Tap + Add Order to add a purchase order not yet tied to a project.'
                        : 'No orders match this filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary)),
                  ]))
                : (isDesktop && _tableView)
                    ? _buildOrdersTable(allEntries, filtered, currency, dateFormat, notifier)
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
              label: const Text('Add Order'),
              backgroundColor: AppTheme.of(context).amber,
              foregroundColor: Colors.black87,
            ),
    );
  }

}
