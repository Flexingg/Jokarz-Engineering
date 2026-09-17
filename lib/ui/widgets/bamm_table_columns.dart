/// Column definitions for the BAMM desktop table header (`bamm_screen.dart`).
///
/// The live BAMM column catalogue (`lib/bamm/schema/catalogue.dart`,
/// `GetListConfigurationStructure`) enumerates far more fields than this app
/// fetches data for - `BammService._majorColumns` is the actual list-query
/// field set. A column with no fetched data and no renderer would silently
/// show nothing if a user added it from a chooser, which is exactly the kind
/// of quiet fake the BAMM save-honesty work in this batch is trying to
/// eliminate - so this list is restricted to keys `BammService` really
/// requests (and `BammWorkOrder` really carries), each with its own cell
/// renderer. `key` doubles as the server-side sort field name
/// (`ListOrderBy.name`) for every column here.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/bamm_models.dart';

class BammColumnDef {
  final String key;

  /// Identity used by the column chooser, hide/show, drag-reorder and the
  /// persisted layout (`BammService.saveColumnLayout`). Defaults to [key].
  ///
  /// Only diverges from [key] for the "3rd level - description" chooser
  /// column (`bamm_table_columns.dart`'s `buildBammColumns`): it shows the
  /// exact same live field as the default-visible "Machine" column
  /// (`funCodeLevelNiv3Description` - there is no separate BAMM property for
  /// "level 3" vs "Machine", they are the same asset-tree level), so it MUST
  /// share [key] for sorting/filtering to dispatch correctly (both
  /// `bamm_sort.dart` and `_applyColumnFilter` switch on [key], and [key] is
  /// also what's sent as the live `orderByFields` name). Two columns can't
  /// share a map key in `applyColumnLayout`'s `byId` lookup, though, so [id]
  /// gives the chooser a distinct, purely-local identity for this one case.
  final String id;

  final String header;
  final bool defaultVisible;
  final bool hideable;
  final double width;
  final String Function(BammWorkOrder) textOf;
  final Widget Function(BuildContext, BammWorkOrder)? cellBuilder;

  BammColumnDef({
    required this.key,
    String? id,
    required this.header,
    this.defaultVisible = false,
    this.hideable = true,
    this.width = 140,
    required this.textOf,
    this.cellBuilder,
  }) : id = id ?? key;

  Widget buildCell(BuildContext context, BammWorkOrder wo) {
    if (cellBuilder != null) return cellBuilder!(context, wo);
    final text = textOf(wo);
    return Text(
      text.isEmpty ? '-' : text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: text.isEmpty ? Colors.grey.shade500 : null),
    );
  }
}

final DateFormat _dateFmt = DateFormat('MMM d, y');

Widget _badge(String text, Color color) {
  if (text.isEmpty) return const Text('-', style: TextStyle(fontSize: 12, color: Colors.grey));
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}

/// The full set of BAMM table columns this app can render, in the default
/// order. `key` matches `BammService._majorColumns` / the BAMM list-query
/// field names, so it also works unmodified as a sort key and as a
/// quick-filter field. Default-visible keys match the plan's agreed set: WO#,
/// Registered, Status, Step, Description, Work done, Machine, Assembly, Area,
/// Responsible.
List<BammColumnDef> buildBammColumns() => [
      BammColumnDef(
        key: 'worNoSeq',
        header: 'WO#',
        defaultVisible: true,
        hideable: false,
        width: 100,
        textOf: (wo) => wo.worNoSeq,
        cellBuilder: (context, wo) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '#${wo.worNoSeq}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: wo.worNoSeq));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied WO #${wo.worNoSeq}'), duration: const Duration(seconds: 1)),
                );
              },
              child: Icon(Icons.copy_rounded, size: 12, color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      ),
      BammColumnDef(
        key: 'woIssueDate',
        header: 'Registered',
        defaultVisible: true,
        width: 100,
        textOf: (wo) => wo.issueDate != null ? _dateFmt.format(wo.issueDate!) : '',
      ),
      BammColumnDef(
        key: 'woStatusDescription',
        header: 'Status',
        defaultVisible: true,
        width: 120,
        textOf: (wo) => wo.status,
        cellBuilder: (context, wo) => _badge(wo.status, wo.statusColor),
      ),
      BammColumnDef(
        key: 'woStepDescription',
        header: 'Step',
        defaultVisible: true,
        width: 110,
        textOf: (wo) => wo.step,
        cellBuilder: (context, wo) => _badge(wo.step, wo.stepColor),
      ),
      BammColumnDef(
        key: 'woDescription',
        header: 'Description',
        defaultVisible: true,
        width: 240,
        textOf: (wo) => wo.description,
      ),
      BammColumnDef(
        key: 'woTask',
        header: 'Work done',
        defaultVisible: true,
        width: 240,
        textOf: (wo) => wo.workDone,
      ),
      BammColumnDef(
        key: 'funCodeLevelNiv3Description',
        header: 'Machine',
        defaultVisible: true,
        width: 160,
        textOf: (wo) => wo.machine.isNotEmpty ? wo.machine : wo.assetId,
      ),
      BammColumnDef(
        key: 'funCodeLevelNiv4Description',
        header: 'Assembly',
        defaultVisible: true,
        width: 160,
        textOf: (wo) => wo.assembly,
      ),
      BammColumnDef(
        key: 'funCodeLevelNiv1Description',
        header: 'Area',
        defaultVisible: true,
        width: 120,
        textOf: (wo) => wo.area,
      ),
      BammColumnDef(
        key: 'recipientName',
        header: 'Responsible',
        defaultVisible: true,
        width: 150,
        textOf: (wo) => wo.responsible,
      ),
      BammColumnDef(
        key: 'requesterName',
        header: 'Requester',
        width: 150,
        textOf: (wo) => wo.requester,
      ),
      BammColumnDef(
        key: 'worNumber3',
        header: 'EM Priority',
        width: 100,
        textOf: (wo) => wo.priority,
      ),
      BammColumnDef(
        key: 'executionModeDescription',
        header: 'Machine Status',
        width: 140,
        textOf: (wo) => wo.executionMode,
      ),
      BammColumnDef(
        key: 'worEstLaborTime',
        header: 'Labor Hours',
        width: 110,
        textOf: (wo) => wo.laborHours != null ? '${wo.laborHours} hrs' : '',
      ),
      BammColumnDef(
        key: 'woRequiredDate',
        header: 'Required date',
        width: 120,
        textOf: (wo) => wo.requiredDate != null ? _dateFmt.format(wo.requiredDate!) : '',
      ),
      // Chooser-only, OFF by default (per the plan - these are lower-value
      // than Area/Machine/Assembly and would crowd the default set).
      BammColumnDef(
        key: 'funCodeLevelNiv2Description',
        header: 'Function Code - Level 2',
        width: 160,
        textOf: (wo) => wo.level2,
      ),
      // Same live field as "Machine" above (see BammColumnDef.id's doc
      // comment) - a distinct chooser id, but the real key, so sort/filter
      // dispatch to the exact same code path as Machine.
      BammColumnDef(
        key: 'funCodeLevelNiv3Description',
        id: 'funCodeLevelNiv3DescriptionAsLevel',
        header: 'Function Code - Level 3',
        width: 160,
        textOf: (wo) => wo.machine.isNotEmpty ? wo.machine : wo.assetId,
      ),
    ];

/// Applies a saved [BammColumnLayout] on top of [buildBammColumns]'s
/// defaults: known columns are reordered per `layout.order` (unknown keys in
/// the saved layout, e.g. from a future column that got renamed, are
/// dropped); anything not mentioned in `layout.order` is appended at the
/// end; visibility comes from `layout.hidden` (or `defaultVisible` when the
/// layout has never been saved).
List<BammColumnDef> applyColumnLayout(List<BammColumnDef> all, BammColumnLayout layout) {
  final byId = {for (final c in all) c.id: c};
  final ordered = <BammColumnDef>[];
  for (final id in layout.order) {
    final def = byId.remove(id);
    if (def != null) ordered.add(def);
  }
  ordered.addAll(byId.values);
  return ordered;
}

bool isColumnVisible(BammColumnDef def, BammColumnLayout layout) {
  if (layout.hidden.contains(def.id)) return false;
  if (layout.order.contains(def.id)) return true;
  return def.defaultVisible;
}
