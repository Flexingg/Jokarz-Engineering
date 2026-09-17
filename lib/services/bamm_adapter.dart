/// Translates responses from the modular BAMM layer (`lib/bamm/`) into this
/// app's screen-facing view models (`lib/models/bamm_models.dart`).
///
/// `lib/bamm/` deliberately knows nothing about this app's UI types, so
/// [BammService] is the only caller of this file - keeping the translation
/// in one place means a shape change on either side has exactly one spot to
/// fix.
library;

import '../bamm/mutations/model_ops.dart' show childItems, propertyValue;
import '../bamm/schema/lookups.dart';
import '../models/bamm_models.dart';

/// One unwrapped `GetListData` row (`ListQueryResult.rows`) into a
/// [BammWorkOrder]. Rows are already unwrapped from `propertyList` by
/// `BammListQueryClient.fetch`, but [BammWorkOrder.fromPropertyList] also
/// tolerates a still-wrapped row, so either shape works here.
BammWorkOrder bammWorkOrderFromListRow(Map<String, dynamic> row) => BammWorkOrder.fromPropertyList(row);

/// A full DynamicDTO work-order model (`GetById`/`GetNew`/`Save` result, as
/// returned by `BammWorkOrderWriter`) into a [BammWorkOrder].
BammWorkOrder bammWorkOrderFromModel(Map<String, dynamic> model) => BammWorkOrder.fromDynamicDto(model);

/// Resolves [wo]'s enumerated `statusId`/`stepId` into human labels using
/// already-fetched live lookup lists (`GetWorkOrderStatus`/
/// `GetWorkOrderStep`) - never a hardcoded label. `BammWorkOrder.
/// fromDynamicDto` intentionally leaves [BammWorkOrder.status]/[step] blank
/// because `GetById` never carries the description properties, only the raw
/// id; this is the layer that has access to the live lookups and can fill
/// them in. Falls back to showing the raw id (not a wrong guess) when the id
/// has no match in the lookup list, and to blank when there is no id at all.
BammWorkOrder resolveWorkOrderLabels(
  BammWorkOrder wo, {
  required List<BammLookupItem> statusLookups,
  required List<BammLookupItem> stepLookups,
}) {
  String resolve(int? id, List<BammLookupItem> items) {
    if (id == null) return '';
    for (final item in items) {
      if (item.id == id) return item.description;
    }
    return id.toString();
  }

  return wo.copyWith(
    status: resolve(wo.statusId, statusLookups),
    step: resolve(wo.stepId, stepLookups),
  );
}

/// One `BammLookupsClient` option into this app's dropdown item type.
///
/// [LookupOption.id] always travels as a [String]; call sites that compare
/// or forward it as an id (e.g. `BammLookupItem.id == someIntId`) rely on it
/// actually being an `int` at runtime, matching what the old JSON-based
/// parsing produced, so it is parsed back rather than kept as a string.
BammLookupItem bammLookupItemFromOption(LookupOption option) => BammLookupItem(
      id: int.tryParse(option.id) ?? option.id,
      description: option.label,
      code: option.code,
    );

List<BammLookupItem> bammLookupItemsFromOptions(Iterable<LookupOption> options) =>
    options.map(bammLookupItemFromOption).toList();

/// Resolves a raw property id (as read off a `GetById` model, e.g. `RCP_ID`)
/// against an already-fetched live [options] list into the matching
/// [LookupOption] - never a plausible-looking wrong label. `null`/empty/`"0"`
/// means "not set" (returns `null`, same convention as `_optionFromRaw` in
/// `bamm_detail_dialog.dart`). When [rawId] is set but no option matches it
/// (truncated lookup page, stale id, ...), returns a placeholder option
/// labelled with the id itself so the dialog never shows a bare number with
/// no indication it's unresolved.
LookupOption? resolveLookupOption(String? rawId, List<LookupOption> options) {
  final id = rawId?.trim();
  if (id == null || id.isEmpty || id == '0') return null;
  for (final option in options) {
    if (option.id == id) return option;
  }
  return LookupOption(id: id, label: 'id $id', code: '', inactive: false);
}

/// The `WO_DETAIL` child set of a full `GetById`/`GetNew`/`Save` model into
/// display-ready [BammActivityLine]s - display + add only (no edit/delete),
/// per the batch's scope.
List<BammActivityLine> bammActivityLinesFromModel(Map<String, dynamic> model) {
  return childItems(model, 'WO_DETAIL').map((item) {
    final hoursRaw = propertyValue(item, 'WOD_ACT_LINE_HOUR_NB');
    return BammActivityLine(
      id: propertyValue(item, 'WOD_ID') ?? '',
      description: propertyValue(item, 'WOD_DESCR') ?? '',
      activityId: propertyValue(item, 'ACY_ID') ?? '',
      subActivityId: propertyValue(item, 'SAC_ID') ?? '',
      hours: hoursRaw == null ? null : double.tryParse(hoursRaw),
      memo: propertyValue(item, 'WOD_MEMO') ?? '',
    );
  }).where((line) => line.id.isNotEmpty && line.id != '-1').toList();
}
