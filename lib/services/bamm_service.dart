import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../bamm/bamm_config.dart';
import '../bamm/mutations/fields.dart';
import '../bamm/mutations/writer.dart';
import '../bamm/queries/list_query.dart';
import '../bamm/schema/lookups.dart';
import '../bamm/transport/http_transport.dart';
import '../models/bamm_models.dart';
import 'bamm_adapter.dart';

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
  Future<List<BammWorkOrder>> fetchWorkOrders({
    BammFilterCriteria? criteria,
    Map<String, dynamic>? customPayload,
    bool forceOffline = false,
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
      return rows.whereType<Map<String, dynamic>>().map(bammWorkOrderFromListRow).toList();
    }

    final request = _buildListQueryRequest(criteria ?? const BammFilterCriteria());
    final result = await BammListQueryClient(_transport, _bammConfig).fetch(request);
    return result.rows.map(bammWorkOrderFromListRow).toList();
  }

  /// Builds a GuideTi filter payload for server-side execution across 196k+ work orders.
  Map<String, dynamic> buildFilterPayload(BammFilterCriteria criteria) => _buildListQueryRequest(criteria).toJson();

  ListQueryRequest _buildListQueryRequest(BammFilterCriteria criteria) {
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
      final sId = criteria.statusId ?? _lookupStatusId(statusStr);
      filters.add(ListFilter.byList(
        searchFieldKey: 'woStatusId',
        sourceUrl: 'GetWorkOrderStatus',
        categoryDescription: 'WO parameters',
        options: [_optionMap(sId, statusStr)],
      ));
    }

    // Step filter (woStepId, filterType 3)
    if (criteria.step != null && criteria.step!.isNotEmpty && criteria.step != 'All') {
      final stId = criteria.stepId ?? _lookupStepId(criteria.step!);
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
      orderByFields: const [ListOrderBy('woIssueDate', ascending: false)],
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
    ListColumn(key: 'funCodeLevelNiv3Description', header: 'Machine', fieldDataType: 15),
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
  /// (`WhitelistedFieldWriter`): lock -> save -> read back, with the read
  /// back proving whether the save actually took, rather than trusting a 2xx
  /// alone. Only `description` and `requiredDate` are on that whitelist;
  /// `status`/`step`/`priority`/`area`/`machine`/`responsible` are not
  /// BAMM-writable through this path (the previous implementation captured
  /// them for display only too - it built its save payload by hand and only
  /// ever actually sent `WOR_DESCR`, `WOR_NB_3`, and `WOR_REQUI_DATE`, of
  /// which `WOR_NB_3` (priority) is not one of the six whitelisted
  /// properties). They are still carried on the returned view model so the
  /// UI's optimistic display is unchanged.
  Future<BammWorkOrder> updateWorkOrder({
    required int worId,
    required String description,
    String? status,
    String? step,
    String? priority,
    DateTime? requiredDate,
    String? area,
    String? machine,
    String? responsible,
    double? laborHours,
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
      if (requiredDate != null) BammFieldEdit(BammWritableField.requiredDate, _dateOnly(requiredDate)),
    ];

    await WhitelistedFieldWriter(writer).write(worId, edits);
    final refreshed = await writer.getById(worId);

    return bammWorkOrderFromModel(refreshed).copyWith(
      status: status,
      step: step,
      priority: priority,
      area: area,
      machine: machine,
      responsible: responsible,
      laborHours: laborHours,
    );
  }

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

  int _lookupStatusId(String status) {
    final s = status.trim().toLowerCase();
    if (s.contains('prep')) return 1; // In preparation
    if (s.contains('schedul')) return 2; // Scheduled
    if (s.contains('ready')) return 9; // Ready to schedule
    if (s.contains('estimat')) return 7; // In estimate
    if (s.contains('regist')) return 8; // Registered
    if (s.contains('complet')) return 3; // Completed
    if (s.contains('close')) return 6; // Closed
    if (s.contains('cancel')) return 4; // Cancelled
    if (s.contains('declin')) return 5; // Declined
    return 1;
  }

  int _lookupStepId(String step) {
    final s = step.trim().toLowerCase();
    if (s.contains('counter')) return 2; // Countermeasure
    if (s.contains('defect')) return 700000007; // Defect Handling
    if (s.contains('emerg')) return 3; // Emergency
    if (s.contains('follow')) return 4; // Follow-up
    if (s.contains('plan')) return 5; // Planned Work
    return 1;
  }

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
