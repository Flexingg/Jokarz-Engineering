part of '../bamm_screen.dart';

extension _BammScreenTable on _BammScreenState {
  /// Rebuilds the saved layout so [visibleKeysInOrder] becomes the new
  /// visible order, keeping every hidden column's relative order untouched.
  BammColumnLayout _layoutWithVisibleOrder(BammColumnLayout current, List<String> visibleIdsInOrder) {
    final hiddenInOrder = _allColumns(current).map((c) => c.id).where((id) => current.hidden.contains(id)).toList();
    return BammColumnLayout(order: [...visibleIdsInOrder, ...hiddenInOrder], hidden: current.hidden);
  }

  void _reorderColumn(String draggedId, String targetId, List<BammColumnDef> visibleColumns) {
    if (draggedId == targetId) return;
    final ids = visibleColumns.map((c) => c.id).toList();
    final oldIndex = ids.indexOf(draggedId);
    final newIndex = ids.indexOf(targetId);
    if (oldIndex == -1 || newIndex == -1) return;
    ids.removeAt(oldIndex);
    ids.insert(newIndex, draggedId);
    final layout = ref.read(bammProvider).columnLayout;
    ref.read(bammProvider.notifier).setColumnLayout(_layoutWithVisibleOrder(layout, ids));
  }

  void _moveColumn(String id, int delta, List<BammColumnDef> visibleColumns) {
    final ids = visibleColumns.map((c) => c.id).toList();
    final index = ids.indexOf(id);
    final target = index + delta;
    if (index == -1 || target < 0 || target >= ids.length) return;
    ids.removeAt(index);
    ids.insert(target, id);
    final layout = ref.read(bammProvider).columnLayout;
    ref.read(bammProvider.notifier).setColumnLayout(_layoutWithVisibleOrder(layout, ids));
  }

  void _hideColumn(String id) {
    final layout = ref.read(bammProvider).columnLayout;
    ref.read(bammProvider.notifier).setColumnLayout(BammColumnLayout(order: layout.order, hidden: {...layout.hidden, id}));
  }

  void _showColumn(String id) {
    final layout = ref.read(bammProvider).columnLayout;
    // A column that isn't default-visible (e.g. Requester) and has never
    // been explicitly ordered is invisible purely because `isColumnVisible`
    // falls through to `defaultVisible == false` - removing it from
    // `hidden` alone is a no-op for that case, since it was never in
    // `hidden` to begin with. Adding it to `order` makes `isColumnVisible`
    // return true regardless of its default.
    final order = layout.order.contains(id) ? layout.order : [...layout.order, id];
    ref.read(bammProvider.notifier).setColumnLayout(
          BammColumnLayout(order: order, hidden: layout.hidden.where((k) => k != id).toSet()),
        );
  }

  /// Applies the existing quick-filter setter for [column] when BAMM has
  /// one (mirrors the toolbar dropdowns); falls back to the free-text
  /// search field for columns with no dedicated filter (description, work
  /// done, priority, labor hours, dates).
  void _applyColumnFilter(BammColumnDef column, String value) {
    final notifier = ref.read(bammProvider.notifier);
    switch (column.key) {
      case 'woStatusDescription':
        notifier.setStatusFilter(value.isEmpty ? null : value);
      case 'woStepDescription':
        notifier.setStepFilter(value.isEmpty ? null : value);
      case 'funCodeLevelNiv1Description':
      case 'regrouping1Description':
        notifier.setAreaFilter(value.isEmpty ? null : value);
      case 'funCodeLevelNiv2Description':
        notifier.setLevel2Filter(value.isEmpty ? null : value);
      case 'recipientName':
        notifier.setResponsibleFilter(value.isEmpty ? null : value);
      case 'requesterName':
        notifier.setRequesterFilter(value.isEmpty ? null : value);
      case 'funCodeLevelNiv3Description':
        notifier.setMachineFilter(value.isEmpty ? null : value);
      case 'funCodeLevelNiv4Description':
        notifier.setAssemblyFilter(value.isEmpty ? null : value);
      case 'executionModeDescription':
        notifier.setExecutionModeFilter(value.isEmpty ? null : value);
      default:
        _searchCtrl.text = value;
        notifier.setSearchQuery(value);
    }
  }

  Future<String?> _promptFilterValue(BammColumnDef column) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Filter by ${column.header}'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Value')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Apply')),
        ],
      ),
    );
  }

  /// The header/cell right-click (desktop) or long-press (mobile) menu:
  /// filter by value, sort asc/desc, hide column, move left/right.
  /// [prefillValue] is set when triggered from a data cell (so "Filter by
  /// this value" applies immediately); null when triggered from the header
  /// itself (prompts for a value instead).
  Future<void> _showColumnMenu(
    Offset globalPosition,
    BammColumnDef column,
    List<BammColumnDef> visibleColumns, {
    String? prefillValue,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final index = visibleColumns.indexWhere((c) => c.id == column.id);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(globalPosition & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
          value: 'filter',
          child: Text(prefillValue != null && prefillValue.isNotEmpty ? 'Filter by this value' : 'Filter by value...'),
        ),
        const PopupMenuItem(value: 'sort_asc', child: Text('Sort ascending')),
        const PopupMenuItem(value: 'sort_desc', child: Text('Sort descending')),
        if (column.hideable) const PopupMenuItem(value: 'hide', child: Text('Hide column')),
        PopupMenuItem(value: 'move_left', enabled: index > 0, child: const Text('Move left')),
        PopupMenuItem(value: 'move_right', enabled: index != -1 && index < visibleColumns.length - 1, child: const Text('Move right')),
      ],
    );
    if (selected == null || !mounted) return;
    final notifier = ref.read(bammProvider.notifier);
    switch (selected) {
      case 'filter':
        final value = prefillValue ?? await _promptFilterValue(column);
        if (value != null && mounted) _applyColumnFilter(column, value);
      case 'sort_asc':
        notifier.setSortField(column.key, ascending: true);
      case 'sort_desc':
        notifier.setSortField(column.key, ascending: false);
      case 'hide':
        _hideColumn(column.id);
      case 'move_left':
        _moveColumn(column.id, -1, visibleColumns);
      case 'move_right':
        _moveColumn(column.id, 1, visibleColumns);
    }
  }

  Widget _headerCell(BammColumnDef column, List<BammColumnDef> visibleColumns) {
    final criteria = ref.watch(bammProvider).criteria;
    final sortedAsc = criteria.sortField == column.key && criteria.sortAscending;
    final sortedDesc = criteria.sortField == column.key && !criteria.sortAscending;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != column.id,
      onAcceptWithDetails: (details) => _reorderColumn(details.data, column.id, visibleColumns),
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: column.width,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: candidateData.isNotEmpty
              ? BoxDecoration(border: Border(left: BorderSide(color: AppTheme.of(context).primary, width: 2)))
              : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(bammProvider.notifier).setSort(column.key),
            onSecondaryTapDown: (d) => _showColumnMenu(d.globalPosition, column, visibleColumns),
            onLongPressStart: (d) => _showColumnMenu(d.globalPosition, column, visibleColumns),
            child: Row(
              children: [
                Draggable<String>(
                  data: column.id,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.of(context).surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.of(context).border)),
                      child: Text(column.header, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  child: Icon(Icons.drag_indicator, size: 14, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    column.header,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                if (sortedAsc) const Icon(Icons.arrow_upward_rounded, size: 12),
                if (sortedDesc) const Icon(Icons.arrow_downward_rounded, size: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(List<BammColumnDef> visibleColumns) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey.shade100,
      child: Row(
        children: [
          for (final column in visibleColumns) ...[
            _headerCell(column, visibleColumns),
            const SizedBox(width: _BammScreenState._columnGap),
          ],
          SizedBox(
            width: _BammScreenState._trailingColumnsWidth,
            child: Row(
              children: [
                const Expanded(child: Text('Linked', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                IconButton(
                  tooltip: 'Choose columns',
                  icon: const Icon(Icons.view_column_outlined, size: 18),
                  onPressed: _showColumnChooser,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showColumnChooser() {
    final layout = ref.read(bammProvider).columnLayout;
    final all = _allColumns(layout);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Columns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              for (final column in all)
                CheckboxListTile(
                  title: Text(column.header),
                  value: isColumnVisible(column, ref.read(bammProvider).columnLayout),
                  onChanged: column.hideable
                      ? (checked) {
                          if (checked == true) {
                            _showColumn(column.id);
                          } else {
                            _hideColumn(column.id);
                          }
                          setSheetState(() {});
                        }
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(BammWorkOrder wo, List<BammColumnDef> visibleColumns) {
    final linkedItems = ref.read(projectProvider.notifier).findItemsLinkedToBamm(wo.worNoSeq);

    return InkWell(
      onTap: () => BammDetailDialog.show(context, wo),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.of(context).surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.of(context).border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final column in visibleColumns) ...[
              SizedBox(
                width: column.width,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onSecondaryTapDown: (d) => _showColumnMenu(d.globalPosition, column, visibleColumns, prefillValue: column.textOf(wo)),
                  onLongPressStart: (d) => _showColumnMenu(d.globalPosition, column, visibleColumns, prefillValue: column.textOf(wo)),
                  child: column.buildCell(context, wo),
                ),
              ),
              const SizedBox(width: _BammScreenState._columnGap),
            ],
            SizedBox(
              width: _BammScreenState._trailingColumnsWidth,
              child: Row(
                children: [
                  if (linkedItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.of(context).emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.of(context).emerald.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_rounded, size: 12, color: AppTheme.of(context).emerald),
                          const SizedBox(width: 4),
                          Text(
                            '${linkedItems.length} linked',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.of(context).emerald),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'View Work Order Details',
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onPressed: () => BammDetailDialog.show(context, wo),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Desktop table: a real header row (sort / right-click filter menu / drag
  /// to reorder / hide) above the data rows, both driven by the same
  /// ordered column list so they always line up.
  Widget _buildDesktopTable(List<BammWorkOrder> orders) {
    final layout = ref.watch(bammProvider).columnLayout;
    final visibleColumns = _visibleColumns(_allColumns(layout), layout);
    final width = _tableWidth(visibleColumns);

    // The 16px inset lives OUTSIDE the horizontal scroller on purpose. [_tableWidth] already
    // accounts for the 12px horizontal padding inside the header/row containers and nothing else,
    // so padding the list as well would leave every row 32px short of the width its children sum
    // to - which is exactly the RenderFlex overflow this used to throw at 1400px.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              _buildTableHeader(visibleColumns),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, idx) => _buildTableRow(orders[idx], visibleColumns),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCardList(List<BammWorkOrder> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (ctx, idx) {
        final wo = orders[idx];
        final linkedItems = ref.read(projectProvider.notifier).findItemsLinkedToBamm(wo.worNoSeq);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => BammDetailDialog.show(context, wo),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.of(context).primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${wo.worNoSeq}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.of(context).primary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: wo.statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                wo.status,
                                style: TextStyle(color: wo.statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: wo.stepColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                wo.step,
                                style: TextStyle(color: wo.stepColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (linkedItems.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.of(context).emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${linkedItems.length} linked',
                                  style: TextStyle(color: AppTheme.of(context).emerald, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (wo.issueDate != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMM d').format(wo.issueDate!),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wo.description,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (wo.workDone.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Work done',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(wo.workDone, style: const TextStyle(fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (wo.machine.isNotEmpty || wo.area.isNotEmpty)
                        Expanded(
                          child: Text(
                            [
                              if (wo.machine.isNotEmpty) wo.machine,
                              if (wo.area.isNotEmpty) 'Area: ${wo.area}',
                            ].join(' • '),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (wo.responsible.isNotEmpty)
                        Text(
                          'Resp: ${wo.responsible}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      if (wo.requester.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'Req: ${wo.requester}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
