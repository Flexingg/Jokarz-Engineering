import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/bamm_models.dart';

class BammService {
  static const String _cacheFileName = 'jokarz_bamm_cache.json';
  static const String _filtersFileName = 'jokarz_bamm_filters.json';
  static const String _configFileName = 'jokarz_bamm_config.json';

  BammConnectionConfig config = const BammConnectionConfig();

  String? _accessToken;
  String? _sessionToken;
  DateTime? _tokenExpiresAt;

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

  /// Checks if authentication tokens are present and non-expired.
  bool get isAuthenticated {
    if (_accessToken == null || _sessionToken == null || _tokenExpiresAt == null) {
      return false;
    }
    return DateTime.now().isBefore(_tokenExpiresAt!);
  }

  /// Performs BAMM authentication: PUT /api/login/FinalizeLogInWeb
  Future<void> login() async {
    final origin = config.origin.trim().replaceAll(RegExp(r'/+$'), '');
    final url = Uri.parse('$origin/api/login/FinalizeLogInWeb');

    final payload = {
      'usercode': config.usercode,
      'password': config.password,
      'companyID': config.companyId,
    };

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Origin': origin,
      'Referer': '$origin/',
      'Cache-Control': 'no-cache',
    };

    final response = await _client
        .put(url, headers: headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 4));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final val = data['value'] as Map<String, dynamic>?;
      if (val != null) {
        final token = val['token']?.toString() ?? '';
        _accessToken = token.toLowerCase().startsWith('bearer ') ? token : 'Bearer $token';
        _sessionToken = val['sessionToken']?.toString() ?? '';
        _tokenExpiresAt = DateTime.now().add(const Duration(minutes: 50));
      }
    } else {
      throw HttpException('BAMM login failed with HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Builds the standard BAMM authenticated request headers.
  Map<String, String> _buildHeaders({
    required String refererPath,
    String contentType = 'application/json',
  }) {
    final origin = config.origin.trim().replaceAll(RegExp(r'/+$'), '');
    return {
      'Accept': 'application/json, text/plain, */*',
      'Content-Type': contentType,
      'Access-Token': _accessToken ?? '',
      'Session-Token': _sessionToken ?? '',
      'Origin': origin,
      'Referer': refererPath.startsWith('http') ? refererPath : '$origin$refererPath',
      'Cache-Control': 'no-cache',
    };
  }

  // ---------------------------------------------------------------------------
  // Work Order List Fetching & Caching
  // ---------------------------------------------------------------------------

  /// Fetches Work Orders from BAMM with server-side sorting and filtering,
  /// or falls back to local cache when offline. Zero dummy data is generated.
  Future<List<BammWorkOrder>> fetchWorkOrders({
    BammFilterCriteria? criteria,
    Map<String, dynamic>? customPayload,
    bool forceOffline = false,
  }) async {
    final bool hasCriteria = criteria != null && !criteria.isEmpty;
    final payload = customPayload ?? (hasCriteria ? buildFilterPayload(criteria) : _buildDefaultFilterPayload());

    if (!forceOffline) {
      final online = await quickPollNetwork();
      if (online) {
        try {
          if (!isAuthenticated && config.usercode.isNotEmpty) {
            await login();
          }

          final origin = config.origin.trim().replaceAll(RegExp(r'/+$'), '');
          final listUrl = Uri.parse('$origin/api/WorkOrderList/GetListData');

          final headers = _buildHeaders(
            refererPath: '/workorder/list/work-order/${config.spwId}',
            contentType: 'application/json',
          );

          http.Response response;
          try {
            response = await _client
                .post(listUrl, headers: headers, body: jsonEncode(payload))
                .timeout(const Duration(seconds: 9));
          } catch (e) {
            // Defensive: If sorting by worNoSeq failed on the server SQL engine, retry with woIssueDate
            if (payload['listFormat'] is Map && (payload['listFormat']['orderByFields'] as List).isNotEmpty) {
              final fallbackPayload = Map<String, dynamic>.from(payload);
              fallbackPayload['listFormat'] = Map<String, dynamic>.from(fallbackPayload['listFormat'] as Map);
              fallbackPayload['listFormat']['orderByFields'] = [
                {'name': 'woIssueDate', 'ascending': false},
              ];
              response = await _client
                  .post(listUrl, headers: headers, body: jsonEncode(fallbackPayload))
                  .timeout(const Duration(seconds: 9));
            } else {
              rethrow;
            }
          }

          if (response.statusCode >= 200 && response.statusCode < 300) {
            final body = jsonDecode(response.body);
            final List<dynamic> rows = (body is Map && body['value'] is List)
                ? body['value'] as List<dynamic>
                : (body is List ? body : []);

            final workOrders = <BammWorkOrder>[];
            for (final r in rows) {
              if (r is Map<String, dynamic>) {
                workOrders.add(BammWorkOrder.fromPropertyList(r));
              }
            }

            // Only cache the full initial view (unfiltered latest 2000) so a search doesn't wipe base cache
            if (!hasCriteria && customPayload == null && workOrders.isNotEmpty) {
              await saveCachedWorkOrders(workOrders);
            }
            return workOrders;
          }
        } catch (e) {
          debugPrint('BAMM live fetch failed ($e), falling back to local cached work orders.');
        }
      }
    }

    // Fallback to cache when offline
    final cached = await loadCachedWorkOrders();
    if (cached.isEmpty) {
      return []; // ZERO DUMMY DATA!
    }

    if (hasCriteria) {
      return _filterCachedLocally(cached, criteria);
    }

    return cached;
  }

  /// Construct standard list format payload matching Cogep GuideTi requirements.
  /// Major columns: WO, registered date, responsible, requester, work done, description, asset.
  Map<String, dynamic> _buildDefaultFilterPayload() {
    return {
      'filters': [],
      'listFormat': {
        'fields': _buildMajorFieldsList(),
        'orderByFields': [
          {'name': 'worNoSeq', 'ascending': false},
        ],
        'topCount': 2000,
      },
      'isCountOnly': false,
    };
  }

  /// Builds the complete list of major columns requested by GuideTi.
  List<Map<String, dynamic>> _buildMajorFieldsList() {
    return [
      {
        'name': 'workOrderId',
        'key': 'workOrderId',
        'header': 'ID',
        'isVisible': false,
        'fieldDataType': 4,
      },
      {
        'name': 'worNoSeq',
        'key': 'worNoSeq',
        'header': 'Work order',
        'isVisible': true,
        'fieldDataType': 6,
      },
      {
        'name': 'woIssueDate',
        'key': 'woIssueDate',
        'header': 'WO registered date',
        'isVisible': true,
        'fieldDataType': 5,
      },
      {
        'name': 'recipientName',
        'key': 'recipientName',
        'header': 'Responsible',
        'isVisible': true,
        'fieldDataType': 15,
      },
      {
        'name': 'requesterName',
        'key': 'requesterName',
        'header': 'Requester',
        'isVisible': true,
        'fieldDataType': 15,
      },
      {
        'name': 'woTask',
        'key': 'woTask',
        'header': 'Work done',
        'isVisible': true,
        'fieldDataType': 1,
      },
      {
        'name': 'woDescription',
        'key': 'woDescription',
        'header': 'WO description',
        'isVisible': true,
        'fieldDataType': 1,
      },
      {
        'name': 'funCodeLevelNiv3Description',
        'key': 'funCodeLevelNiv3Description',
        'header': 'Machine',
        'isVisible': true,
        'fieldDataType': 15,
      },
      {
        'name': 'functionInfo2',
        'key': 'functionInfo2',
        'header': 'Cell',
        'isVisible': true,
        'fieldDataType': 1,
      },
      {
        'name': 'woStatusDescription',
        'key': 'woStatusDescription',
        'header': 'Status',
        'isVisible': true,
        'fieldDataType': 15,
      },
      {
        'name': 'woStepDescription',
        'key': 'woStepDescription',
        'header': 'Step',
        'isVisible': true,
        'fieldDataType': 15,
      },
      {
        'name': 'executionModeDescription',
        'key': 'executionModeDescription',
        'header': 'Machine Status',
        'isVisible': true,
        'fieldDataType': 15,
      },
      {
        'name': 'woRequiredDate',
        'key': 'woRequiredDate',
        'header': 'Required date',
        'isVisible': true,
        'fieldDataType': 5,
      },
      {
        'name': 'worNumber3',
        'key': 'worNumber3',
        'header': 'EM Priority',
        'isVisible': true,
        'fieldDataType': 3,
      },
      {
        'name': 'worEstLaborTime',
        'key': 'worEstLaborTime',
        'header': 'Labor Hours',
        'isVisible': true,
        'fieldDataType': 3,
      },
    ];
  }

  /// Builds a GuideTi filter payload for server-side execution across 196k+ work orders.
  Map<String, dynamic> buildFilterPayload(BammFilterCriteria criteria) {
    final filters = <Map<String, dynamic>>[];

    // Status filter (woStatusId, filterType 8)
    if (criteria.status != null && criteria.status!.isNotEmpty && criteria.status != 'All') {
      final sId = criteria.statusId ?? _lookupStatusId(criteria.status!);
      filters.add({
        'searchFieldKey': 'woStatusId',
        'filterType': 8,
        'sourceUrl': 'GetWorkOrderStatus',
        'categoryDescription': 'WO parameters',
        'values': [
          {
            'status': 'included',
            'comparisonType': 'contains',
            'includeNull': false,
            'listValues': [
              {
                'id': sId,
                'value': 0,
                'description': criteria.status!,
                'code': '',
                'type': null,
                'inactive': false,
              }
            ],
            'stringValues': [],
          }
        ],
        'isExpanded': true,
        'isVisible': true,
      });
    }

    // Step filter (woStepId, filterType 3)
    if (criteria.step != null && criteria.step!.isNotEmpty && criteria.step != 'All') {
      final stId = criteria.stepId ?? _lookupStepId(criteria.step!);
      filters.add({
        'searchFieldKey': 'woStepId',
        'filterType': 3,
        'sourceUrl': 'GetWorkOrderStep',
        'categoryDescription': 'WO parameters',
        'values': [
          {
            'status': 'included',
            'comparisonType': 'contains',
            'includeNull': false,
            'listValues': [
              {
                'id': stId,
                'value': 0,
                'description': criteria.step!,
                'code': '',
                'type': null,
                'inactive': false,
              }
            ],
            'stringValues': [],
          }
        ],
        'isExpanded': true,
        'isVisible': true,
      });
    }

    // Maintenance Type filter (maintenanceTypeId, filterType 8)
    if (criteria.maintenanceType != null &&
        criteria.maintenanceType!.isNotEmpty &&
        criteria.maintenanceType != 'All') {
      final mtId = criteria.maintenanceTypeId ?? _lookupMaintId(criteria.maintenanceType!);
      filters.add({
        'searchFieldKey': 'maintenanceTypeId',
        'filterType': 8,
        'sourceUrl': 'GetMaintenanceType',
        'categoryDescription': 'WO parameters',
        'values': [
          {
            'status': 'included',
            'comparisonType': 'contains',
            'includeNull': false,
            'listValues': [
              {
                'id': mtId,
                'value': 0,
                'description': criteria.maintenanceType!,
                'code': '',
                'type': null,
                'inactive': false,
              }
            ],
            'stringValues': [],
          }
        ],
        'isExpanded': true,
        'isVisible': true,
      });
    }

    // Cell / Area (functionInfo2, filterType 1)
    if (criteria.cell != null && criteria.cell!.isNotEmpty && criteria.cell != 'All') {
      filters.add({
        'searchFieldKey': 'functionInfo2',
        'filterType': 1,
        'values': [
          {
            'status': 'included',
            'comparisonType': 'contains',
            'includeNull': false,
            'listValues': [],
            'stringValues': [criteria.cell!],
          }
        ],
        'isExpanded': true,
        'isVisible': true,
      });
    }

    // Responsible (recipientName, filterType 1)
    if (criteria.responsible != null && criteria.responsible!.trim().isNotEmpty) {
      filters.add({
        'searchFieldKey': 'recipientName',
        'filterType': 1,
        'values': [
          {
            'status': 'included',
            'comparisonType': 'contains',
            'includeNull': false,
            'listValues': [],
            'stringValues': [criteria.responsible!.trim()],
          }
        ],
        'isExpanded': true,
        'isVisible': true,
      });
    }

    // Requester (requesterName, filterType 1)
    if (criteria.requester != null && criteria.requester!.trim().isNotEmpty) {
      filters.add({
        'searchFieldKey': 'requesterName',
        'filterType': 1,
        'values': [
          {
            'status': 'included',
            'comparisonType': 'contains',
            'includeNull': false,
            'listValues': [],
            'stringValues': [criteria.requester!.trim()],
          }
        ],
        'isExpanded': true,
        'isVisible': true,
      });
    }

    // Machine / Equipment (funCodeLevelNiv3Description, filterType 1)
    if (criteria.machine != null && criteria.machine!.trim().isNotEmpty) {
      filters.add({
        'searchFieldKey': 'funCodeLevelNiv3Description',
        'filterType': 1,
        'values': [
          {
            'status': 'included',
            'comparisonType': 'contains',
            'includeNull': false,
            'listValues': [],
            'stringValues': [criteria.machine!.trim()],
          }
        ],
        'isExpanded': true,
        'isVisible': true,
      });
    }

    // Machine Status / Execution Mode (executionModeId, filterType 8)
    if (criteria.executionMode != null &&
        criteria.executionMode!.isNotEmpty &&
        criteria.executionMode != 'All') {
      final emId = criteria.executionModeId ?? _lookupExecutionModeId(criteria.executionMode!);
      filters.add({
        'searchFieldKey': 'executionModeId',
        'filterType': 8,
        'sourceUrl': 'GetExecutionMode',
        'values': [
          {
            'status': 'included',
            'comparisonType': 'contains',
            'includeNull': false,
            'listValues': [
              {
                'id': emId,
                'value': 0,
                'description': criteria.executionMode!,
                'code': '',
                'type': null,
                'inactive': false,
              }
            ],
            'stringValues': [],
          }
        ],
        'isExpanded': true,
        'isVisible': true,
      });
    }

    // Text Search / WO Number Search
    if (criteria.searchQuery.trim().isNotEmpty) {
      final q = criteria.searchQuery.trim();
      final isWoNumber = RegExp(r'^(wo-)?\d+(\.\d+)?$', caseSensitive: false).hasMatch(q);
      filters.add({
        'searchFieldKey': isWoNumber ? 'worNoSeq' : 'woDescription',
        'filterType': 1,
        'values': [
          {
            'status': 'included',
            'comparisonType': 'contains',
            'includeNull': false,
            'listValues': [],
            'stringValues': [q],
          }
        ],
        'isExpanded': true,
        'isVisible': true,
      });
    }

    return {
      'filters': filters,
      'listFormat': {
        'fields': _buildMajorFieldsList(),
        'orderByFields': [
          {'name': 'worNoSeq', 'ascending': false},
        ],
        'topCount': 2000,
      },
      'isCountOnly': false,
    };
  }

  /// Filters local cached work orders in-memory when offline.
  List<BammWorkOrder> _filterCachedLocally(List<BammWorkOrder> list, BammFilterCriteria criteria) {
    return list.where((wo) {
      if (criteria.searchQuery.trim().isNotEmpty) {
        final q = criteria.searchQuery.trim().toLowerCase();
        final match = wo.worNoSeq.toLowerCase().contains(q) ||
            wo.description.toLowerCase().contains(q) ||
            wo.cell.toLowerCase().contains(q) ||
            wo.machine.toLowerCase().contains(q) ||
            wo.responsible.toLowerCase().contains(q) ||
            wo.requester.toLowerCase().contains(q) ||
            wo.workDone.toLowerCase().contains(q) ||
            wo.status.toLowerCase().contains(q);
        if (!match) return false;
      }

      if (criteria.status != null && criteria.status!.isNotEmpty && criteria.status != 'All') {
        if (wo.status.toLowerCase() != criteria.status!.toLowerCase()) return false;
      }

      if (criteria.step != null && criteria.step!.isNotEmpty && criteria.step != 'All') {
        if (!wo.step.toLowerCase().contains(criteria.step!.toLowerCase())) return false;
      }

      if (criteria.cell != null && criteria.cell!.isNotEmpty && criteria.cell != 'All') {
        if (!wo.cell.toLowerCase().contains(criteria.cell!.toLowerCase())) return false;
      }

      if (criteria.responsible != null && criteria.responsible!.trim().isNotEmpty) {
        if (!wo.responsible.toLowerCase().contains(criteria.responsible!.toLowerCase().trim())) return false;
      }

      if (criteria.requester != null && criteria.requester!.trim().isNotEmpty) {
        if (!wo.requester.toLowerCase().contains(criteria.requester!.toLowerCase().trim())) return false;
      }

      if (criteria.machine != null && criteria.machine!.trim().isNotEmpty) {
        if (!wo.machine.toLowerCase().contains(criteria.machine!.toLowerCase().trim())) return false;
      }

      return true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Create Work Order
  // ---------------------------------------------------------------------------

  /// Creates a new Work Order on BAMM using the full stateful recalculation flow.
  Future<BammWorkOrder> createWorkOrder({
    required String description,
    String assetId = '',
    int maintenanceTypeId = 107, // Corrective by default
    int stepId = 1, // Normal/Emergency
    String priority = '1.0',
    DateTime? requiredDate,
    String responsible = '',
    String cell = '',
    String machine = '',
    double? laborHours,
  }) async {
    final online = await quickPollNetwork();

    if (online && isAuthenticated) {
      final origin = config.origin.trim().replaceAll(RegExp(r'/+$'), '');

      // Step 1: Obtain Blank Prototype
      final getNewUrl = Uri.parse('$origin/api/WorkOrder/GetNew?spwId=${config.spwId}&assetId=$assetId&workOrderHeaderId=');
      final newResp = await _client.get(
        getNewUrl,
        headers: _buildHeaders(refererPath: '/workorder/detail/0'),
      ).timeout(const Duration(seconds: 4));

      if (newResp.statusCode >= 200 && newResp.statusCode < 300) {
        final blankData = jsonDecode(newResp.body) as Map<String, dynamic>;
        Map<String, dynamic> model = blankData['value'] as Map<String, dynamic>;

        // Step 2: Contextual Mutating Calls
        if (assetId.isNotEmpty) {
          try {
            final changeFnUrl = Uri.parse('$origin/api/WorkOrder/ChangeFunctionCode?assetId=$assetId&actionId=&isApplyDefaultModel=true');
            final fnResp = await _client.post(
              changeFnUrl,
              headers: _buildHeaders(
                refererPath: '/workorder/detail/0',
                contentType: 'application/cogep.dynamicdtoV1+json',
              ),
              body: jsonEncode(model),
            );
            if (fnResp.statusCode == 200) {
              final fnData = jsonDecode(fnResp.body);
              if (fnData['value'] is Map<String, dynamic>) {
                model = fnData['value'] as Map<String, dynamic>;
              }
            }
          } catch (_) {}
        }

        // Step 3: Apply User Field Edits
        final properties = (model['properties'] as List<dynamic>?) ?? [];
        void setProp(String name, dynamic val, {int type = 9}) {
          var found = false;
          for (var p in properties) {
            if (p is Map && p['name'] == name) {
              p['value'] = val?.toString();
              p['state'] = 2;
              found = true;
              break;
            }
          }
          if (!found) {
            properties.add({
              'name': name,
              'value': val?.toString(),
              'type': type,
              'state': 2,
              'shortTypeName': 'WORK_ORDER',
            });
          }
        }

        setProp('WOR_DESCR', description, type: 9);
        if (assetId.isNotEmpty) setProp('FUN_ID', assetId, type: 4);
        setProp('MNT_ID', maintenanceTypeId, type: 4);
        setProp('WSP_ID', stepId, type: 4);
        if (priority.isNotEmpty) setProp('WOR_NB_3', priority, type: 3);
        if (requiredDate != null) {
          setProp('WOR_REQUI_DATE', requiredDate.millisecondsSinceEpoch.toString(), type: 28);
        }

        model['properties'] = properties;
        model['state'] = 3;
        model['isNull'] = false;
        model['forceEmpty'] = false;
        model['shortTypeName'] = 'WORK_ORDER';

        // Step 4: Commit Save
        final saveUrl = Uri.parse('$origin/api/WorkOrder/Save?duplicateQuestionSettingsJson=');
        final saveResp = await _client.post(
          saveUrl,
          headers: _buildHeaders(
            refererPath: '/workorder/detail/0',
            contentType: 'application/cogep.dynamicdtoV1+json',
          ),
          body: jsonEncode(model),
        ).timeout(const Duration(seconds: 6));

        if (saveResp.statusCode >= 200 && saveResp.statusCode < 300) {
          final saveJson = jsonDecode(saveResp.body) as Map<String, dynamic>;
          final val = saveJson['value'] as Map<String, dynamic>?;
          final newWorId = (val?['WOR_ID'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final newWorNo = val?['WOR_NO']?.toString() ?? 'WO-$newWorId';

          final created = BammWorkOrder(
            worId: newWorId,
            worNoSeq: newWorNo,
            description: description,
            status: 'Registered',
            step: stepId == 3 ? 'Emergency' : 'Normal',
            cell: cell,
            machine: machine,
            assetId: assetId,
            priority: priority,
            responsible: responsible,
            requiredDate: requiredDate,
            issueDate: DateTime.now(),
            laborHours: laborHours,
            rawDto: saveJson,
          );

          await _upsertLocalCachedWorkOrder(created);
          return created;
        }
      }
    }

    throw HttpException(
      'Cannot create work order while disconnected from BAMM (${config.origin}). '
      'Please ensure device is connected to the plant Wi-Fi / VPN.',
    );
  }

  // ---------------------------------------------------------------------------
  // Edit Work Order
  // ---------------------------------------------------------------------------

  /// Updates an existing Work Order using the BAMM lock & DynamicDTO protocol.
  Future<BammWorkOrder> updateWorkOrder({
    required int worId,
    required String description,
    String? status,
    String? step,
    String? priority,
    DateTime? requiredDate,
    String? cell,
    String? machine,
    String? responsible,
    double? laborHours,
  }) async {
    final online = await quickPollNetwork();

    if (online && isAuthenticated && worId > 0) {
      final origin = config.origin.trim().replaceAll(RegExp(r'/+$'), '');

      // 1. GET fresh model
      final getUrl = Uri.parse('$origin/api/WorkOrder/GetById?id=$worId&spwId=${config.spwId}');
      final getResp = await _client.get(
        getUrl,
        headers: _buildHeaders(refererPath: '/workorder/detail/$worId'),
      ).timeout(const Duration(seconds: 4));

      if (getResp.statusCode == 200) {
        final dtoData = jsonDecode(getResp.body) as Map<String, dynamic>;
        Map<String, dynamic> model = dtoData['value'] as Map<String, dynamic>;

        // 2. Mutate properties with state = 2
        final properties = (model['properties'] as List<dynamic>?) ?? [];
        void updateProp(String name, dynamic val) {
          if (val == null) return;
          for (var p in properties) {
            if (p is Map && p['name'] == name) {
              p['value'] = val.toString();
              p['state'] = 2;
              return;
            }
          }
        }

        updateProp('WOR_DESCR', description);
        if (priority != null) updateProp('WOR_NB_3', priority);
        if (requiredDate != null) {
          updateProp('WOR_REQUI_DATE', requiredDate.millisecondsSinceEpoch.toString());
        }

        model['properties'] = properties;
        model['state'] = 2;
        model['shortTypeName'] = 'WORK_ORDER';

        // 3. Acquire lock
        try {
          final lockUrl = Uri.parse('$origin/api/dataLock/Save');
          final lockPayload = {
            'ProgramID': 1,
            'TableName': 'WORK_ORDER',
            'RecordID': worId,
            'CompanyID': config.companyId,
          };
          await _client.post(
            lockUrl,
            headers: _buildHeaders(refererPath: '/workorder/detail/$worId'),
            body: jsonEncode(lockPayload),
          ).timeout(const Duration(seconds: 3));
        } catch (_) {}

        // 4. Save
        final saveUrl = Uri.parse('$origin/api/WorkOrder/Save?duplicateQuestionSettingsJson=');
        final saveResp = await _client.post(
          saveUrl,
          headers: _buildHeaders(
            refererPath: '/workorder/detail/$worId',
            contentType: 'application/cogep.dynamicdtoV1+json',
          ),
          body: jsonEncode(model),
        ).timeout(const Duration(seconds: 6));

        // 5. Release lock
        try {
          final unlockUrl = Uri.parse('$origin/api/dataLock/Delete');
          final unlockPayload = {
            'ProgramID': 1,
            'TableName': 'WORK_ORDER',
            'RecordID': worId,
            'CompanyID': config.companyId,
          };
          await _client.post(
            unlockUrl,
            headers: _buildHeaders(refererPath: '/workorder/detail/$worId'),
            body: jsonEncode(unlockPayload),
          ).timeout(const Duration(seconds: 3));
        } catch (_) {}

        if (saveResp.statusCode >= 200 && saveResp.statusCode < 300) {
          final updated = BammWorkOrder(
            worId: worId,
            worNoSeq: worId.toString(),
            description: description,
            status: status ?? 'Registered',
            step: step ?? 'Normal',
            cell: cell ?? '',
            machine: machine ?? '',
            priority: priority ?? '',
            responsible: responsible ?? '',
            requiredDate: requiredDate,
            laborHours: laborHours,
            rawDto: model,
          );

          await _upsertLocalCachedWorkOrder(updated);
          return updated;
        }
      }
    }

    throw HttpException(
      'Cannot update work order #$worId while disconnected from BAMM (${config.origin}). '
      'Please ensure device is connected to the plant Wi-Fi / VPN.',
    );
  }

  /// Fetches complete Work Order detail on demand from BAMM using GetById.
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async {
    if (worId <= 0) return null;
    final online = await quickPollNetwork();
    if (!online) return null;

    try {
      if (!isAuthenticated && config.usercode.isNotEmpty) {
        await login();
      }

      final origin = config.origin.trim().replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$origin/api/WorkOrder/GetById?id=$worId&spwId=${config.spwId}');

      final response = await _client
          .get(url, headers: _buildHeaders(refererPath: '/workorder/detail/$worId'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final val = body is Map ? body['value'] : null;
        if (val is Map<String, dynamic>) {
          final detail = BammWorkOrder.fromDynamicDto(val);
          await _upsertLocalCachedWorkOrder(detail);
          return detail;
        }
      }
    } catch (e) {
      debugPrint('Error fetching BAMM work order detail for $worId: $e');
    }
    return null;
  }

  /// Fetches lookup options dynamically from BAMM WorkOrderLookup endpoints.
  Future<List<BammLookupItem>> fetchLookup(String method, {String search = ''}) async {
    final online = await quickPollNetwork();
    if (online) {
      try {
        if (!isAuthenticated && config.usercode.isNotEmpty) {
          await login();
        }

        final origin = config.origin.trim().replaceAll(RegExp(r'/+$'), '');
        final searchParam = search.isNotEmpty ? '&search=${Uri.encodeComponent(search)}&searchColumns=description' : '';
        final url = Uri.parse(
          '$origin/api/WorkOrderLookup/$method?querytype=top&pageSize=200&companyId=${config.companyId}&sortColumn=description$searchParam',
        );

        final headers = _buildHeaders(refererPath: '/');
        final response = await _client.post(url, headers: headers).timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(response.body);
          final rows = (body is Map && body['value'] is List) ? body['value'] as List<dynamic> : [];
          final items = rows
              .whereType<Map<String, dynamic>>()
              .map((r) => BammLookupItem.fromJson(r))
              .toList();
          if (items.isNotEmpty) return items;
        }
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
    if (s.contains('estimat')) return 7; // In estimate
    if (s.contains('regist')) return 8; // Registered
    if (s.contains('ready')) return 9; // Ready to schedule
    if (s.contains('complet')) return 3; // Completed
    if (s.contains('close')) return 6; // Closed
    if (s.contains('cancel')) return 4; // Cancelled
    if (s.contains('declin')) return 5; // Declined
    return 1;
  }

  int _lookupStepId(String step) {
    final s = step.trim().toLowerCase();
    if (s.contains('emerg')) return 3; // Emergency
    if (s.contains('plan')) return 5; // Planned Work
    if (s.contains('follow')) return 4; // Follow-up
    if (s.contains('counter')) return 2; // Countermeasure
    if (s.contains('defect')) return 700000007; // Defect Handling
    return 1;
  }

  int _lookupMaintId(String maint) {
    final m = maint.trim().toLowerCase();
    if (m.contains('corrective')) return 107;
    if (m.contains('kaizen')) return 111;
    if (m.contains('preventive') || m.contains('pm')) return 108;
    if (m.contains('assist')) return 118;
    if (m.contains('pitstop')) return 117;
    if (m.contains('emerg')) return 105;
    if (m.contains('defect')) return 700000019;
    if (m.contains('safety')) return 700000020;
    if (m.contains('project') || m.contains('capex')) return 115;
    return 107;
  }

  int _lookupExecutionModeId(String mode) {
    final m = mode.trim().toLowerCase();
    if (m.contains('run')) return 1;
    if (m.contains('stop')) return 2;
    if (m.contains('reduc')) return 3;
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
          BammLookupItem(id: 3, description: 'Emergency'),
          BammLookupItem(id: 5, description: 'Planned Work'),
          BammLookupItem(id: 2, description: 'Countermeasure'),
          BammLookupItem(id: 4, description: 'Follow-up'),
          BammLookupItem(id: 700000007, description: 'Defect Handling'),
        ];
      case 'GetMaintenanceType':
        return const [
          BammLookupItem(id: 107, description: 'Corrective'),
          BammLookupItem(id: 111, description: 'Kaizen'),
          BammLookupItem(id: 108, description: 'Preventive'),
          BammLookupItem(id: 105, description: 'Emergency'),
          BammLookupItem(id: 118, description: 'Emergency - Assist'),
          BammLookupItem(id: 117, description: 'Emergency - Pitstop'),
          BammLookupItem(id: 700000019, description: 'Defect'),
          BammLookupItem(id: 700000020, description: 'Defect - Safety'),
          BammLookupItem(id: 115, description: 'Project / CapEx'),
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
      case 'GetExecutionMode':
        return const [
          BammLookupItem(id: 1, description: 'Running'),
          BammLookupItem(id: 2, description: 'Stopped'),
          BammLookupItem(id: 3, description: 'Reduced Speed'),
        ];
      default:
        return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Local File & Storage Utilities
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

  Future<List<BammWorkOrder>> loadCachedWorkOrders() async {
    try {
      final file = await _getFile(_cacheFileName);
      if (!await file.exists()) return [];
      final text = await file.readAsString();
      if (text.trim().isEmpty) return [];
      final list = jsonDecode(text) as List<dynamic>;
      return list.map((e) => BammWorkOrder.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading BAMM cache: $e');
      return [];
    }
  }

  Future<void> saveCachedWorkOrders(List<BammWorkOrder> orders) async {
    try {
      final file = await _getFile(_cacheFileName);
      final jsonStr = jsonEncode(orders.map((o) => o.toJson()).toList());
      await _atomicWrite(file, jsonStr);
    } catch (e) {
      debugPrint('Error saving BAMM cache: $e');
    }
  }

  Future<void> _upsertLocalCachedWorkOrder(BammWorkOrder item) async {
    final list = await loadCachedWorkOrders();
    final idx = list.indexWhere((o) => o.worId == item.worId || (o.worNoSeq.isNotEmpty && o.worNoSeq == item.worNoSeq));
    if (idx >= 0) {
      list[idx] = item;
    } else {
      list.insert(0, item);
    }
    await saveCachedWorkOrders(list);
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
