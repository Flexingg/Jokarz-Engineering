import 'package:flutter/material.dart';

/// Represents a Work Order from Cogep GuideTi / BAMM.
class BammWorkOrder {
  final int worId;
  final String worNoSeq;
  final String description;
  final String status;
  final int? statusId;
  final String step;
  final int? stepId;
  final String area;
  final String machine;
  final String assetId;
  final String priority;
  final String responsible;
  final String requester;
  final String workDone;
  final DateTime? issueDate;
  final DateTime? requiredDate;
  final double? laborHours;
  final int? requiredEmployees;
  final String maintenanceType;
  final int? maintenanceTypeId;
  final String executionMode;
  final Map<String, dynamic>? rawDto;

  BammWorkOrder({
    required this.worId,
    required this.worNoSeq,
    required this.description,
    this.status = 'Registered',
    this.statusId,
    this.step = 'Normal',
    this.stepId,
    this.area = '',
    this.machine = '',
    this.assetId = '',
    this.priority = '',
    this.responsible = '',
    this.requester = '',
    this.workDone = '',
    this.issueDate,
    this.requiredDate,
    this.laborHours,
    this.requiredEmployees,
    this.maintenanceType = '',
    this.maintenanceTypeId,
    this.executionMode = '',
    this.rawDto,
  });

  /// Short display title, e.g. "BAMM #185586 - Motor Replacement"
  String get displayTitle => 'BAMM #$worNoSeq${description.isNotEmpty ? ' - $description' : ''}';

  Color get statusColor {
    final s = status.trim().toLowerCase();
    if (s.contains('prep')) return const Color(0xFFF59E0B); // Amber
    if (s.contains('schedul')) return const Color(0xFF3B82F6); // Blue
    if (s.contains('ready')) return const Color(0xFF06B6D4); // Cyan
    if (s.contains('estimat')) return const Color(0xFF8B5CF6); // Purple
    if (s.contains('complet') || s.contains('closed')) return const Color(0xFF10B981); // Emerald
    if (s.contains('emerg')) return const Color(0xFFEF4444); // Red
    return const Color(0xFF64748B); // Slate
  }

  Color get stepColor {
    final st = step.trim().toLowerCase();
    if (st.contains('emerg')) return const Color(0xFFEF4444);
    if (st.contains('kaizen')) return const Color(0xFF8B5CF6);
    if (st.contains('corrective')) return const Color(0xFFF97316);
    if (st.contains('preventive')) return const Color(0xFF10B981);
    return const Color(0xFF64748B);
  }

  BammWorkOrder copyWith({
    int? worId,
    String? worNoSeq,
    String? description,
    String? status,
    int? statusId,
    String? step,
    int? stepId,
    String? area,
    String? machine,
    String? assetId,
    String? priority,
    String? responsible,
    String? requester,
    String? workDone,
    DateTime? issueDate,
    DateTime? requiredDate,
    double? laborHours,
    int? requiredEmployees,
    String? maintenanceType,
    int? maintenanceTypeId,
    String? executionMode,
    Map<String, dynamic>? rawDto,
  }) {
    return BammWorkOrder(
      worId: worId ?? this.worId,
      worNoSeq: worNoSeq ?? this.worNoSeq,
      description: description ?? this.description,
      status: status ?? this.status,
      statusId: statusId ?? this.statusId,
      step: step ?? this.step,
      stepId: stepId ?? this.stepId,
      area: area ?? this.area,
      machine: machine ?? this.machine,
      assetId: assetId ?? this.assetId,
      priority: priority ?? this.priority,
      responsible: responsible ?? this.responsible,
      requester: requester ?? this.requester,
      workDone: workDone ?? this.workDone,
      issueDate: issueDate ?? this.issueDate,
      requiredDate: requiredDate ?? this.requiredDate,
      laborHours: laborHours ?? this.laborHours,
      requiredEmployees: requiredEmployees ?? this.requiredEmployees,
      maintenanceType: maintenanceType ?? this.maintenanceType,
      maintenanceTypeId: maintenanceTypeId ?? this.maintenanceTypeId,
      executionMode: executionMode ?? this.executionMode,
      rawDto: rawDto ?? this.rawDto,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'worId': worId,
      'worNoSeq': worNoSeq,
      'description': description,
      'status': status,
      'statusId': statusId,
      'step': step,
      'stepId': stepId,
      'area': area,
      'machine': machine,
      'assetId': assetId,
      'priority': priority,
      'responsible': responsible,
      'requester': requester,
      'workDone': workDone,
      'issueDate': issueDate?.toIso8601String(),
      'requiredDate': requiredDate?.toIso8601String(),
      'laborHours': laborHours,
      'requiredEmployees': requiredEmployees,
      'maintenanceType': maintenanceType,
      'maintenanceTypeId': maintenanceTypeId,
      'executionMode': executionMode,
      'rawDto': rawDto,
    };
  }

  factory BammWorkOrder.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      final s = val.toString().trim();
      final asInt = int.tryParse(s);
      if (asInt != null && asInt > 100000000) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      return DateTime.tryParse(s);
    }

    return BammWorkOrder(
      worId: (json['worId'] as num?)?.toInt() ?? 0,
      worNoSeq: json['worNoSeq']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Registered',
      statusId: (json['statusId'] as num?)?.toInt(),
      step: json['step']?.toString() ?? 'Normal',
      stepId: (json['stepId'] as num?)?.toInt(),
      area: json['area']?.toString() ?? json['cell']?.toString() ?? '',
      machine: json['machine']?.toString() ?? '',
      assetId: json['assetId']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
      responsible: json['responsible']?.toString() ?? '',
      requester: json['requester']?.toString() ?? '',
      workDone: json['workDone']?.toString() ?? '',
      issueDate: parseDate(json['issueDate']),
      requiredDate: parseDate(json['requiredDate']),
      laborHours: (json['laborHours'] as num?)?.toDouble(),
      requiredEmployees: (json['requiredEmployees'] as num?)?.toInt(),
      maintenanceType: json['maintenanceType']?.toString() ?? '',
      maintenanceTypeId: (json['maintenanceTypeId'] as num?)?.toInt(),
      executionMode: json['executionMode']?.toString() ?? '',
      rawDto: json['rawDto'] as Map<String, dynamic>?,
    );
  }

  /// Parses a row from BAMM's GetListData endpoint (which is wrapped in `propertyList`).
  factory BammWorkOrder.fromPropertyList(Map<String, dynamic> raw) {
    final p = (raw['propertyList'] is Map<String, dynamic>)
        ? raw['propertyList'] as Map<String, dynamic>
        : raw;

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      final s = val.toString().trim();
      final asInt = int.tryParse(s);
      if (asInt != null && asInt > 100000000) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      return DateTime.tryParse(s);
    }

    final idVal = p['workOrderId'] ?? p['WOR_ID'] ?? p['worId'];
    final worId = (idVal is num) ? idVal.toInt() : (int.tryParse(idVal?.toString() ?? '') ?? 0);
    final worNo = (p['worNoSeq'] ?? p['WOR_NO_SEQ'] ?? p['WOR_NO'] ?? p['worNo'] ?? '').toString();
    final areaVal = (p['regrouping1Description'] ?? p['area'] ?? p['functionInfo2'] ?? p['WOR_DEPARTMENT_CODE'] ?? p['cell'] ?? '').toString();

    return BammWorkOrder(
      worId: worId,
      worNoSeq: worNo.isNotEmpty ? worNo : (worId > 0 ? worId.toString() : 'Unknown'),
      description: (p['woDescription'] ?? p['WOR_TEXT'] ?? p['WOR_DESCR'] ?? p['description'] ?? '').toString(),
      status: (p['woStatusDescription'] ?? p['WOR_STATUS_DESC'] ?? p['status'] ?? 'Registered').toString(),
      statusId: (p['woStatusId'] ?? p['WOR_STATUS_ID'] as num?)?.toInt(),
      step: (p['woStepDescription'] ?? p['WOR_STEP_DESC'] ?? p['step'] ?? 'Normal').toString(),
      stepId: (p['woStepId'] ?? p['WOR_STEP_ID'] as num?)?.toInt(),
      area: areaVal,
      machine: (p['funCodeLevelNiv3Description'] ?? p['WOR_EQUIPMENT_CODE'] ?? p['machine'] ?? '').toString(),
      assetId: (p['functionCode'] ?? p['FUN_ID'] ?? p['assetId'] ?? '').toString(),
      priority: (p['worNumber3'] ?? p['WOR_PRIORITY_DESC'] ?? p['PRI_ID'] ?? '').toString(),
      responsible: (p['recipientName'] ?? p['WOR_RESPONSIBLE_NAME'] ?? p['responsible'] ?? '').toString(),
      requester: (p['requesterName'] ?? p['WOR_REQUESTER_NAME'] ?? p['requester'] ?? '').toString(),
      workDone: (p['woTask'] ?? p['workDone'] ?? p['woDoneDescription'] ?? p['WOD_DESCR'] ?? '').toString(),
      issueDate: parseDate(p['woIssueDate'] ?? p['WOR_ISSUE_DATE']),
      requiredDate: parseDate(p['woRequiredDate'] ?? p['WOR_REQUIRED_DATE']),
      laborHours: (p['worEstLaborTime'] ?? p['WOR_EST_LABOR_HOURS'] as num?)?.toDouble(),
      requiredEmployees: (p['worEstNbEmployee'] ?? p['WOR_EST_NB_EMPLOYEE'] as num?)?.toInt(),
      maintenanceType: (p['maintenanceTypeDescription'] ?? p['WOR_MAINT_TYPE_DESC'] ?? p['maintenanceType'] ?? '').toString(),
      maintenanceTypeId: (p['maintenanceTypeId'] ?? p['MNT_ID'] as num?)?.toInt(),
      executionMode: (p['executionModeDescription'] ?? '').toString(),
      rawDto: raw,
    );
  }

  /// Parses a full DynamicDTO model returned by GET /api/WorkOrder/GetById.
  factory BammWorkOrder.fromDynamicDto(Map<String, dynamic> dto) {
    final properties = (dto['properties'] as List<dynamic>?) ?? [];
    String getProp(String name, [String fallback = '']) {
      for (final p in properties) {
        if (p is Map && p['name'] == name) {
          final val = p['value'];
          return val != null ? val.toString() : fallback;
        }
      }
      if (dto.containsKey(name) && dto[name] != null) {
        return dto[name].toString();
      }
      return fallback;
    }

    DateTime? parseEpochOrDate(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      final ms = int.tryParse(raw);
      if (ms != null && ms > 100000000) {
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
      return DateTime.tryParse(raw);
    }

    final id = int.tryParse(getProp('WOR_ID', '0')) ?? 0;
    final no = getProp('WOR_NO_SEQ', getProp('WOR_NO', id.toString()));

    // Check activity lines for work done description
    String extractedWorkDone = '';
    final childSets = (dto['childSets'] as List<dynamic>?) ?? [];
    for (final cs in childSets) {
      if (cs is Map && cs['originProperty'] == 'WO_DETAIL') {
        final items = (cs['items'] as List<dynamic>?) ?? [];
        for (final item in items) {
          if (item is Map && item['properties'] is List) {
            for (final p in item['properties']) {
              if (p is Map && p['name'] == 'WOD_DESCR' && p['value'] != null && p['value'].toString().isNotEmpty) {
                extractedWorkDone = p['value'].toString();
                break;
              }
            }
          }
          if (extractedWorkDone.isNotEmpty) break;
        }
      }
    }

    return BammWorkOrder(
      worId: id,
      worNoSeq: no,
      description: getProp('WOR_DESCR'),
      status: getProp('WOR_STATUS_DESC', 'Registered'),
      statusId: int.tryParse(getProp('WOR_STATUS_ID', '')),
      step: getProp('WOR_STEP_DESC', 'Normal'),
      stepId: int.tryParse(getProp('WSP_ID', '')),
      area: getProp('regrouping1Description', getProp('WOR_DEPARTMENT_CODE', getProp('functionInfo2', getProp('cell')))),
      machine: getProp('funCodeLevelNiv3Description', getProp('WOR_EQUIPMENT_CODE', getProp('machine'))),
      assetId: getProp('FUN_ID'),
      priority: getProp('WOR_PRIORITY_DESC', getProp('WOR_NB_3')),
      responsible: getProp('WOR_RESPONSIBLE_NAME', getProp('recipientName')),
      requester: getProp('WOR_REQUESTER_NAME', getProp('requesterName')),
      workDone: extractedWorkDone.isNotEmpty ? extractedWorkDone : getProp('woTask'),
      issueDate: parseEpochOrDate(getProp('WOR_ISSUE_DATE')),
      requiredDate: parseEpochOrDate(getProp('WOR_REQUI_DATE')),
      laborHours: double.tryParse(getProp('WOR_EST_LABOR_HOURS', '')),
      maintenanceType: getProp('WOR_MAINT_TYPE_DESC', getProp('maintenanceTypeDescription')),
      maintenanceTypeId: int.tryParse(getProp('MNT_ID', '')),
      rawDto: dto,
    );
  }
}

/// A lookup item from BAMM dropdown endpoints (e.g. GetWorkOrderStatus).
class BammLookupItem {
  final dynamic id;
  final String description;
  final String code;

  const BammLookupItem({
    required this.id,
    required this.description,
    this.code = '',
  });

  factory BammLookupItem.fromJson(Map<String, dynamic> json) {
    return BammLookupItem(
      id: json['id'] ?? json['value'],
      description: (json['description'] ?? json['label'] ?? json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'code': code,
  };
}

/// One `WO_DETAIL` activity line, as read from a `GetById` model's
/// `WO_DETAIL` child set. BAMM's DynamicDTO carries `ACY_ID`/`SAC_ID` as bare
/// ids with no sibling description property (same limitation as the header
/// lookup fields), so [activityId]/[subActivityId] are shown as raw ids in
/// the UI unless resolved against a fetched `GetActivities`/`GetSubActivities`
/// list.
class BammActivityLine {
  final String id;
  final String description;
  final String activityId;
  final String subActivityId;
  final double? hours;
  final String memo;

  const BammActivityLine({
    required this.id,
    required this.description,
    required this.activityId,
    required this.subActivityId,
    this.hours,
    this.memo = '',
  });
}

/// Comprehensive filter criteria for server-side and client-side querying.
class BammFilterCriteria {
  final String searchQuery;
  final String? status;
  final int? statusId;
  final String? step;
  final int? stepId;
  final String? maintenanceType;
  final int? maintenanceTypeId;
  final String? area;
  final int? areaId;
  final String? responsible;
  final String? requester;
  final String? machine;
  final String? executionMode;
  final int? executionModeId;

  /// Server-side sort column (a BAMM list-query field key, e.g.
  /// `woIssueDate`). `null` means "use the default sort"
  /// (`woIssueDate desc`) - see `BammService._buildListQueryRequest`.
  final String? sortField;
  final bool sortAscending;

  const BammFilterCriteria({
    this.searchQuery = '',
    this.status,
    this.statusId,
    this.step,
    this.stepId,
    this.maintenanceType,
    this.maintenanceTypeId,
    this.area,
    this.areaId,
    this.responsible,
    this.requester,
    this.machine,
    this.executionMode,
    this.executionModeId,
    this.sortField,
    this.sortAscending = true,
  });

  bool get isEmpty =>
      searchQuery.trim().isEmpty &&
      (status == null || status!.isEmpty || status == 'Open' || status == 'All Open') &&
      (step == null || step == 'All' || step!.isEmpty) &&
      (maintenanceType == null || maintenanceType == 'All' || maintenanceType!.isEmpty) &&
      (area == null || area == 'All' || area!.isEmpty) &&
      (responsible == null || responsible!.trim().isEmpty) &&
      (requester == null || requester!.trim().isEmpty) &&
      (machine == null || machine!.trim().isEmpty) &&
      (executionMode == null || executionMode == 'All' || executionMode!.isEmpty);

  int get activeFilterCount {
    int count = 0;
    if (searchQuery.trim().isNotEmpty) count++;
    if (status != null && status!.isNotEmpty && status != 'Open' && status != 'All Open' && status != 'All') count++;
    if (step != null && step != 'All' && step!.isNotEmpty) count++;
    if (maintenanceType != null && maintenanceType != 'All' && maintenanceType!.isNotEmpty) count++;
    if (area != null && area != 'All' && area!.isNotEmpty) count++;
    if (responsible != null && responsible!.trim().isNotEmpty) count++;
    if (requester != null && requester!.trim().isNotEmpty) count++;
    if (machine != null && machine!.trim().isNotEmpty) count++;
    if (executionMode != null && executionMode != 'All' && executionMode!.isNotEmpty) count++;
    return count;
  }

  BammFilterCriteria copyWith({
    String? searchQuery,
    String? status,
    bool clearStatus = false,
    int? statusId,
    String? step,
    bool clearStep = false,
    int? stepId,
    String? maintenanceType,
    bool clearMaintenanceType = false,
    int? maintenanceTypeId,
    String? area,
    bool clearArea = false,
    int? areaId,
    String? responsible,
    bool clearResponsible = false,
    String? requester,
    bool clearRequester = false,
    String? machine,
    bool clearMachine = false,
    String? executionMode,
    bool clearExecutionMode = false,
    int? executionModeId,
    String? sortField,
    bool clearSort = false,
    bool? sortAscending,
  }) {
    return BammFilterCriteria(
      searchQuery: searchQuery ?? this.searchQuery,
      status: clearStatus ? null : (status ?? this.status),
      statusId: clearStatus ? null : (statusId ?? this.statusId),
      step: clearStep ? null : (step ?? this.step),
      stepId: clearStep ? null : (stepId ?? this.stepId),
      maintenanceType: clearMaintenanceType ? null : (maintenanceType ?? this.maintenanceType),
      maintenanceTypeId: clearMaintenanceType ? null : (maintenanceTypeId ?? this.maintenanceTypeId),
      area: clearArea ? null : (area ?? this.area),
      areaId: clearArea ? null : (areaId ?? this.areaId),
      responsible: clearResponsible ? null : (responsible ?? this.responsible),
      requester: clearRequester ? null : (requester ?? this.requester),
      machine: clearMachine ? null : (machine ?? this.machine),
      executionMode: clearExecutionMode ? null : (executionMode ?? this.executionMode),
      executionModeId: clearExecutionMode ? null : (executionModeId ?? this.executionModeId),
      sortField: clearSort ? null : (sortField ?? this.sortField),
      sortAscending: clearSort ? true : (sortAscending ?? this.sortAscending),
    );
  }
}

/// Which BAMM table columns are shown, in what order - persisted the same
/// way as saved filters (`BammService.loadColumnLayout`/`saveColumnLayout`).
/// `hidden` holds column keys the user removed from the default visible set;
/// `order` holds every known column key (visible and hidden) in display
/// order, so a newly-added default-visible column not yet in a saved layout
/// still has somewhere to go (appended at the end by the caller).
class BammColumnLayout {
  final List<String> order;
  final Set<String> hidden;

  const BammColumnLayout({this.order = const [], this.hidden = const {}});

  Map<String, dynamic> toJson() => {'order': order, 'hidden': hidden.toList()};

  factory BammColumnLayout.fromJson(Map<String, dynamic> json) {
    final order = (json['order'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
    final hidden = (json['hidden'] as List<dynamic>? ?? const []).map((e) => e.toString()).toSet();
    return BammColumnLayout(order: order, hidden: hidden);
  }
}

/// A filter preset that can be saved and recalled.
class BammSavedFilter {
  final String id;
  final String name;
  final String searchQuery;
  final String? status;
  final int? statusId;
  final String? step;
  final int? stepId;
  final String? maintenanceType;
  final int? maintenanceTypeId;
  final String? area;
  final int? areaId;
  final String? responsible;
  final String? requester;
  final String? machine;
  final String? executionMode;

  const BammSavedFilter({
    required this.id,
    required this.name,
    this.searchQuery = '',
    this.status,
    this.statusId,
    this.step,
    this.stepId,
    this.maintenanceType,
    this.maintenanceTypeId,
    this.area,
    this.areaId,
    this.responsible,
    this.requester,
    this.machine,
    this.executionMode,
  });

  BammFilterCriteria toCriteria() {
    return BammFilterCriteria(
      searchQuery: searchQuery,
      status: status,
      statusId: statusId,
      step: step,
      stepId: stepId,
      maintenanceType: maintenanceType,
      maintenanceTypeId: maintenanceTypeId,
      area: area,
      areaId: areaId,
      responsible: responsible,
      requester: requester,
      machine: machine,
      executionMode: executionMode,
    );
  }

  factory BammSavedFilter.fromCriteria({
    required String id,
    required String name,
    required BammFilterCriteria criteria,
  }) {
    return BammSavedFilter(
      id: id,
      name: name,
      searchQuery: criteria.searchQuery,
      status: criteria.status,
      statusId: criteria.statusId,
      step: criteria.step,
      stepId: criteria.stepId,
      maintenanceType: criteria.maintenanceType,
      maintenanceTypeId: criteria.maintenanceTypeId,
      area: criteria.area,
      areaId: criteria.areaId,
      responsible: criteria.responsible,
      requester: criteria.requester,
      machine: criteria.machine,
      executionMode: criteria.executionMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'searchQuery': searchQuery,
      'status': status,
      'statusId': statusId,
      'step': step,
      'stepId': stepId,
      'maintenanceType': maintenanceType,
      'maintenanceTypeId': maintenanceTypeId,
      'area': area,
      'areaId': areaId,
      'responsible': responsible,
      'requester': requester,
      'machine': machine,
      'executionMode': executionMode,
    };
  }

  factory BammSavedFilter.fromJson(Map<String, dynamic> json) {
    return BammSavedFilter(
      id: json['id'] as String? ?? UniqueKey().toString(),
      name: json['name'] as String? ?? 'Filter',
      searchQuery: json['searchQuery'] as String? ?? '',
      status: json['status'] as String?,
      statusId: (json['statusId'] as num?)?.toInt(),
      step: json['step'] as String?,
      stepId: (json['stepId'] as num?)?.toInt(),
      maintenanceType: json['maintenanceType'] as String?,
      maintenanceTypeId: (json['maintenanceTypeId'] as num?)?.toInt(),
      area: json['area'] as String? ?? json['cell'] as String?,
      areaId: (json['areaId'] as num?)?.toInt(),
      responsible: json['responsible'] as String?,
      requester: json['requester'] as String?,
      machine: json['machine'] as String?,
      executionMode: json['executionMode'] as String?,
    );
  }
}

/// Host and credential settings for BAMM connection.
class BammConnectionConfig {
  final String origin;
  final String usercode;
  final String password;
  final int companyId;
  final int spwId;

  const BammConnectionConfig({
    this.origin = 'http://app02-ao-plt:82',
    this.usercode = '',
    this.password = '',
    this.companyId = 3,
    this.spwId = 700000027,
  });

  BammConnectionConfig copyWith({
    String? origin,
    String? usercode,
    String? password,
    int? companyId,
    int? spwId,
  }) {
    return BammConnectionConfig(
      origin: origin ?? this.origin,
      usercode: usercode ?? this.usercode,
      password: password ?? this.password,
      companyId: companyId ?? this.companyId,
      spwId: spwId ?? this.spwId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'origin': origin,
      'usercode': usercode,
      'password': password,
      'companyId': companyId,
      'spwId': spwId,
    };
  }

  factory BammConnectionConfig.fromJson(Map<String, dynamic> json) {
    return BammConnectionConfig(
      origin: json['origin'] as String? ?? 'http://app02-ao-plt:82',
      usercode: json['usercode'] as String? ?? '',
      password: json['password'] as String? ?? '',
      companyId: (json['companyId'] as num?)?.toInt() ?? 3,
      spwId: (json['spwId'] as num?)?.toInt() ?? 700000027,
    );
  }
}
