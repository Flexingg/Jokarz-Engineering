/// Client-side sort for BAMM work-order table rows.
///
/// BAMM's `GetListData` accepts `orderByFields` but the real server does not
/// honour it (see `~/repos/BAMM/captures/*.har` for `WorkOrderOpenOnAssetList`
/// - the requested order is silently ignored). The reference web app never
/// relies on server-side sort either: its header click sorts the already-
/// fetched rows locally (`~/repos/BAMM/app/static/js/list/table.js:174-189,
/// 401-412`) - blanks always sort last regardless of direction, and numeric/
/// date columns compare by magnitude rather than string. This mirrors that.
library;

import '../models/bamm_models.dart';

enum BammSortType { text, numeric, date }

/// Column-key -> comparison type, matching `BammService._majorColumns` /
/// `bamm_table_columns.dart`'s `key`s (also the server `orderByFields` name).
BammSortType sortTypeForField(String field) {
  switch (field) {
    case 'worEstLaborTime':
    case 'worNumber3':
      return BammSortType.numeric;
    case 'woIssueDate':
    case 'woRequiredDate':
      return BammSortType.date;
    default:
      return BammSortType.text;
  }
}

Object? _rawValue(BammWorkOrder wo, String field) {
  switch (field) {
    case 'worNoSeq':
      return wo.worNoSeq;
    case 'woIssueDate':
      return wo.issueDate;
    case 'woStatusDescription':
      return wo.status;
    case 'woStepDescription':
      return wo.step;
    case 'woDescription':
      return wo.description;
    case 'woTask':
      return wo.workDone;
    case 'funCodeLevelNiv3Description':
      return wo.machine.isNotEmpty ? wo.machine : wo.assetId;
    case 'regrouping1Description':
      return wo.area;
    case 'recipientName':
      return wo.responsible;
    case 'requesterName':
      return wo.requester;
    case 'worNumber3':
      return wo.priority;
    case 'executionModeDescription':
      return wo.executionMode;
    case 'worEstLaborTime':
      return wo.laborHours;
    case 'woRequiredDate':
      return wo.requiredDate;
    default:
      return null;
  }
}

num? _numOf(Object? v) {
  if (v == null) return null;
  if (v is num) return v;
  final match = RegExp(r'-?\d+(\.\d+)?').stringMatch(v.toString());
  if (match == null) return null;
  return num.tryParse(match);
}

/// Splits into alternating digit/non-digit runs so "WO-9" sorts before
/// "WO-10" - matches the reference's `localeCompare(..., { numeric: true })`.
int _naturalCompare(String a, String b) {
  final tokens = RegExp(r'\d+|\D+');
  final partsA = tokens.allMatches(a).map((m) => m.group(0)!).toList();
  final partsB = tokens.allMatches(b).map((m) => m.group(0)!).toList();
  final len = partsA.length < partsB.length ? partsA.length : partsB.length;
  for (var i = 0; i < len; i++) {
    final na = int.tryParse(partsA[i]);
    final nb = int.tryParse(partsB[i]);
    final cmp = (na != null && nb != null) ? na.compareTo(nb) : partsA[i].compareTo(partsB[i]);
    if (cmp != 0) return cmp;
  }
  return partsA.length.compareTo(partsB.length);
}

/// Compares two rows on [field]. Blanks (null/empty) always sort last,
/// regardless of [ascending] - matching the reference comparator exactly.
int compareBammWorkOrders(BammWorkOrder a, BammWorkOrder b, String field, {bool ascending = true}) {
  final type = sortTypeForField(field);
  final rawA = _rawValue(a, field);
  final rawB = _rawValue(b, field);

  int cmp;
  bool aEmpty;
  bool bEmpty;
  switch (type) {
    case BammSortType.numeric:
      final na = _numOf(rawA);
      final nb = _numOf(rawB);
      aEmpty = na == null;
      bEmpty = nb == null;
      cmp = (aEmpty || bEmpty) ? 0 : na.compareTo(nb);
      break;
    case BammSortType.date:
      final da = rawA as DateTime?;
      final db = rawB as DateTime?;
      aEmpty = da == null;
      bEmpty = db == null;
      cmp = (aEmpty || bEmpty) ? 0 : da.compareTo(db);
      break;
    case BammSortType.text:
      final ta = (rawA?.toString().trim().isEmpty ?? true) ? null : rawA.toString().trim();
      final tb = (rawB?.toString().trim().isEmpty ?? true) ? null : rawB.toString().trim();
      aEmpty = ta == null;
      bEmpty = tb == null;
      cmp = (aEmpty || bEmpty) ? 0 : _naturalCompare(ta, tb);
      break;
  }

  if (aEmpty && bEmpty) return 0;
  if (aEmpty) return 1;
  if (bEmpty) return -1;
  return ascending ? cmp : -cmp;
}

/// Sorts a copy of [rows] by [field] ([ascending]); returns [rows] unchanged
/// (same order) when [field] is null.
List<BammWorkOrder> sortBammWorkOrders(List<BammWorkOrder> rows, String? field, bool ascending) {
  if (field == null) return rows;
  final sorted = List<BammWorkOrder>.from(rows);
  sorted.sort((a, b) => compareBammWorkOrders(a, b, field, ascending: ascending));
  return sorted;
}
