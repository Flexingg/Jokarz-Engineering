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

  /// Fetches Work Orders from BAMM or falls back to local cached list if offline.
  Future<List<BammWorkOrder>> fetchWorkOrders({
    Map<String, dynamic>? customPayload,
    bool forceOffline = false,
  }) async {
    if (!forceOffline) {
      final online = await quickPollNetwork();
      if (online) {
        try {
          if (!isAuthenticated && config.usercode.isNotEmpty) {
            await login();
          }

          final origin = config.origin.trim().replaceAll(RegExp(r'/+$'), '');
          final listUrl = Uri.parse('$origin/api/WorkOrderList/GetListData');

          final payload = customPayload ?? _buildDefaultFilterPayload();

          final headers = _buildHeaders(
            refererPath: '/workorder/list/work-order/${config.spwId}',
            contentType: 'application/json',
          );

          final response = await _client
              .post(listUrl, headers: headers, body: jsonEncode(payload))
              .timeout(const Duration(seconds: 6));

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

            if (workOrders.isNotEmpty) {
              await saveCachedWorkOrders(workOrders);
              return workOrders;
            }
          }
        } catch (e) {
          debugPrint('BAMM live fetch failed ($e), falling back to cached work orders.');
        }
      }
    }

    // Fallback to cache or realistic sample plant data
    final cached = await loadCachedWorkOrders();
    if (cached.isNotEmpty) {
      return cached;
    }

    // Default plant sample work orders for instant usability
    final seed = _getInitialPlantSampleOrders();
    await saveCachedWorkOrders(seed);
    return seed;
  }

  /// Construct standard list format payload matching Cogep GuideTi requirements.
  Map<String, dynamic> _buildDefaultFilterPayload() {
    return {
      'filters': [],
      'listFormat': {
        'fields': [
          {
            'name': 'workOrderId',
            'key': 'workOrderId',
            'header': 'ID',
            'isVisible': true,
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
            'name': 'woDescription',
            'key': 'woDescription',
            'header': 'WO description',
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
            'name': 'functionInfo2',
            'key': 'functionInfo2',
            'header': 'Cell',
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
            'name': 'woRequiredDate',
            'key': 'woRequiredDate',
            'header': 'Required date',
            'isVisible': true,
            'fieldDataType': 5,
          },
          {
            'name': 'woIssueDate',
            'key': 'woIssueDate',
            'header': 'Issue date',
            'isVisible': true,
            'fieldDataType': 5,
          },
          {
            'name': 'worEstLaborTime',
            'key': 'worEstLaborTime',
            'header': 'Labor Hours',
            'isVisible': true,
            'fieldDataType': 3,
          },
          {
            'name': 'worNumber3',
            'key': 'worNumber3',
            'header': 'EM Priority',
            'isVisible': true,
            'fieldDataType': 3,
          },
        ],
        'orderByFields': [
          {'name': 'woIssueDate', 'ascending': false},
        ],
        'topCount': 2000,
      },
      'isCountOnly': false,
    };
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

    // Offline / Fallback Local Creation
    final generatedId = 700000000 + (DateTime.now().millisecondsSinceEpoch % 900000);
    final generatedNo = (185600 + (DateTime.now().millisecondsSinceEpoch % 900)).toString();

    final created = BammWorkOrder(
      worId: generatedId,
      worNoSeq: generatedNo,
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
    );

    await _upsertLocalCachedWorkOrder(created);
    return created;
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

        // 3. Acquire Pessimistic Record Lock
        try {
          final lockUrl = Uri.parse('$origin/api/RecordLocking/Lock?programId=1&tableName=WORK_ORDER&recordId=$worId');
          await _client.get(
            lockUrl,
            headers: _buildHeaders(refererPath: '/workorder/detail/$worId'),
          ).timeout(const Duration(seconds: 2));
        } catch (_) {}

        // 4. Commit Save
        final saveUrl = Uri.parse('$origin/api/WorkOrder/Save?duplicateQuestionSettingsJson=');
        final saveResp = await _client.post(
          saveUrl,
          headers: _buildHeaders(
            refererPath: '/workorder/detail/$worId',
            contentType: 'application/cogep.dynamicdtoV1+json',
          ),
          body: jsonEncode(model),
        ).timeout(const Duration(seconds: 5));

        if (saveResp.statusCode == 200) {
          final cachedList = await loadCachedWorkOrders();
          final index = cachedList.indexWhere((w) => w.worId == worId);
          final existing = index >= 0 ? cachedList[index] : null;

          final updated = (existing ?? BammWorkOrder(worId: worId, worNoSeq: worId.toString(), description: description)).copyWith(
            description: description,
            status: status ?? existing?.status,
            step: step ?? existing?.step,
            priority: priority ?? existing?.priority,
            requiredDate: requiredDate ?? existing?.requiredDate,
            cell: cell ?? existing?.cell,
            machine: machine ?? existing?.machine,
            responsible: responsible ?? existing?.responsible,
            laborHours: laborHours ?? existing?.laborHours,
          );

          await _upsertLocalCachedWorkOrder(updated);
          return updated;
        }
      }
    }

    // Offline / Local update
    final cachedList = await loadCachedWorkOrders();
    final index = cachedList.indexWhere((w) => w.worId == worId);
    final existing = index >= 0 ? cachedList[index] : null;

    final updated = (existing ?? BammWorkOrder(worId: worId, worNoSeq: worId.toString(), description: description)).copyWith(
      description: description,
      status: status ?? existing?.status,
      step: step ?? existing?.step,
      priority: priority ?? existing?.priority,
      requiredDate: requiredDate ?? existing?.requiredDate,
      cell: cell ?? existing?.cell,
      machine: machine ?? existing?.machine,
      responsible: responsible ?? existing?.responsible,
      laborHours: laborHours ?? existing?.laborHours,
    );

    await _upsertLocalCachedWorkOrder(updated);
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Storage & Persistence
  // ---------------------------------------------------------------------------

  Future<File> _getFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$filename');
  }

  Future<void> _atomicWrite(File file, String content) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
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
      BammSavedFilter(id: 'filter_prep', name: 'In Preparation', status: 'In preparation'),
      BammSavedFilter(id: 'filter_scheduled', name: 'Scheduled', status: 'Scheduled'),
      BammSavedFilter(id: 'filter_emergency', name: 'Emergency', step: 'Emergency'),
      BammSavedFilter(id: 'filter_line3', name: 'Line 3 Orders', cell: 'Line 3'),
    ];
  }

  List<BammWorkOrder> _getInitialPlantSampleOrders() {
    final now = DateTime.now();
    return [
      BammWorkOrder(
        worId: 700203512,
        worNoSeq: '185586',
        description: 'Replace drive motor bearings on Line 3 conveyor',
        status: 'In preparation',
        step: 'Emergency',
        cell: 'Line 3',
        machine: 'Main Conveyor',
        priority: '1.0',
        responsible: 'Miller, John',
        requester: 'Operator Bill',
        requiredDate: now.add(const Duration(days: 1)),
        issueDate: now.subtract(const Duration(days: 2)),
        laborHours: 2.5,
        requiredEmployees: 2,
      ),
      BammWorkOrder(
        worId: 700203513,
        worNoSeq: '185590',
        description: 'Kaizen: Install pneumatic diverter gate sensors',
        status: 'Scheduled',
        step: 'Kaizen',
        cell: 'Line 2',
        machine: 'Packer A',
        priority: '2.5',
        responsible: 'Davis, Alex',
        requester: 'Continuous Imprv.',
        requiredDate: now.add(const Duration(days: 4)),
        issueDate: now.subtract(const Duration(days: 5)),
        laborHours: 4.0,
        requiredEmployees: 1,
      ),
      BammWorkOrder(
        worId: 700203549,
        worNoSeq: '185610',
        description: 'Inspect seal integrity and rebuild manifold on Filler B',
        status: 'Registered',
        step: 'Corrective',
        cell: 'Line 1',
        machine: 'Filler B',
        priority: '3.0',
        responsible: 'Wilson, Sarah',
        requester: 'Quality Dept',
        requiredDate: now.add(const Duration(days: 3)),
        issueDate: now.subtract(const Duration(days: 1)),
        laborHours: 1.5,
        requiredEmployees: 1,
      ),
      BammWorkOrder(
        worId: 700203490,
        worNoSeq: '184920',
        description: 'Fabricate stainless catch pan bracket and support arms',
        status: 'Ready to schedule',
        step: 'Corrective',
        cell: 'Line 3',
        machine: 'Labeler',
        priority: '2.0',
        responsible: 'Doe, Jane',
        requester: 'Packaging Lead',
        requiredDate: now.add(const Duration(days: 6)),
        issueDate: now.subtract(const Duration(days: 7)),
        laborHours: 3.0,
        requiredEmployees: 1,
      ),
      BammWorkOrder(
        worId: 700203415,
        worNoSeq: '184315',
        description: 'Rebuild gripper cylinder and replace worn air lines',
        status: 'In estimate',
        step: 'Corrective',
        cell: 'Line 4',
        machine: 'Palletizer',
        priority: '4.0',
        responsible: 'Smith, Chris',
        requester: 'Maint Shift 2',
        requiredDate: now.add(const Duration(days: 10)),
        issueDate: now.subtract(const Duration(days: 8)),
        laborHours: 5.0,
        requiredEmployees: 2,
      ),
      BammWorkOrder(
        worId: 700202036,
        worNoSeq: '182036',
        description: 'Annual safety interlock verification & optical sensor calibration',
        status: 'Completed',
        step: 'Preventive',
        cell: 'Plant-Wide',
        machine: 'Safety Interlocks',
        priority: '1.0',
        responsible: 'Johnson, Mark',
        requester: 'EHS Safety',
        requiredDate: now.subtract(const Duration(days: 1)),
        issueDate: now.subtract(const Duration(days: 14)),
        laborHours: 6.0,
        requiredEmployees: 2,
      ),
    ];
  }
}
