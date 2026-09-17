/// Client-side "search everything already loaded" for the BAMM table - a
/// separate, purely local mode from the server-side search
/// (`BammFilterCriteria.searchQuery`), which only ever matches `woDescription`
/// or `worNoSeq` (see `BammService._buildListQueryRequest`). This one joins
/// every column's text - including columns the user has hidden - into one
/// blob per row and matches multiple whitespace-separated tokens with AND,
/// case-insensitively, against rows already sitting in memory. No network
/// call is ever made here.
library;

import 'package:intl/intl.dart';

import '../models/bamm_models.dart';

final DateFormat _displayDate = DateFormat('MMM d, y');
final DateFormat _monthFull = DateFormat('MMMM');
final DateFormat _monthShort = DateFormat('MMM');

/// Every spoken/displayed form of [date] a user might type: the form shown
/// in the table ("Sep 17, 2026"), short numeric forms ("9/17/26",
/// "9/17/2026"), the month name in full and abbreviated ("September",
/// "Sep"), and a dashed month-day form ("09-17") - the exact set the batch
/// brief calls out.
List<String> _dateTokens(DateTime? date) {
  if (date == null) return const [];
  final twoDigitYear = (date.year % 100).toString().padLeft(2, '0');
  final month2 = date.month.toString().padLeft(2, '0');
  final day2 = date.day.toString().padLeft(2, '0');
  return [
    _displayDate.format(date),
    '${date.month}/${date.day}/$twoDigitYear',
    '${date.month}/${date.day}/${date.year}',
    _monthFull.format(date),
    _monthShort.format(date),
    '$month2-$day2',
  ];
}

/// Every field on [wo] - including columns not currently shown in the table
/// - joined into one lowercase blob for token matching.
String bammLocalSearchBlob(BammWorkOrder wo) {
  final parts = <String>[
    wo.worNoSeq,
    wo.description,
    wo.workDone,
    wo.status,
    wo.step,
    wo.area,
    wo.machine,
    wo.assembly,
    wo.assetId,
    wo.priority,
    wo.responsible,
    wo.requester,
    wo.executionMode,
    wo.maintenanceType,
    if (wo.laborHours != null) '${wo.laborHours}',
    if (wo.requiredEmployees != null) '${wo.requiredEmployees}',
    ..._dateTokens(wo.issueDate),
    ..._dateTokens(wo.requiredDate),
  ];
  return parts.join(' ').toLowerCase();
}

/// True when every whitespace-separated token in [query] (case-insensitive)
/// appears somewhere in [wo]'s combined field blob. An empty/blank [query]
/// matches everything.
bool matchesBammLocalSearch(BammWorkOrder wo, String query) {
  final tokens = query.trim().toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  if (tokens.isEmpty) return true;
  final blob = bammLocalSearchBlob(wo);
  return tokens.every(blob.contains);
}

/// Filters [rows] to those matching every token in [query] - see
/// [matchesBammLocalSearch]. Returns [rows] unchanged when [query] is blank.
List<BammWorkOrder> filterBammWorkOrdersLocally(List<BammWorkOrder> rows, String query) {
  if (query.trim().isEmpty) return rows;
  return rows.where((wo) => matchesBammLocalSearch(wo, query)).toList();
}
