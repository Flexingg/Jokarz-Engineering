/// Translates responses from the modular BAMM layer (`lib/bamm/`) into this
/// app's screen-facing view models (`lib/models/bamm_models.dart`).
///
/// `lib/bamm/` deliberately knows nothing about this app's UI types, so
/// [BammService] is the only caller of this file - keeping the translation
/// in one place means a shape change on either side has exactly one spot to
/// fix.
library;

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
