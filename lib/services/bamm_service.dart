import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../bamm/bamm_config.dart';
import '../bamm/mutations/fields.dart';
import '../bamm/mutations/model_ops.dart' show childItems;
import '../bamm/mutations/writer.dart';
import '../bamm/queries/asset_tree.dart';
import '../bamm/queries/list_query.dart';
import '../bamm/schema/lookups.dart';
import '../bamm/src/json_helpers.dart';
import '../bamm/transport/http_transport.dart';
import '../models/bamm_models.dart';
import 'bamm_adapter.dart';
import 'bamm_sort.dart';

/// The honest result of [BammService.updateWorkOrder]: the work order as
/// BAMM's own read-back returned it, plus the per-field verdict for exactly
/// what was sent. Callers must not report success without checking
/// [writeResult].
class BammUpdateOutcome {
  final BammWorkOrder workOrder;
  final BammWriteResult writeResult;
  const BammUpdateOutcome({required this.workOrder, required this.writeResult});
}

/// The honest result of [BammService.addActivityLine]: whether the
/// `WO_DETAIL` count actually grew after `Save` + read-back, not merely
/// whether the HTTP calls returned 200 - the same "don't trust a 200,
/// re-read and compare" discipline as [BammUpdateOutcome].
class BammAddActivityLineOutcome {
  final BammWorkOrder workOrder;
  final bool added;
  const BammAddActivityLineOutcome({required this.workOrder, required this.added});
}

/// App-facing BAMM service: owns persisted app state (connection config,
/// saved filters) and the network reachability probe, and translates between
/// this app's view models (`BammWorkOrder`, `BammFilterCriteria`, ...) and
/// the modular BAMM protocol layer in `lib/bamm/`, which owns login,
/// request/payload shape, and DynamicDTO handling.
///
/// Deliberately live-only: a failed or unreachable fetch is reported as a
/// failure to the caller. There is no local cache of work-order data to fall
/// back to - a cache decorator with a visible timestamp is a later batch.
class BammService {
  static const String _filtersFileName = 'jokarz_bamm_filters.json';
  static const String _configFileName = 'jokarz_bamm_config.json';
  static const String _columnLayoutFileName = 'jokarz_bamm_columns.json';

  BammConnectionConfig _config = const BammConnectionConfig();
  BammHttpTransport _transport = BammHttpTransport(_toBammConfig(const BammConnectionConfig()));

  BammConnectionConfig get config => _config;

  /// Replacing the config also replaces the transport (and with it, any
  /// cached tokens): a token issued for one host/user must never be reused
  /// against another after the user repoints the app at a different BAMM.
  set config(BammConnectionConfig value) {
    _config = value;
    _transport.close();
    _transport = BammHttpTransport(_toBammConfig(value));
  }

  BammConfig get _bammConfig => _transport.config;

  static BammConfig _toBammConfig(BammConnectionConfig config) => BammConfig(
        origin: config.origin,
        usercode: config.usercode,
        password: config.password,
        companyId: config.companyId,
        spwId: config.spwId,
        loginTimeout: const Duration(seconds: 6),
        apiTimeout: const Duration(seconds: 12),
      );

  bool isOnline = false;
  bool isPolling = false;
  DateTime? lastChecked;

  /// The server-reported `total` from the most recent `GetListData` call -
  /// `null` until a query has run. `BammListQueryClient.fetch` already parses
  /// this; surfacing it here is what lets the UI show "showing N of total"
  /// instead of silently truncating at `topCount` (2000).
  int? lastQueryTotal;

  final http.Client _client = http.Client();

  /// Fast network poll to determine if BAMM is reachable on the current network.
  /// Uses a short 1500ms timeout so the UI remains completely responsive.
  Future<bool> quickPollNetwork({String? targetOrigin}) async {
    isPolling = true;
    final origin = (targetOrigin ?? config.origin).trim().replaceAll(RegExp(r'/+$'), '');
    bool reachable = false;

    try {
      final uri = Uri.parse(origin);
      final host = uri.host;
      final port = uri.port > 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);

      // 1. First probe TCP socket directly with a 1.5s timeout.
      final socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 1500));
      socket.destroy();
      reachable = true;
    } catch (e) {
      // 2. If direct socket connect has issues or platform restricts, try a light HTTP GET probe
      try {
        final probeUri = Uri.parse('$origin/api/login/FinalizeLogInWeb');
        final response = await _client.get(probeUri).timeout(const Duration(milliseconds: 1500));
        // Any HTTP response (even 400, 401, 405 Method Not Allowed) proves the server is online and reached!
        reachable = response.statusCode > 0;
      } catch (_) {
        reachable = false;
      }
    }

    isOnline = reachable;
    lastChecked = DateTime.now();
    isPolling = false;
    return isOnline;
  }

  // ---------------------------------------------------------------------------
  // Work Order List Fetching
  // ---------------------------------------------------------------------------

  /// Fetches Work Orders from BAMM with server-side sorting and filtering.
  /// Live-only: an unreachable server or a failed request is reported to the
  /// caller as a failure, never masked by stale local data. Zero dummy data
  /// is generated.
  ///
  /// [statusLookups]/[stepLookups] are the live-fetched `GetWorkOrderStatus`/
  /// `GetWorkOrderStep` option lists (`BammState.statusLookups`/
  /// `stepLookups`) - passed through to resolve a filter's status/step id
  /// from the real live data rather than a short hardcoded guess (see
  /// [_lookupStatusId]/[_lookupStepId]).
  Future<List<BammWorkOrder>> fetchWorkOrders({
    BammFilterCriteria? criteria,
    Map<String, dynamic>? customPayload,
    bool forceOffline = false,
    List<BammLookupItem> statusLookups = const [],
    List<BammLookupItem> stepLookups = const [],
  }) async {
    if (forceOffline) return const [];

    final online = await quickPollNetwork();
    if (!online) {
      throw HttpException(
        'BAMM is unreachable at ${config.origin}. Please ensure device is connected to the plant Wi-Fi / VPN.',
      );
    }

    if (customPayload != null) {
      final raw = await _transport.post(
        '/api/WorkOrderList/GetListData',
        jsonBody: customPayload,
        referer: '/workorder/list/work-order/${_bammConfig.listScreenId}',
        operation: 'Work order list',
      );
      final rows = (raw is Map && raw['value'] is List) ? raw['value'] as List : const [];
      lastQueryTotal = (raw is Map) ? asInt(raw['total']) : null;
      return rows.whereType<Map<String, dynamic>>().map(bammWorkOrderFromListRow).toList();
    }

    final effectiveCriteria = criteria ?? const BammFilterCriteria();
    final request = _buildListQueryRequest(effectiveCriteria, statusLookups: statusLookups, stepLookups: stepLookups);
    final result = await BammListQueryClient(_transport, _bammConfig).fetch(request);
    lastQueryTotal = result.total;
    final mapped = result.rows.map(bammWorkOrderFromListRow).toList();

    // The real server ignores `orderByFields` (see BAMM/captures/*.har for
    // WorkOrderOpenOnAssetList) - sort the returned page locally, same as
    // the reference web app's header click. Falls back to the same default
    // sent on the wire (woIssueDate desc) when no explicit sort is set.
    final sortField = effectiveCriteria.sortField ?? 'woIssueDate';
    final sortAscending = effectiveCriteria.sortField == null ? false : effectiveCriteria.sortAscending;
    return sortBammWorkOrders(mapped, sortField, sortAscending);
  }

  /// Builds a GuideTi filter payload for server-side execution across 196k+ work orders.
  Map<String, dynamic> buildFilterPayload(
    BammFilterCriteria criteria, {
    List<BammLookupItem> statusLookups = const [],
    List<BammLookupItem> stepLookups = const [],
  }) =>
      _buildListQueryRequest(criteria, statusLookups: statusLookups, stepLookups: stepLookups).toJson();

  ListQueryRequest _buildListQueryRequest(
    BammFilterCriteria criteria, {
    List<BammLookupItem> statusLookups = const [],
    List<BammLookupItem> stepLookups = const [],
  }) {
    final filters = <ListFilter>[];

    // Status filter:
    // If empty/null/All Open -> filter by open work orders (exclude completed, declined, closed, cancelled)
    // If specific status -> filter by that single status
    // If 'All' or 'All (Including Closed)' -> do not filter by status
    final statusStr = criteria.status?.trim() ?? '';
    final isAllInclusive = statusStr.toLowerCase() == 'all' ||
        statusStr.toLowerCase() == 'all (including closed)' ||
        statusStr.toLowerCase() == 'all_inclusive';
    final isOpenDefault = statusStr.isEmpty ||
        statusStr.toLowerCase() == 'all open' ||
        statusStr.toLowerCase() == 'open';

    if (isOpenDefault) {
      filters.add(_openStatusFilter());
    } else if (!isAllInclusive) {
      final sId = criteria.statusId ?? _lookupStatusId(statusStr, statusLookups);
      filters.add(ListFilter.byList(
        searchFieldKey: 'woStatusId',
        sourceUrl: 'GetWorkOrderStatus',
        categoryDescription: 'WO parameters',
        options: [_optionMap(sId, statusStr)],
      ));
    }

    // Step filter (woStepId, filterType 3)
    if (criteria.step != null && criteria.step!.isNotEmpty && criteria.step != 'All') {
      final stId = criteria.stepId ?? _lookupStepId(criteria.step!, stepLookups);
      filters.add(ListFilter.byList(
        searchFieldKey: 'woStepId',
        filterType: 3,
        sourceUrl: 'GetWorkOrderStep',
        categoryDescription: 'WO parameters',
        options: [_optionMap(stId, criteria.step!)],
      ));
    }

    // Maintenance Type filter (maintenanceTypeId, filterType 8)
    if (criteria.maintenanceType != null &&
        criteria.maintenanceType!.isNotEmpty &&
        criteria.maintenanceType != 'All') {
      final mtId = criteria.maintenanceTypeId ?? _lookupMaintId(criteria.maintenanceType!);
      filters.add(ListFilter.byList(
        searchFieldKey: 'maintenanceTypeId',
        sourceUrl: 'GetMaintenanceType',
        categoryDescription: 'WO parameters',
        options: [_optionMap(mtId, criteria.maintenanceType!)],
      ));
    }

    // Area filter (regrouping1Id, filterType 8, sourceUrl: GetGrouping1)
    final areaVal = criteria.area?.trim();
    if (areaVal != null && areaVal.isNotEmpty && areaVal != 'All') {
      final aId = criteria.areaId ?? _lookupAreaId(areaVal);
      filters.add(ListFilter.byList(
        searchFieldKey: 'regrouping1Id',
        sourceUrl: 'GetGrouping1',
        categoryDescription: 'Asset parameters',
        options: [_optionMap(aId, areaVal)],
      ));
    }

    // Machine filter: 3rd level asset description (funCodeLevelNiv3Description, filterType 1)
    if (criteria.machine != null && criteria.machine!.trim().isNotEmpty) {
      filters.add(ListFilter.byText(searchFieldKey: 'funCodeLevelNiv3Description', value: criteria.machine!.trim()));
    }

    // Assembly filter: 4th level asset description (funCodeLevelNiv4Description, filterType 1)
    if (criteria.assembly != null && criteria.assembly!.trim().isNotEmpty) {
      filters.add(ListFilter.byText(searchFieldKey: 'funCodeLevelNiv4Description', value: criteria.assembly!.trim()));
    }

    // Function code level 2 filter: 2nd level asset description (funCodeLevelNiv2Description, filterType 1)
    if (criteria.level2 != null && criteria.level2!.trim().isNotEmpty) {
      filters.add(ListFilter.byText(searchFieldKey: 'funCodeLevelNiv2Description', value: criteria.level2!.trim()));
    }

    // Responsible (recipientName, filterType 1)
    if (criteria.responsible != null && criteria.responsible!.trim().isNotEmpty) {
      filters.add(ListFilter.byText(searchFieldKey: 'recipientName', value: criteria.responsible!.trim()));
    }

    // Requester (requesterName, filterType 1)
    if (criteria.requester != null && criteria.requester!.trim().isNotEmpty) {
      filters.add(ListFilter.byText(searchFieldKey: 'requesterName', value: criteria.requester!.trim()));
    }

    // Machine Status / Execution Mode (executionModeId, filterType 8)
    if (criteria.executionMode != null &&
        criteria.executionMode!.isNotEmpty &&
        criteria.executionMode != 'All') {
      final emId = criteria.executionModeId ?? _lookupExecutionModeId(criteria.executionMode!);
      filters.add(ListFilter.byList(
        searchFieldKey: 'executionModeId',
        sourceUrl: 'GetExecutionMode',
        options: [_optionMap(emId, criteria.executionMode!)],
      ));
    }

    // Text Search / WO Number Search
    if (criteria.searchQuery.trim().isNotEmpty) {
      final q = criteria.searchQuery.trim();
      final isWoNumber = RegExp(r'^(wo-)?\d+(\.\d+)?$', caseSensitive: false).hasMatch(q);
      filters.add(ListFilter.byText(searchFieldKey: isWoNumber ? 'worNoSeq' : 'woDescription', value: q));
    }

    return ListQueryRequest(
      fields: _majorColumns,
      orderByFields: [
        ListOrderBy(criteria.sortField ?? 'woIssueDate', ascending: criteria.sortField == null ? false : criteria.sortAscending),
      ],
      filters: filters,
      topCount: 2000,
    );
  }

  /// The single-value `listValues` entry GuideTi expects for a resolved id/description pair.
  Map<String, dynamic> _optionMap(int id, String description) =>
      {'id': id, 'value': 0, 'description': description, 'code': '', 'type': null, 'inactive': false};

  /// Builds the standard GuideTi filter block that restricts results to open/active work orders.
  /// Excludes completed (3), declined (5), closed (6), and cancelled (4).
  ListFilter _openStatusFilter() => ListFilter.byList(
        searchFieldKey: 'woStatusId',
        description: 'Statuses',
        sourceUrl: 'GetWorkOrderStatus',
        categoryDescription: 'WO parameters',
        options: const [
          {'id': 1, 'value': 0, 'description': 'In preparation', 'code': '', 'type': null, 'inactive': false},
          {'id': 2, 'value': 0, 'description': 'Scheduled', 'code': '', 'type': null, 'inactive': false},
          {'id': 7, 'value': 0, 'description': 'In estimate', 'code': '', 'type': null, 'inactive': false},
          {'id': 8, 'value': 0, 'description': 'Registered', 'code': '', 'type': null, 'inactive': false},
          {'id': 9, 'value': 0, 'description': 'Ready to schedule', 'code': '', 'type': null, 'inactive': false},
        ],
      );

  /// The major columns requested by GuideTi.
  static const List<ListColumn> _majorColumns = [
    ListColumn(key: 'workOrderId', header: 'ID', isVisible: false, fieldDataType: 4),
    ListColumn(key: 'worNoSeq', header: 'Work order', fieldDataType: 6),
    ListColumn(key: 'woIssueDate', header: 'WO registered date', fieldDataType: 5, format: 4),
    ListColumn(key: 'regrouping1Description', header: 'Area', fieldDataType: 15),
    ListColumn(key: 'funCodeLevelNiv1Description', header: '1st level - description', fieldDataType: 15),
    ListColumn(key: 'funCodeLevelNiv2Description', header: '2nd level - description', fieldDataType: 15),
    ListColumn(key: 'funCodeLevelNiv3Description', header: 'Machine', fieldDataType: 15),
    ListColumn(key: 'funCodeLevelNiv4Description', header: '4th level - description', fieldDataType: 15),
    ListColumn(key: 'recipientName', header: 'Responsible', fieldDataType: 15),
    ListColumn(key: 'requesterName', header: 'Requester', fieldDataType: 15),
    ListColumn(key: 'woTask', header: 'Work done', fieldDataType: 1),
    ListColumn(key: 'woDescription', header: 'WO description', fieldDataType: 1),
    ListColumn(key: 'woStatusDescription', header: 'Status', fieldDataType: 15),
    ListColumn(key: 'woStepDescription', header: 'Step', fieldDataType: 15),
    ListColumn(key: 'executionModeDescription', header: 'Machine Status', fieldDataType: 15),
    ListColumn(key: 'woRequiredDate', header: 'Required date', fieldDataType: 5, format: 4),
    ListColumn(key: 'worNumber3', header: 'EM Priority', fieldDataType: 3),
    ListColumn(key: 'worEstLaborTime', header: 'Labor Hours', fieldDataType: 3),
  ];

  // ---------------------------------------------------------------------------
  // Create Work Order
  // ---------------------------------------------------------------------------

  /// Creates a new Work Order on BAMM via `GetNew -> [asset steps] -> apply
  /// fields -> Save -> read back` (`BammWorkOrderWriter.createWorkOrder`).
  /// `area`/`machine`/`responsible`/`laborHours` have no corresponding
  /// writable BAMM property reachable from this form, so - exactly as the
  /// previous implementation did - they are carried on the returned view
  /// model for display only, not sent to BAMM.
  Future<BammWorkOrder> createWorkOrder({
    required String description,
    String assetId = '',
    int maintenanceTypeId = 107, // Corrective by default
    int stepId = 1, // Normal/Emergency
    String priority = '1.0',
    DateTime? requiredDate,
    String responsible = '',
    String area = '',
    String machine = '',
    double? laborHours,
  }) async {
    final online = await quickPollNetwork();
    if (!online) {
      throw HttpException(
        'Cannot create work order while disconnected from BAMM (${config.origin}). '
        'Please ensure device is connected to the plant Wi-Fi / VPN.',
      );
    }

    final writer = BammWorkOrderWriter(_transport, _bammConfig);
    final fields = <String, Object?>{
      'WOR_DESCR': description,
      'MNT_ID': maintenanceTypeId,
      'WSP_ID': stepId,
      if (priority.isNotEmpty) 'WOR_NB_3': priority,
      if (requiredDate != null) 'WOR_REQUI_DATE': _dateOnly(requiredDate),
    };

    final result = await writer.createWorkOrder(
      fields: fields,
      assetId: assetId.isEmpty ? null : assetId,
    );

    final createdModel = result['model'] as Map<String, dynamic>?;
    final base = createdModel != null
        ? bammWorkOrderFromModel(createdModel)
        : BammWorkOrder(
            worId: int.tryParse(result['workOrderId']?.toString() ?? '') ?? 0,
            worNoSeq: result['workOrderNumber']?.toString() ?? '',
            description: description,
          );

    return base.copyWith(
      area: area,
      machine: machine,
      assetId: assetId,
      responsible: responsible,
      laborHours: laborHours,
    );
  }

  // ---------------------------------------------------------------------------
  // Edit Work Order
  // ---------------------------------------------------------------------------

  /// Updates an existing Work Order through the six-field write whitelist
  /// (`WhitelistedFieldWriter`): lock -> save -> read back. The returned
  /// [BammUpdateOutcome.writeResult] is the read-back verdict for every field
  /// that was actually sent - a 2xx from Save is never treated as proof on
  /// its own. `status`/`step`/`priority`/`area`/`machine`/`laborHours` are
  /// not on the whitelist and are never sent; [BammUpdateOutcome.workOrder]
  /// reflects only what BAMM's own read-back returned, never a local guess,
  /// so the UI cannot show an edit as saved when it was not.
  Future<BammUpdateOutcome> updateWorkOrder({
    required int worId,
    required String description,
    String? workDone,
    String? responsible,
    DateTime? requiredDate,
    DateTime? installStart,
    DateTime? installEnd,
    String? classificationId,
    String? skillId,
    String? classificationTableId,
    String? crewShiftId,
    int? requiredEmployees,
    String? stepId,
    String? maintenanceTypeId,
    String? executionModeId,
    double? priorityEm,
    String? assetId,
    double? estimatedLaborHours,
    String? statusId,
  }) async {
    final online = await quickPollNetwork();
    if (!online || worId <= 0) {
      throw HttpException(
        'Cannot update work order #$worId while disconnected from BAMM (${config.origin}). '
        'Please ensure device is connected to the plant Wi-Fi / VPN.',
      );
    }

    final writer = BammWorkOrderWriter(_transport, _bammConfig);
    final edits = <BammFieldEdit>[
      BammFieldEdit(BammWritableField.description, description),
      if (workDone != null) BammFieldEdit(BammWritableField.workDone, workDone),
      if (responsible != null) BammFieldEdit(BammWritableField.responsible, responsible),
      if (requiredDate != null) BammFieldEdit(BammWritableField.requiredDate, _dateOnly(requiredDate)),
      if (installStart != null) BammFieldEdit(BammWritableField.installStart, _dateOnly(installStart)),
      if (installEnd != null) BammFieldEdit(BammWritableField.installEnd, _dateOnly(installEnd)),
      if (classificationId != null) BammFieldEdit(BammWritableField.classification, classificationId),
      if (skillId != null) BammFieldEdit(BammWritableField.skill, skillId),
      if (classificationTableId != null) BammFieldEdit(BammWritableField.classificationTable, classificationTableId),
      if (crewShiftId != null) BammFieldEdit(BammWritableField.crewShift, crewShiftId),
      if (requiredEmployees != null) BammFieldEdit(BammWritableField.requiredEmployees, requiredEmployees.toString()),
      if (stepId != null) BammFieldEdit(BammWritableField.step, stepId),
      if (maintenanceTypeId != null) BammFieldEdit(BammWritableField.maintenanceType, maintenanceTypeId),
      if (executionModeId != null) BammFieldEdit(BammWritableField.executionMode, executionModeId),
      if (priorityEm != null) BammFieldEdit(BammWritableField.priorityEm, priorityEm.toString()),
      if (assetId != null) BammFieldEdit(BammWritableField.asset, assetId),
      if (estimatedLaborHours != null) BammFieldEdit(BammWritableField.estimatedLaborHours, estimatedLaborHours.toString()),
      if (statusId != null) BammFieldEdit(BammWritableField.status, statusId),
    ];

    final writeResult = await WhitelistedFieldWriter(writer).write(worId, edits);
    final refreshed = await writer.getById(worId);

    return BammUpdateOutcome(workOrder: bammWorkOrderFromModel(refreshed), writeResult: writeResult);
  }

  /// Adds one `WO_DETAIL` activity line to an existing work order:
  /// `GetById -> Lock -> AddActivityLine(model) -> Save -> read-back`.
  /// Display + add only, per the batch's scope (no edit/delete of existing
  /// lines). [activityId]/[subActivityId] are required by BAMM
  /// (`~/repos/BAMM/docs/10-lookups-and-activity-lines.md`); the rest are
  /// optional line detail. [BammAddActivityLineOutcome.added] is computed by
  /// comparing the `WO_DETAIL` count before and after the read-back, not by
  /// trusting a 200 from `Save` - the same discipline as [updateWorkOrder].
  Future<BammAddActivityLineOutcome> addActivityLine({
    required int worId,
    required String activityId,
    required String subActivityId,
    String? description,
    double? hours,
    String? memo,
  }) async {
    final online = await quickPollNetwork();
    if (!online || worId <= 0) {
      throw HttpException(
        'Cannot add an activity line to work order #$worId while disconnected from BAMM (${config.origin}). '
        'Please ensure device is connected to the plant Wi-Fi / VPN.',
      );
    }
    if (activityId.trim().isEmpty || subActivityId.trim().isEmpty) {
      throw const FormatException('Activity and sub-activity are both required to add a line');
    }

    final writer = BammWorkOrderWriter(_transport, _bammConfig);
    final model = await writer.getById(worId);
    final before = childItems(model, 'WO_DETAIL').length;

    await writer.lockWorkOrder(worId);
    await writer.addActivityLine(model, fields: {
      'ACY_ID': activityId,
      'SAC_ID': subActivityId,
      if (description != null && description.trim().isNotEmpty) 'WOD_DESCR': description.trim(),
      if (hours != null) 'WOD_ACT_LINE_HOUR_NB': hours.toString(),
      if (memo != null && memo.trim().isNotEmpty) 'WOD_MEMO': memo.trim(),
    });
    await writer.save(model, worId);

    final refreshed = await writer.getById(worId);
    final after = childItems(refreshed, 'WO_DETAIL').length;
    return BammAddActivityLineOutcome(workOrder: bammWorkOrderFromModel(refreshed), added: after > before);
  }

  /// Direct access to the live lookup client for callers (searchable
  /// pickers) that need the raw [LookupOption]/[LookupResult] shape - total
  /// count, `inactive`, `code` - rather than [fetchLookup]'s simplified,
  /// offline-fallback-capable [BammLookupItem] list.
  BammLookupsClient get lookups => BammLookupsClient(_transport, _bammConfig);

  /// Direct access to the live 5-level asset-tree client for the machine
  /// picker (`bamm_asset_tree_picker.dart`) - one level per call, never a
  /// bundled/cached tree.
  BammAssetTreeClient get assetTree => BammAssetTreeClient(_transport, _bammConfig);

  /// Fetches complete Work Order detail on demand from BAMM using GetById.
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async {
    if (worId <= 0) return null;
    final online = await quickPollNetwork();
    if (!online) return null;

    try {
      final writer = BammWorkOrderWriter(_transport, _bammConfig);
      final model = await writer.getById(worId);
      return bammWorkOrderFromModel(model);
    } catch (e) {
      debugPrint('Error fetching BAMM work order detail for $worId: $e');
      return null;
    }
  }

  static String _dateOnly(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Fetches lookup options dynamically from BAMM WorkOrderLookup endpoints.
  Future<List<BammLookupItem>> fetchLookup(String method, {String search = ''}) async {
    final online = await quickPollNetwork();
    if (online) {
      try {
        final lookups = BammLookupsClient(_transport, _bammConfig);
        final extraParams = <String, String>{
          if (method == 'GetWorkOrderStep') 'showSecondaryStep': 'false',
          if (search.isNotEmpty) 'search': search,
          if (search.isNotEmpty) 'searchColumns': 'description',
        };
        final result = await lookups.fetch(method, extraParams: extraParams.isEmpty ? null : extraParams);
        final items = bammLookupItemsFromOptions(result.items);
        if (items.isNotEmpty) return items;
      } catch (e) {
        debugPrint('Error fetching BAMM lookup $method: $e');
      }
    }

    // Fallback standard options from GuideTi dictionary when offline
    return _getStandardFallbackLookup(method);
  }

  // ---------------------------------------------------------------------------
  // Lookup Id Resolvers & Defaults
  // ---------------------------------------------------------------------------

  /// Resolves a status description to its BAMM id, preferring the live
  /// `GetWorkOrderStatus` lookup ([liveLookups]) over the offline dictionary
  /// - falling back to id 1 only when neither has a match, rather than the
  /// old short hardcoded keyword list that silently returned 1 (In
  /// preparation) for anything it didn't recognise.
  int _lookupStatusId(String status, List<BammLookupItem> liveLookups) =>
      _resolveIdFromLookups(status, liveLookups) ??
      _resolveIdFromLookups(status, _getStandardFallbackLookup('GetWorkOrderStatus')) ??
      1;

  /// Same as [_lookupStatusId] for the step (`WSP_ID`) filter.
  int _lookupStepId(String step, List<BammLookupItem> liveLookups) =>
      _resolveIdFromLookups(step, liveLookups) ??
      _resolveIdFromLookups(step, _getStandardFallbackLookup('GetWorkOrderStep')) ??
      1;

  int? _resolveIdFromLookups(String description, List<BammLookupItem> lookups) {
    final d = description.trim().toLowerCase();
    if (d.isEmpty) return null;
    for (final item in lookups) {
      if (item.description.toLowerCase().trim() == d) return _asLookupId(item.id);
    }
    for (final item in lookups) {
      final id = item.description.toLowerCase().contains(d) || d.contains(item.description.toLowerCase())
          ? _asLookupId(item.id)
          : null;
      if (id != null) return id;
    }
    return null;
  }

  int? _asLookupId(dynamic id) => id is int ? id : int.tryParse(id?.toString() ?? '');

  int _lookupMaintId(String maint) {
    final m = maint.trim().toLowerCase();
    final items = _getStandardFallbackLookup('GetMaintenanceType');
    for (final item in items) {
      if (item.description.toLowerCase().trim() == m) {
        return item.id;
      }
    }
    for (final item in items) {
      if (item.description.toLowerCase().contains(m) || m.contains(item.description.toLowerCase())) {
        return item.id;
      }
    }
    return 111;
  }

  int _lookupAreaId(String area) {
    final a = area.trim().toLowerCase();
    final items = _getStandardFallbackLookup('GetGrouping1');
    for (final item in items) {
      if (item.description.toLowerCase().trim() == a) {
        return item.id;
      }
    }
    for (final item in items) {
      if (item.description.toLowerCase().contains(a) || a.contains(item.description.toLowerCase())) {
        return item.id;
      }
    }
    return 700000000;
  }

  int _lookupExecutionModeId(String mode) {
    final m = mode.trim().toLowerCase();
    if (m.contains('down')) return 1; // Down
    if (m.contains('limp')) return 2; // Limping
    if (m.contains('run')) return 3; // Running
    return 1;
  }

  List<BammLookupItem> _getStandardFallbackLookup(String method) {
    switch (method) {
      case 'GetWorkOrderStatus':
        return const [
          BammLookupItem(id: 1, description: 'In preparation'),
          BammLookupItem(id: 2, description: 'Scheduled'),
          BammLookupItem(id: 9, description: 'Ready to schedule'),
          BammLookupItem(id: 7, description: 'In estimate'),
          BammLookupItem(id: 8, description: 'Registered'),
          BammLookupItem(id: 3, description: 'Completed'),
          BammLookupItem(id: 6, description: 'Closed'),
          BammLookupItem(id: 4, description: 'Cancelled'),
          BammLookupItem(id: 5, description: 'Declined'),
        ];
      case 'GetWorkOrderStep':
        return const [
          BammLookupItem(id: 2, description: 'Countermeasure'),
          BammLookupItem(id: 700000007, description: 'Defect Handling'),
          BammLookupItem(id: 3, description: 'Emergency'),
          BammLookupItem(id: 4, description: 'Follow-up'),
          BammLookupItem(id: 5, description: 'Planned Work'),
        ];
      case 'GetMaintenanceType':
        return const [
          BammLookupItem(id: 700000004, description: '3m/ Active Trial'),
          BammLookupItem(id: 103, description: 'Administrative (Training, Meeting, General)'),
          BammLookupItem(id: 700000019, description: 'Defect '),
          BammLookupItem(id: 700000021, description: 'Defect - Quality #5'),
          BammLookupItem(id: 700000020, description: 'Defect - Safety #7'),
          BammLookupItem(id: 105, description: 'Emergency'),
          BammLookupItem(id: 118, description: 'Emergency - Assist'),
          BammLookupItem(id: 117, description: 'Emergency - Pitstop'),
          BammLookupItem(id: 106, description: 'Fabrication / Machining'),
          BammLookupItem(id: 700000010, description: 'Floating activity found during PM'),
          BammLookupItem(id: 700000011, description: 'Follow Up - Investigate (IPS,UPS or IDA)'),
          BammLookupItem(id: 700000005, description: 'Follow Up - Order Parts'),
          BammLookupItem(id: 700000008, description: 'Follow Up - Take/Send Oill Sample for Analysis'),
          BammLookupItem(id: 114, description: 'Periodic Maintenance'),
          BammLookupItem(id: 110, description: 'Planned - Audit Follow-up Task'),
          BammLookupItem(id: 116, description: 'Planned - Calibration / Accuracy Checks'),
          BammLookupItem(id: 111, description: 'Planned - Corrective Maint.'),
          BammLookupItem(id: 107, description: 'Planned - Kaizen '),
          BammLookupItem(id: 108, description: 'Planned - Modification / Upgrade'),
          BammLookupItem(id: 113, description: 'Planned - Predictive Maint.'),
          BammLookupItem(id: 115, description: 'Planned - Size Change / Setup'),
          BammLookupItem(id: 700000014, description: 'Planned - Thermography Action'),
          BammLookupItem(id: 700000013, description: 'Planned - Vibration/MCE Action'),
          BammLookupItem(id: 700000002, description: 'Shutdown Item'),
          BammLookupItem(id: 112, description: 'x_Planned - MEMO Task'),
        ];
      case 'GetGrouping1':
        return const [
          BammLookupItem(id: 700000000, description: '100'),
          BammLookupItem(id: 700000001, description: '150'),
          BammLookupItem(id: 700000002, description: '200'),
          BammLookupItem(id: 700000003, description: '300'),
          BammLookupItem(id: 700000004, description: '350'),
          BammLookupItem(id: 700000005, description: '400'),
          BammLookupItem(id: 700000014, description: '500'),
          BammLookupItem(id: 700000006, description: '700'),
          BammLookupItem(id: 700000008, description: '720'),
          BammLookupItem(id: 700000009, description: '736'),
          BammLookupItem(id: 700000010, description: '900'),
          BammLookupItem(id: 700000011, description: '930'),
          BammLookupItem(id: 700000012, description: 'Carts'),
          BammLookupItem(id: 700000015, description: 'Cell 1'),
          BammLookupItem(id: 700000013, description: 'Mobile Power'),
        ];
      case 'GetExecutionMode':
        return const [
          BammLookupItem(id: 1, description: 'Down', code: '2.00'),
          BammLookupItem(id: 2, description: 'Limping', code: '1.50'),
          BammLookupItem(id: 3, description: 'Running', code: '1.00'),
        ];
      case 'GetDepartment':
        return const [
          BammLookupItem(id: 700000001, description: 'CG1 (831)'),
          BammLookupItem(id: 700000002, description: 'EG1 (MX)'),
          BammLookupItem(id: 700000003, description: 'EG2 (EX/CL)'),
          BammLookupItem(id: 700000024, description: 'EG3 (SP)'),
          BammLookupItem(id: 700000025, description: 'EG4 (TA)'),
          BammLookupItem(id: 700000026, description: 'EG5 (FL/CR/FL)'),
          BammLookupItem(id: 700000022, description: 'MSG1 (MX)'),
          BammLookupItem(id: 700000009, description: 'MSG2 (EX/CL)'),
          BammLookupItem(id: 700000023, description: 'MSG3 (SP)'),
          BammLookupItem(id: 700000010, description: 'MSG4 (TA)'),
          BammLookupItem(id: 700000011, description: 'MSG5 (FL/CR/FL)'),
          BammLookupItem(id: 1, description: 'Line 1'),
          BammLookupItem(id: 2, description: 'Line 2'),
          BammLookupItem(id: 3, description: 'Line 3'),
          BammLookupItem(id: 4, description: 'Line 4'),
          BammLookupItem(id: 5, description: 'Line 5'),
        ];
      default:
        return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Local File & Storage Utilities (persisted app state - not live BAMM data)
  // ---------------------------------------------------------------------------

  Future<File> _getFile(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<void> _atomicWrite(File file, String content) async {
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(content);
    await tempFile.rename(file.path);
  }

  Future<List<BammSavedFilter>> loadSavedFilters() async {
    try {
      final file = await _getFile(_filtersFileName);
      if (!await file.exists()) {
        final defaults = _getDefaultSavedFilters();
        await saveSavedFilters(defaults);
        return defaults;
      }
      final text = await file.readAsString();
      if (text.trim().isEmpty) return _getDefaultSavedFilters();
      final list = jsonDecode(text) as List<dynamic>;
      return list.map((e) => BammSavedFilter.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading BAMM saved filters: $e');
      return _getDefaultSavedFilters();
    }
  }

  Future<void> saveSavedFilters(List<BammSavedFilter> filters) async {
    try {
      final file = await _getFile(_filtersFileName);
      final jsonStr = jsonEncode(filters.map((f) => f.toJson()).toList());
      await _atomicWrite(file, jsonStr);
    } catch (e) {
      debugPrint('Error saving BAMM filters: $e');
    }
  }

  /// The user's BAMM table column order/visibility, or an empty layout
  /// (caller falls back to defaults) if nothing has been saved yet.
  Future<BammColumnLayout> loadColumnLayout() async {
    try {
      final file = await _getFile(_columnLayoutFileName);
      if (!await file.exists()) return const BammColumnLayout();
      final text = await file.readAsString();
      if (text.trim().isEmpty) return const BammColumnLayout();
      return BammColumnLayout.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error loading BAMM column layout: $e');
      return const BammColumnLayout();
    }
  }

  Future<void> saveColumnLayout(BammColumnLayout layout) async {
    try {
      final file = await _getFile(_columnLayoutFileName);
      await _atomicWrite(file, jsonEncode(layout.toJson()));
    } catch (e) {
      debugPrint('Error saving BAMM column layout: $e');
    }
  }

  Future<BammConnectionConfig> loadConfig() async {
    try {
      final file = await _getFile(_configFileName);
      if (!await file.exists()) return const BammConnectionConfig();
      final text = await file.readAsString();
      if (text.trim().isEmpty) return const BammConnectionConfig();
      final json = jsonDecode(text) as Map<String, dynamic>;
      config = BammConnectionConfig.fromJson(json);
      return config;
    } catch (e) {
      debugPrint('Error loading BAMM config: $e');
      return const BammConnectionConfig();
    }
  }

  Future<void> saveConfig(BammConnectionConfig newConfig) async {
    try {
      config = newConfig;
      final file = await _getFile(_configFileName);
      await _atomicWrite(file, jsonEncode(newConfig.toJson()));
    } catch (e) {
      debugPrint('Error saving BAMM config: $e');
    }
  }

  List<BammSavedFilter> _getDefaultSavedFilters() {
    return const [
      BammSavedFilter(id: 'filter_prep', name: 'In Preparation', status: 'In preparation', statusId: 1),
      BammSavedFilter(id: 'filter_scheduled', name: 'Scheduled', status: 'Scheduled', statusId: 2),
      BammSavedFilter(id: 'filter_emergency', name: 'Emergency', step: 'Emergency', stepId: 3),
      BammSavedFilter(id: 'filter_planned', name: 'Planned Work', step: 'Planned Work', stepId: 5),
    ];
  }
}
