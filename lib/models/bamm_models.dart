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
  final String cell;
  final String machine;
  final String assetId;
  final String priority;
  final String responsible;
  final String requester;
  final DateTime? issueDate;
  final DateTime? requiredDate;
  final double? laborHours;
  final int? requiredEmployees;
  final String executionMode;
  final Map<String, dynamic>? rawDto;

  const BammWorkOrder({
    required this.worId,
    required this.worNoSeq,
    required this.description,
    this.status = 'Registered',
    this.statusId,
    this.step = 'Normal',
    this.stepId,
    this.cell = '',
    this.machine = '',
    this.assetId = '',
    this.priority = '',
    this.responsible = '',
    this.requester = '',
    this.issueDate,
    this.requiredDate,
    this.laborHours,
    this.requiredEmployees,
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
    String? cell,
    String? machine,
    String? assetId,
    String? priority,
    String? responsible,
    String? requester,
    DateTime? issueDate,
    DateTime? requiredDate,
    double? laborHours,
    int? requiredEmployees,
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
      cell: cell ?? this.cell,
      machine: machine ?? this.machine,
      assetId: assetId ?? this.assetId,
      priority: priority ?? this.priority,
      responsible: responsible ?? this.responsible,
      requester: requester ?? this.requester,
      issueDate: issueDate ?? this.issueDate,
      requiredDate: requiredDate ?? this.requiredDate,
      laborHours: laborHours ?? this.laborHours,
      requiredEmployees: requiredEmployees ?? this.requiredEmployees,
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
      'cell': cell,
      'machine': machine,
      'assetId': assetId,
      'priority': priority,
      'responsible': responsible,
      'requester': requester,
      'issueDate': issueDate?.toIso8601String(),
      'requiredDate': requiredDate?.toIso8601String(),
      'laborHours': laborHours,
      'requiredEmployees': requiredEmployees,
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
      cell: json['cell']?.toString() ?? '',
      machine: json['machine']?.toString() ?? '',
      assetId: json['assetId']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
      responsible: json['responsible']?.toString() ?? '',
      requester: json['requester']?.toString() ?? '',
      issueDate: parseDate(json['issueDate']),
      requiredDate: parseDate(json['requiredDate']),
      laborHours: (json['laborHours'] as num?)?.toDouble(),
      requiredEmployees: (json['requiredEmployees'] as num?)?.toInt(),
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

    return BammWorkOrder(
      worId: worId,
      worNoSeq: worNo.isNotEmpty ? worNo : (worId > 0 ? worId.toString() : 'Unknown'),
      description: (p['woDescription'] ?? p['WOR_TEXT'] ?? p['WOR_DESCR'] ?? p['description'] ?? '').toString(),
      status: (p['woStatusDescription'] ?? p['WOR_STATUS_DESC'] ?? p['status'] ?? 'Registered').toString(),
      statusId: (p['woStatusId'] ?? p['WOR_STATUS_ID'] as num?)?.toInt(),
      step: (p['woStepDescription'] ?? p['WOR_STEP_DESC'] ?? p['step'] ?? 'Normal').toString(),
      stepId: (p['woStepId'] ?? p['WOR_STEP_ID'] as num?)?.toInt(),
      cell: (p['functionInfo2'] ?? p['WOR_DEPARTMENT_CODE'] ?? p['cell'] ?? '').toString(),
      machine: (p['funCodeLevelNiv3Description'] ?? p['WOR_EQUIPMENT_CODE'] ?? p['machine'] ?? '').toString(),
      assetId: (p['functionCode'] ?? p['FUN_ID'] ?? p['assetId'] ?? '').toString(),
      priority: (p['worNumber3'] ?? p['WOR_PRIORITY_DESC'] ?? p['PRI_ID'] ?? '').toString(),
      responsible: (p['recipientName'] ?? p['WOR_RESPONSIBLE_NAME'] ?? p['responsible'] ?? '').toString(),
      requester: (p['requesterName'] ?? p['WOR_REQUESTER_NAME'] ?? p['requester'] ?? '').toString(),
      issueDate: parseDate(p['woIssueDate'] ?? p['WOR_ISSUE_DATE']),
      requiredDate: parseDate(p['woRequiredDate'] ?? p['WOR_REQUIRED_DATE']),
      laborHours: (p['worEstLaborTime'] ?? p['WOR_EST_LABOR_HOURS'] as num?)?.toDouble(),
      requiredEmployees: (p['worEstNbEmployee'] ?? p['WOR_EST_NB_EMPLOYEE'] as num?)?.toInt(),
      executionMode: (p['executionModeDescription'] ?? '').toString(),
      rawDto: raw,
    );
  }
}

/// A filter preset that can be saved and recalled.
class BammSavedFilter {
  final String id;
  final String name;
  final String searchQuery;
  final String? status;
  final String? step;
  final String? cell;
  final String? responsible;

  const BammSavedFilter({
    required this.id,
    required this.name,
    this.searchQuery = '',
    this.status,
    this.step,
    this.cell,
    this.responsible,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'searchQuery': searchQuery,
      'status': status,
      'step': step,
      'cell': cell,
      'responsible': responsible,
    };
  }

  factory BammSavedFilter.fromJson(Map<String, dynamic> json) {
    return BammSavedFilter(
      id: json['id'] as String? ?? UniqueKey().toString(),
      name: json['name'] as String? ?? 'Filter',
      searchQuery: json['searchQuery'] as String? ?? '',
      status: json['status'] as String?,
      step: json['step'] as String?,
      cell: json['cell'] as String?,
      responsible: json['responsible'] as String?,
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
