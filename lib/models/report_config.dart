/// Sort order for the top-projects section of a report.
enum ReportSort { priority, cost, nextAction }

/// Configuration for the customizable report generator.
class ReportConfig {
  final bool showPriority;
  final bool showOrders;
  final bool showDueToday;
  final bool showNotes;
  final bool showStores;
  final bool showCost;
  final bool showClosed;
  final int ordersDueDays;
  final int notTouchedDays;
  final int topProjectsLimit;
  final int maxOrders;
  final ReportSort sortBy;
  final bool groupByMachine;
  final bool includeCompleted;

  const ReportConfig({
    this.showPriority = true,
    this.showOrders = true,
    this.showDueToday = true,
    this.showNotes = true,
    this.showStores = true,
    this.showCost = true,
    this.showClosed = false,
    this.ordersDueDays = 5,
    this.notTouchedDays = 7,
    this.topProjectsLimit = 10,
    this.maxOrders = 10,
    this.sortBy = ReportSort.priority,
    this.groupByMachine = false,
    this.includeCompleted = false,
  });

  ReportConfig copyWith({
    bool? showPriority,
    bool? showOrders,
    bool? showDueToday,
    bool? showNotes,
    bool? showStores,
    bool? showCost,
    bool? showClosed,
    int? ordersDueDays,
    int? notTouchedDays,
    int? topProjectsLimit,
    int? maxOrders,
    ReportSort? sortBy,
    bool? groupByMachine,
    bool? includeCompleted,
  }) {
    return ReportConfig(
      showPriority: showPriority ?? this.showPriority,
      showOrders: showOrders ?? this.showOrders,
      showDueToday: showDueToday ?? this.showDueToday,
      showNotes: showNotes ?? this.showNotes,
      showStores: showStores ?? this.showStores,
      showCost: showCost ?? this.showCost,
      showClosed: showClosed ?? this.showClosed,
      ordersDueDays: ordersDueDays ?? this.ordersDueDays,
      notTouchedDays: notTouchedDays ?? this.notTouchedDays,
      topProjectsLimit: topProjectsLimit ?? this.topProjectsLimit,
      maxOrders: maxOrders ?? this.maxOrders,
      sortBy: sortBy ?? this.sortBy,
      groupByMachine: groupByMachine ?? this.groupByMachine,
      includeCompleted: includeCompleted ?? this.includeCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'showPriority': showPriority,
        'showOrders': showOrders,
        'showDueToday': showDueToday,
        'showNotes': showNotes,
        'showStores': showStores,
        'showCost': showCost,
        'showClosed': showClosed,
        'ordersDueDays': ordersDueDays,
        'notTouchedDays': notTouchedDays,
        'topProjectsLimit': topProjectsLimit,
        'maxOrders': maxOrders,
        'sortBy': sortBy.name,
        'groupByMachine': groupByMachine,
        'includeCompleted': includeCompleted,
      };

  factory ReportConfig.fromJson(Map<String, dynamic> json) {
    ReportSort parseSort(dynamic v) {
      for (final s in ReportSort.values) {
        if (s.name == v) return s;
      }
      return ReportSort.priority;
    }

    int intOr(dynamic v, int def) => v is int ? v : (v is num ? v.toInt() : def);
    bool boolOr(dynamic v, bool def) => v is bool ? v : def;

    return ReportConfig(
      showPriority: boolOr(json['showPriority'], true),
      showOrders: boolOr(json['showOrders'], true),
      showDueToday: boolOr(json['showDueToday'], true),
      showNotes: boolOr(json['showNotes'], true),
      showStores: boolOr(json['showStores'], true),
      showCost: boolOr(json['showCost'], true),
      showClosed: boolOr(json['showClosed'], false),
      ordersDueDays: intOr(json['ordersDueDays'], 5),
      notTouchedDays: intOr(json['notTouchedDays'], 7),
      topProjectsLimit: intOr(json['topProjectsLimit'], 10),
      maxOrders: intOr(json['maxOrders'], 10),
      sortBy: parseSort(json['sortBy']),
      groupByMachine: boolOr(json['groupByMachine'], false),
      includeCompleted: boolOr(json['includeCompleted'], false),
    );
  }
}
