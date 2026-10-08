import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/bamm_models.dart';
import '../../providers/bamm_provider.dart';
import '../../providers/project_provider.dart';
import '../../services/bamm_local_search.dart';
import '../../services/bamm_report_integrity.dart';
import '../../theme/app_theme.dart';
import '../panels/resizable_panel.dart';
import '../widgets/bamm_detail_dialog.dart';
import '../widgets/bamm_table_columns.dart';

part 'bamm_screen_parts/dialogs.dart';
part 'bamm_screen_parts/filters.dart';
part 'bamm_screen_parts/table.dart';

class BammScreen extends ConsumerStatefulWidget {
  final String? targetWo;
  final String? initialFilter;
  /// Sheet-integrity hash embedded in a scanned report QR
  /// (`aor-report://wo?id=...&h=...`) - compared against the live work
  /// order once fetched. Null for any other way this screen is opened.
  final String? snapshotHash;
  /// Epoch-ms print timestamp embedded alongside [snapshotHash], for a
  /// friendlier staleness message ("printed Sep 17" rather than just "this
  /// sheet is stale").
  final String? printedAtEpochMs;

  const BammScreen({
    super.key,
    this.targetWo,
    this.initialFilter,
    this.snapshotHash,
    this.printedAtEpochMs,
  });

  @override
  ConsumerState<BammScreen> createState() => _BammScreenState();
}

class _BammScreenState extends ConsumerState<BammScreen> {
  /// `setState` is protected, so the part-file extensions rebuild through this.
  void _rebuild(VoidCallback fn) => setState(fn);

  final TextEditingController _searchCtrl = TextEditingController();
  bool _denseView = true;
  bool _hasHandledInitialWo = false;

  /// Local "search everything already loaded" mode (item 4): OFF by default,
  /// never persisted, filters the rows already fetched with no new API call
  /// - see `bamm_local_search.dart`. Independent of the server-side search
  /// (`setSearchQuery`), which this toggle leaves untouched.
  bool _localSearchOn = false;
  String _localSearchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.targetWo != null && widget.targetWo!.isNotEmpty) {
      _searchCtrl.text = widget.targetWo!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(bammProvider.notifier).setSearchQuery(widget.targetWo!);
        _autoOpenTargetWo();
      });
    }
  }

  Future<void> _autoOpenTargetWo() async {
    if (_hasHandledInitialWo) return;
    _hasHandledInitialWo = true;
    final bammState = ref.read(bammProvider);
    final match = bammState.workOrders.where((w) =>
        w.worNoSeq.toLowerCase() == widget.targetWo!.toLowerCase().trim() ||
        w.worId.toString() == widget.targetWo!.trim()).firstOrNull;

    if (match != null) {
      if (mounted) _openWithStaleCheck(match);
      return;
    }

    // Cold-start gap: the target work order isn't in whatever's currently
    // loaded (e.g. the app booted with its default Emergency-step filter
    // and a scanned sheet points at a non-Emergency WO) - fetch it directly
    // by id rather than silently doing nothing. Only works when the target
    // is a numeric worId (the deep link always encodes that; a bare
    // worNoSeq typed into a URL has no live single-WO lookup by that key).
    final worId = int.tryParse(widget.targetWo!.trim());
    if (worId == null) return;
    final detail = await ref.read(bammProvider.notifier).fetchWorkOrderDetail(worId);
    if (detail != null && mounted) _openWithStaleCheck(detail);
  }

  void _openWithStaleCheck(BammWorkOrder wo) {
    String? warning;
    if (widget.snapshotHash != null && widget.snapshotHash!.isNotEmpty) {
      if (bammHasChangedSincePrint(wo, widget.snapshotHash!)) {
        final printedAtMs = int.tryParse(widget.printedAtEpochMs ?? '');
        final printedAtText = printedAtMs != null
            ? ' (printed ${DateFormat('MMM d, y').format(DateTime.fromMillisecondsSinceEpoch(printedAtMs))})'
            : '';
        warning = 'This sheet is out of date$printedAtText - BAMM has changed since it was printed.';
      }
    }
    _openWo(wo, staleWarning: warning);
  }

  /// The work order open in the side pane on desktop (dialog elsewhere).
  BammWorkOrder? _activeWo;
  String? _activeWarning;

  void _openWo(BammWorkOrder wo, {String? staleWarning}) {
    if (MediaQuery.of(context).size.width >= 900) {
      setState(() {
        _activeWo = wo;
        _activeWarning = staleWarning;
      });
    } else {
      BammDetailDialog.show(context, wo, staleWarning: staleWarning);
    }
  }

  Widget _withDetailPane(bool isDesktop, Widget table) {
    final wo = _activeWo;
    if (!isDesktop || wo == null) return table;
    return Row(
      children: [
        Expanded(child: table),
        ResizablePanel(
          prefKey: 'bamm',
          defaultWidth: 560,
          maxWidth: 900,
          child: BammDetailDialog(
            key: ValueKey('wo-${wo.worNoSeq}'),
            workOrder: wo,
            staleWarning: _activeWarning,
            embedded: true,
            onClose: () => setState(() => _activeWo = null),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bammState = ref.watch(bammProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final loadedWorkOrders = bammState.filteredWorkOrders;
    final workOrders = _localSearchOn
        ? filterBammWorkOrdersLocally(loadedWorkOrders, _localSearchQuery)
        : loadedWorkOrders;
    final localSearchHidingRows = _localSearchOn && workOrders.length != loadedWorkOrders.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.of(context).primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(Icons.precision_manufacturing_rounded, color: AppTheme.of(context).primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'BAMM Work Orders',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Live Network Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: bammState.isOnline
                  ? AppTheme.of(context).emerald.withValues(alpha: 0.12)
                  : Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: bammState.isOnline
                    ? AppTheme.of(context).emerald.withValues(alpha: 0.4)
                    : Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: bammState.isOnline ? AppTheme.of(context).emerald : Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  bammState.isPolling
                      ? 'Polling...'
                      : (bammState.isOnline ? 'Online' : 'Offline'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: bammState.isOnline ? AppTheme.of(context).emerald : Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),

          // Poll Network Button
          IconButton(
            tooltip: 'Poll Plant Network Now',
            icon: bammState.isPolling
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            onPressed: () async {
              final online = await ref.read(bammProvider.notifier).pollNetwork();
              await ref.read(bammProvider.notifier).refreshWorkOrders();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(online
                        ? 'Connected to BAMM at ${bammState.config.origin}!'
                        : 'BAMM offline. Showing cached records.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),

          // Batch Update - tick several work orders, apply the same
          // status/step/note change in one go.
          IconButton(
            key: const Key('bamm_batch_update_button'),
            tooltip: 'Batch update',
            icon: const Icon(Icons.playlist_add_check_rounded),
            onPressed: () => context.push('/bamm/batch'),
          ),

          // Settings Button
          IconButton(
            tooltip: 'Connection Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showConnectionConfigDialog,
          ),

          // View Toggle (Desktop)
          if (isDesktop)
            IconButton(
              tooltip: _denseView ? 'Card View' : 'Table View',
              icon: Icon(_denseView ? Icons.view_agenda_outlined : Icons.table_rows_outlined),
              onPressed: () => setState(() => _denseView = !_denseView),
            ),

          const SizedBox(width: 8),
        ],
      ),
      body: _withDetailPane(isDesktop, Column(
        children: [
          // Offline Warning Banner (if offline)
          if (!bammState.isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.withValues(alpha: 0.15),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Not connected to plant network (${bammState.config.origin}). Queries and updates require plant Wi-Fi / VPN.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(bammProvider.notifier).pollNetwork(),
                    child: const Text('Poll Again', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Savable Filters & Presets Bar
          _buildFilterPresetsBar(bammState),

          // Search & Filter Dropdowns Row
          _buildFilterControlsRow(bammState, isDesktop, workOrders.length),

          // Active Filter Chips Bar (if any filters active)
          if (bammState.criteria.activeFilterCount > 0)
            _buildActiveFilterChipsRow(bammState),

          // Local-search Warning: when the "search all loaded fields" toggle
          // is on and narrowing the rows, make that plain rather than let the
          // user think the table only has this many work orders.
          if (localSearchHidingRows)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.purple.withValues(alpha: 0.08),
              child: Text(
                'Showing ${workOrders.length} of ${loadedWorkOrders.length} loaded rows (local search).',
                style: TextStyle(fontSize: 12, color: Colors.purple.shade900),
              ),
            ),

          // Truncation Warning: the server caps a list query at 2000 rows -
          // this makes a truncated result visible instead of silently
          // capping with no indication more exist.
          if (bammState.isTruncated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.blue.withValues(alpha: 0.08),
              child: Text(
                'Showing ${bammState.workOrders.length} of ${bammState.lastQueryTotal} work orders - refine your filters to see the rest.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
              ),
            ),

          const Divider(height: 1),

          // List / Table
          Expanded(
            child: bammState.isLoading && bammState.workOrders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : workOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              bammState.criteria.isEmpty
                                  ? (bammState.isOnline ? 'No BAMM work orders found on server.' : 'Not connected to plant network. Connect to load work orders.')
                                  : 'No BAMM work orders match your active filters.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            if (bammState.criteria.activeFilterCount > 0)
                              OutlinedButton(
                                onPressed: () => ref.read(bammProvider.notifier).clearFilters(),
                                child: const Text('Clear Filters'),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(bammProvider.notifier).refreshWorkOrders(),
                        child: isDesktop && _denseView
                            ? _buildDesktopTable(workOrders)
                            : _buildMobileCardList(workOrders),
                      ),
          ),
        ],
      )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewWorkOrderDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Work Order'),
      ),
    );
  }

  static const double _trailingColumnsWidth = 170;
  static const double _columnGap = 12;

  /// The BAMM table columns this app can render, ordered/filtered per the
  /// user's saved layout (`BammState.columnLayout`) - see
  /// `bamm_table_columns.dart` for why this is not the full live BAMM
  /// column catalogue.
  List<BammColumnDef> _allColumns(BammColumnLayout layout) => applyColumnLayout(buildBammColumns(), layout);

  List<BammColumnDef> _visibleColumns(List<BammColumnDef> all, BammColumnLayout layout) =>
      all.where((c) => isColumnVisible(c, layout)).toList();

  /// Total width of the table's content: each visible column plus its trailing gap, the fixed
  /// trailing cells, and the container chrome around a row - 12px horizontal padding plus 1px of
  /// border on BOTH sides (see [_tableChromeWidth]). The header and the rows apply the same padding
  /// so their content lines up, and the row `ListView` itself carries no horizontal padding - the
  /// 16px page inset lives outside the horizontal scroller instead. Undercounting this by even 2px
  /// throws a RenderFlex overflow, because every cell is laid out at its own fixed width in that Row.
  double _tableWidth(List<BammColumnDef> visible) =>
      visible.fold<double>(0, (sum, c) => sum + c.width + _columnGap) +
      _trailingColumnsWidth +
      _tableChromeWidth;

  /// 12px padding + 1px border, on each side of the header/row containers.
  static const double _tableChromeWidth = 26.0;

}
