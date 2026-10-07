part of '../open_orders_screen.dart';

/// Desktop data table for Open Orders: sortable columns, multi-select with a
/// floating action bar, right-click context menu and a details drawer.
extension _OpenOrdersTable on _OpenOrdersScreenState {
  static const double _tableMinWidth = 1020;

  List<_OrderEntry> _sortedEntries(List<_OrderEntry> list) {
    final key = _sortKey;
    if (key == null) return list;
    int cmp(_OrderEntry a, _OrderEntry b) {
      switch (key) {
        case 'po':
          return a.po.compareTo(b.po);
        case 'desc':
          return a.description.toLowerCase().compareTo(
            b.description.toLowerCase(),
          );
        case 'vendor':
          return a.vendorName.toLowerCase().compareTo(
            b.vendorName.toLowerCase(),
          );
        case 'project':
          return a.projectTitle.toLowerCase().compareTo(
            b.projectTitle.toLowerCase(),
          );
        case 'price':
          return a.price.compareTo(b.price);
        case 'eta':
          if (a.eta == null && b.eta == null) return 0;
          if (a.eta == null) return 1; // no ETA always last
          if (b.eta == null) return -1;
          return a.eta!.compareTo(b.eta!);
      }
      return 0;
    }

    final out = [...list]..sort(cmp);
    return _sortAsc ? out : out.reversed.toList();
  }

  void _toggleSort(String key) {
    _rebuild(() {
      if (_sortKey == key) {
        if (!_sortAsc) {
          _sortKey = null; // third click clears the sort
          _sortAsc = true;
        } else {
          _sortAsc = false;
        }
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
  }

  Future<void> _setDelivered(
    List<_OrderEntry> entries,
    bool delivered,
    dynamic notifier,
  ) async {
    final changed = entries.where((e) => e.delivered != delivered).toList();
    if (changed.isEmpty) return;
    Future<void> apply(bool value) async {
      for (final e in changed) {
        if (e.isStandalone) {
          await notifier.updateStandaloneOrder(
            e.standalone!.copyWith(delivered: value),
          );
        } else {
          await notifier.toggleOrderDelivered(e.project!.id, e.order!.id);
        }
      }
    }

    await apply(delivered);
    if (!mounted) return;
    _rebuild(() => _selected.clear());
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          changed.length == 1
              ? (delivered
                    ? 'Order marked delivered'
                    : 'Order marked not delivered')
              : '${changed.length} orders ${delivered ? 'marked delivered' : 'marked not delivered'}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => apply(!delivered),
        ),
      ),
    );
  }

  Future<void> _copyText(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Copied $what')));
  }

  String _csv(List<_OrderEntry> entries) {
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    final b = StringBuffer(
      'PO,PR,Description,Vendor,Project,ETA,Price,Delivered\n',
    );
    for (final e in entries) {
      b.writeln(
        [
          q(e.po),
          q(e.pr),
          q(e.description),
          q(e.vendorName),
          q(e.projectTitle),
          q(e.eta == null ? '' : DateFormat('yyyy-MM-dd').format(e.eta!)),
          e.price.toStringAsFixed(2),
          e.delivered ? 'yes' : 'no',
        ].join(','),
      );
    }
    return b.toString();
  }

  void _openEntry(_OrderEntry e) {
    if (e.isStandalone) {
      _showEditStandaloneOrderDialog(context, e.standalone!);
    } else {
      _showEditOrderDialog(context, e);
    }
  }

  Future<void> _showRowMenu(
    Offset globalPos,
    _OrderEntry e,
    dynamic notifier,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final colors = AppTheme.of(context);
    PopupMenuItem<String> item(
      String v,
      IconData icon,
      String label, {
      Color? color,
      String? hint,
    }) => PopupMenuItem(
      value: v,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? colors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: color, fontSize: 13)),
          ),
          if (hint != null)
            Text(
              hint,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
        ],
      ),
    );

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPos & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        item('open', Icons.open_in_new_rounded, 'Open details'),
        item(
          'deliver',
          e.delivered ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
          e.delivered ? 'Mark not delivered' : 'Mark delivered',
        ),
        if (e.po.isNotEmpty)
          item('copyPo', Icons.copy_rounded, 'Copy PO #', hint: e.po),
        if (e.pr.isNotEmpty)
          item('copyPr', Icons.copy_rounded, 'Copy PR #', hint: e.pr),
        if (e.isStandalone)
          item('link', Icons.link_rounded, 'Link to project...'),
        if (e.trackingUrl.isNotEmpty)
          item('track', Icons.track_changes_rounded, 'Open tracking page'),
        const PopupMenuDivider(),
        item(
          'delete',
          Icons.delete_outline_rounded,
          'Delete order',
          color: colors.coral,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'open':
        _openEntry(e);
      case 'deliver':
        await _setDelivered([e], !e.delivered, notifier);
      case 'copyPo':
        await _copyText(e.po, 'PO ${e.po}');
      case 'copyPr':
        await _copyText(e.pr, 'PR ${e.pr}');
      case 'link':
        _showAttachToProjectDialog(context, e);
      case 'track':
        var url = e.trackingUrl.trim();
        if (!url.startsWith('http://') && !url.startsWith('https://'))
          url = 'https://$url';
        final uri = Uri.tryParse(url);
        if (uri != null)
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete this order?'),
            content: Text(
              e.description.isEmpty
                  ? 'This order will be removed.'
                  : e.description,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colors.coral),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok == true) {
          if (e.isStandalone) {
            await notifier.deleteStandaloneOrder(e.standalone!.id);
          } else {
            await notifier.deleteOrder(e.project!.id, e.order!.id);
          }
          _rebuild(() {
            _selected.remove(e.key);
            if (_activeKey == e.key) _activeKey = null;
          });
        }
    }
  }

  /// Short ETA pill for the table (the long form lives in the details drawer).
  Widget _etaChip(DateTime eta) {
    final colors = AppTheme.of(context);
    final now = DateTime.now();
    final days = DateTime(eta.year, eta.month, eta.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final (label, color) = days < 0
        ? ('Overdue ${-days}d', colors.coral)
        : days == 0
            ? ('Due today', colors.amber)
            : days <= 3
                ? ('In ${days}d', colors.amber)
                : ('In ${days}d', colors.primary);
    return Tooltip(
      message: DateFormat('EEE, MMM d, y').format(eta),
      child: ExpressiveBadge(label: label, color: color, fontSize: 11),
    );
  }

  Widget _headerCell(
    String label,
    String key, {
    double? width,
    bool right = false,
    int flex = 0,
  }) {
    final colors = AppTheme.of(context);
    final motion = Motion.of(context);
    final active = _sortKey == key;
    final cell = InkWell(
      onTap: () => _toggleSort(key),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: right
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: active ? colors.primary : colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedOpacity(
              duration: motion.quick,
              opacity: active ? 1 : 0,
              child: AnimatedRotation(
                duration: motion.pop,
                curve: motion.spring,
                turns: _sortAsc ? 0 : 0.5,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 14,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return width != null
        ? SizedBox(width: width, child: cell)
        : Expanded(flex: flex, child: cell);
  }

  Widget _orderRow(
    _OrderEntry e,
    int index,
    NumberFormat currency,
    dynamic notifier,
  ) {
    final colors = AppTheme.of(context);
    final selected = _selected.contains(e.key);
    final active = _activeKey == e.key;
    final overdue =
        !e.delivered && e.eta != null && e.eta!.isBefore(DateTime.now());
    final bg = active
        ? colors.primary.withValues(alpha: 0.12)
        : selected
        ? colors.primary.withValues(alpha: 0.07)
        : Colors.transparent;

    return Material(
      color: bg,
      child: InkWell(
        hoverColor: colors.textPrimary.withValues(alpha: 0.04),
        onTap: () => _rebuild(() => _activeKey = active ? null : e.key),
        onSecondaryTapUp: (d) => _showRowMenu(d.globalPosition, e, notifier),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Checkbox(
                  value: selected,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => _rebuild(() {
                    if (v == true) {
                      _selected.add(e.key);
                    } else {
                      _selected.remove(e.key);
                    }
                  }),
                ),
              ),
              SizedBox(
                width: 190,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: e.delivered
                        ? ExpressiveBadge(
                            label: 'Delivered',
                            color: colors.emerald,
                            fontSize: 11,
                          )
                        : e.eta != null
                        ? _etaChip(e.eta!)
                        : Text(
                            'No ETA',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(
                width: 130,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    e.po.isEmpty ? (e.pr.isEmpty ? '-' : 'PR ${e.pr}') : e.po,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    e.description.isEmpty
                        ? 'Parts / Material Order'
                        : e.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: e.delivered
                          ? TextDecoration.lineThrough
                          : null,
                      color: e.delivered
                          ? colors.textSecondary
                          : (overdue ? colors.coral : colors.textPrimary),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    e.vendorName.isEmpty ? '-' : e.vendorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    e.projectTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: e.isStandalone
                          ? colors.amber
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    currency.format(e.price),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersTable(
    List<_OrderEntry> all,
    List<_OrderEntry> filtered,
    NumberFormat currency,
    DateFormat dateFormat,
    dynamic notifier,
  ) {
    final colors = AppTheme.of(context);
    final motion = Motion.of(context);
    final rows = _sortedEntries(filtered);
    final selectedEntries = all
        .where((e) => _selected.contains(e.key))
        .toList();
    final active = all.where((e) => e.key == _activeKey).firstOrNull;
    if (active != null) _lastActive = active;
    final allChecked =
        rows.isNotEmpty && rows.every((e) => _selected.contains(e.key));

    final table = Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth < _tableMinWidth
              ? _tableMinWidth
              : c.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: c.maxHeight,
              child: Column(
                children: [
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colors.border)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Checkbox(
                            value: allChecked,
                            visualDensity: VisualDensity.compact,
                            onChanged: (v) => _rebuild(() {
                              if (v == true) {
                                _selected.addAll(rows.map((e) => e.key));
                              } else {
                                _selected.clear();
                              }
                            }),
                          ),
                        ),
                        _headerCell('Status / ETA', 'eta', width: 190),
                        _headerCell('PO', 'po', width: 130),
                        _headerCell('Description', 'desc', flex: 5),
                        _headerCell('Vendor', 'vendor', width: 150),
                        _headerCell('Project', 'project', flex: 3),
                        _headerCell('Price', 'price', width: 110, right: true),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: rows.length,
                      itemBuilder: (context, i) =>
                          _orderRow(rows[i], i, currency, notifier),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    final drawerOpen = active != null;
    return Stack(
      children: [
        Row(
          children: [
            Expanded(child: table),
            TweenAnimationBuilder<double>(
              tween: Tween(end: drawerOpen ? 1 : 0),
              duration: motion.sheet,
              curve: motion.spring,
              builder: (context, t, _) {
                final w = (_drawerWidth * t).clamp(0.0, _drawerWidth + 24);
                if (w < 1) return const SizedBox.shrink();
                return SizedBox(
                  width: w,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: 0,
                      maxWidth: _drawerWidth,
                      child: SizedBox(
                        width: _drawerWidth,
                        child: _orderDrawer(
                          active ?? _lastActive,
                          currency,
                          dateFormat,
                          notifier,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: IgnorePointer(
            ignoring: selectedEntries.isEmpty,
            child: AnimatedSlide(
              duration: motion.sheet,
              curve: motion.spring,
              offset: selectedEntries.isEmpty
                  ? const Offset(0, 1.6)
                  : Offset.zero,
              child: AnimatedOpacity(
                duration: motion.quick,
                opacity: selectedEntries.isEmpty ? 0 : 1,
                child: ExcludeSemantics(
                  excluding: selectedEntries.isEmpty,
                  child: Center(child: _bulkBar(selectedEntries, notifier)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const double _drawerWidth = 380;

  Widget _bulkBar(List<_OrderEntry> sel, dynamic notifier) {
    final colors = AppTheme.of(context);
    final allDelivered = sel.isNotEmpty && sel.every((e) => e.delivered);
    return Material(
      color: colors.surface,
      elevation: 10,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${sel.length} selected',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(width: 14),
            ElevatedButton.icon(
              onPressed: () => _setDelivered(sel, !allDelivered, notifier),
              icon: Icon(
                allDelivered ? Icons.undo_rounded : Icons.check_rounded,
                size: 16,
              ),
              label: Text(
                allDelivered ? 'Mark not delivered' : 'Mark delivered',
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _copyText(_csv(sel), '${sel.length} orders as CSV'),
              icon: const Icon(Icons.table_view_rounded, size: 16),
              label: const Text('Copy as CSV'),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Clear selection',
              onPressed: () => _rebuild(() => _selected.clear()),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderDrawer(
    _OrderEntry? e,
    NumberFormat currency,
    DateFormat dateFormat,
    dynamic notifier,
  ) {
    final colors = AppTheme.of(context);
    if (e == null) return const SizedBox.shrink();
    Widget field(String label, String value) => SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.po.isEmpty ? 'No PO yet' : 'PO ${e.po}',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
                IconButton(
                  tooltip: 'Close details',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _rebuild(() => _activeKey = null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            Text(
              e.description.isEmpty ? 'Parts / Material Order' : e.description,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            e.delivered
                ? ExpressiveBadge(
                    label: 'Delivered',
                    color: colors.emerald,
                    fontSize: 12,
                  )
                : (e.eta != null
                      ? _buildEtaBadge(e.eta!)
                      : Text(
                          'No ETA set',
                          style: TextStyle(color: colors.textSecondary),
                        )),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                field('Vendor', e.vendorName),
                field('Price', currency.format(e.price)),
                field('Project', e.projectTitle),
                field('PR', e.pr),
                field('ETA', e.eta == null ? '' : dateFormat.format(e.eta!)),
                field('Quote #', e.vendorQuoteNumber),
              ],
            ),
            if (e.bammWorkOrders.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final wo in e.bammWorkOrders)
                    BammChip(worNo: wo, isDense: true),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _setDelivered([e], !e.delivered, notifier),
                  child: Text(
                    e.delivered ? 'Mark not delivered' : 'Mark delivered',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _openEntry(e),
                  child: const Text('Edit'),
                ),
                if (e.po.isNotEmpty)
                  OutlinedButton(
                    onPressed: () => _copyText(e.po, 'PO ${e.po}'),
                    child: const Text('Copy PO #'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
