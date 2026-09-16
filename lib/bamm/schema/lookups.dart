/// The `/api/WorkOrderLookup/*` family - option lists behind BAMM's dropdowns.
///
/// Modelled on `~/repos/BAMM/app/bamm/lookups.py::LookupService`. All of these
/// are POSTs with an empty body; everything travels in the query string. No
/// caching happens here - a cache decorator is added in a later phase.
library;

import '../bamm_config.dart';
import '../src/json_helpers.dart';
import '../transport/http_transport.dart';

class BammLookupsException implements Exception {
  final String message;
  const BammLookupsException(this.message);

  @override
  String toString() => message;
}

/// One normalised option row, e.g. from `GetWorkOrderStep` or `GetResponsible`.
class LookupOption {
  final String id;
  final String label;
  final String code;
  final dynamic type;
  final bool inactive;

  const LookupOption({
    required this.id,
    required this.label,
    required this.code,
    this.type,
    required this.inactive,
  });

  factory LookupOption.fromJson(Map<String, dynamic> json) {
    final identifier = json['id'] ?? json['value'];
    final label = json['description'] ?? json['code'] ?? identifier?.toString() ?? '';
    return LookupOption(
      id: identifier == null ? '' : identifier.toString(),
      label: label.toString().trim(),
      code: json['code']?.toString().trim() ?? '',
      type: json['type'],
      inactive: json['inactive'] as bool? ?? false,
    );
  }
}

/// The result of one lookup call, with the server's reported total alongside
/// what actually came back.
class LookupResult {
  final List<LookupOption> items;
  final int? total;

  const LookupResult({required this.items, required this.total});

  /// True when the server reports more rows exist than this page returned.
  /// BAMM caps some lists at a page size regardless of what is asked for
  /// (e.g. 200 of 377 sub-activities) and never sends the rest unasked -
  /// callers must surface that instead of presenting the list as complete.
  bool get isTruncated => total != null && total! > items.length;
}

class BammLookupsClient {
  final BammHttpTransport transport;
  final BammConfig config;

  static const int defaultPageSize = 200;

  const BammLookupsClient(this.transport, this.config);

  /// One lookup call: `POST /api/WorkOrderLookup/<endpoint>`.
  Future<LookupResult> fetch(
    String endpoint, {
    Map<String, String>? extraParams,
    String sortColumn = 'description',
    int pageSize = defaultPageSize,
  }) async {
    final params = {
      'querytype': 'top',
      'pageSize': pageSize.toString(),
      'companyId': config.companyId.toString(),
      'sortColumn': sortColumn,
      ...?extraParams,
    };

    final result = await transport.post(
      '/api/WorkOrderLookup/$endpoint',
      params: params,
      referer: '/',
      operation: 'Lookup $endpoint',
    );

    if (result is! Map) {
      throw BammLookupsException('Lookup $endpoint returned an unexpected shape');
    }
    final rows = result['value'];
    if (rows is! List) {
      throw BammLookupsException('Lookup $endpoint response has no value list');
    }

    final items = rows.whereType<Map<String, dynamic>>().map(LookupOption.fromJson).toList();
    return LookupResult(items: items, total: asInt(result['total']));
  }

  // -- context-free parameter lists, mirrored from LookupService ------------

  /// `WSP_ID` options - the required "step" field.
  Future<LookupResult> steps() =>
      fetch('GetWorkOrderStep', extraParams: {'showSecondaryStep': 'false'});

  /// `MNT_ID` options.
  Future<LookupResult> maintenanceTypes() => fetch('GetMaintenanceType');

  /// `CTG_ID` options.
  Future<LookupResult> categories() => fetch('GetWoCategory');

  /// `EXM_ID` options - the "machine status" list.
  Future<LookupResult> executionModes() => fetch('GetExecutionMode');

  /// `SKI_ID` options.
  Future<LookupResult> skills() => fetch('GetSkills');

  /// `PRI_ID` options.
  Future<LookupResult> priority() => fetch('GetPriority');

  /// `RCP_ID` options. `search` drives the type-ahead variant.
  Future<LookupResult> responsible({String? search}) => fetch(
        'GetResponsible',
        extraParams: (search != null && search.isNotEmpty)
            ? {'search': search, 'searchColumns': 'description'}
            : null,
      );

  /// `Model.Code` options (WO templates), optionally scoped to an asset.
  Future<LookupResult> models({String? assetId}) => fetch(
        'GetModel',
        extraParams: {
          'assetId': assetId ?? '',
          'componentId': '',
          'skillId': '',
          'onlyAllAsset': 'false',
          'forCreation': 'false',
        },
        sortColumn: 'code',
      );

  /// `WGM_ID` options for one grouping slot. `type` selects the slot
  /// (1 = cause category, 2 = in-prep reason, 3 = permits, ... - seen live).
  Future<LookupResult> groupings(int type) =>
      fetch('GetMultiGrouping', extraParams: {'type': type.toString()});

  /// `WG6_ID` options - "Classification Table".
  Future<LookupResult> classificationTables() => fetch('GetWorkOrderRegrouping6');

  /// `WG7_ID` options - "Crew/Shift".
  Future<LookupResult> crewShifts() => fetch('GetWorkOrderRegrouping7');

  /// `ACY_ID` options for an activity line - scoped by step + asset.
  Future<LookupResult> activities({String? stepId, String? assetId, String? componentTypeId}) => fetch(
        'GetActivities',
        extraParams: {
          'workOrderStepId': stepId ?? '',
          'assetId': assetId ?? '',
          'componentTypeId': componentTypeId ?? '',
        },
      );

  /// `SAC_ID` options for a chosen activity. BAMM caps this lookup at 200
  /// rows regardless of `pageSize` (377 total is a known real case) -
  /// [LookupResult.isTruncated] reports that instead of hiding it.
  Future<LookupResult> subActivities({
    required String activityId,
    String? assetId,
    String? componentTypeId,
  }) =>
      fetch(
        'GetSubActivities',
        extraParams: {
          'activityId': activityId,
          'assetId': assetId ?? '',
          'componentTypeId': componentTypeId ?? '',
        },
      );
}
