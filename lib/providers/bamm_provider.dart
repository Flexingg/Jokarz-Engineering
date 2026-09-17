import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bamm_models.dart';
import '../services/bamm_adapter.dart' show resolveWorkOrderLabels;
import '../services/bamm_service.dart';

final bammServiceProvider = Provider<BammService>((ref) {
  return BammService();
});

class BammState {
  final bool isOnline;
  final bool isPolling;
  final DateTime? lastChecked;
  final BammConnectionConfig config;
  final List<BammWorkOrder> workOrders;
  final List<BammSavedFilter> savedFilters;
  final BammSavedFilter? activeFilter;
  final BammFilterCriteria criteria;
  final List<BammLookupItem> statusLookups;
  final List<BammLookupItem> stepLookups;
  final List<BammLookupItem> maintLookups;
  final List<BammLookupItem> areaLookups;
  final List<BammLookupItem> execLookups;
  final BammColumnLayout columnLayout;
  final bool isLoading;
  final String? errorMessage;

  /// The server-reported total for the most recent list query - `null`
  /// until a query has run. Lets the UI show a truncation warning instead of
  /// silently capping at `topCount` (2000) with no indication more exist.
  final int? lastQueryTotal;

  const BammState({
    this.isOnline = false,
    this.isPolling = false,
    this.lastChecked,
    this.config = const BammConnectionConfig(),
    this.workOrders = const [],
    this.savedFilters = const [],
    this.activeFilter,
    this.criteria = const BammFilterCriteria(),
    this.statusLookups = const [],
    this.stepLookups = const [],
    this.maintLookups = const [],
    this.areaLookups = const [],
    this.execLookups = const [],
    this.columnLayout = const BammColumnLayout(),
    this.isLoading = false,
    this.errorMessage,
    this.lastQueryTotal,
  });

  /// True when the server reports more rows exist than the current page
  /// (capped at `topCount` = 2000) actually returned.
  bool get isTruncated => lastQueryTotal != null && lastQueryTotal! > workOrders.length;

  // Backwards compatibility getters
  String get searchQuery => criteria.searchQuery;
  String? get statusFilter => criteria.status;
  String? get stepFilter => criteria.step;
  String? get areaFilter => criteria.area;

  BammState copyWith({
    bool? isOnline,
    bool? isPolling,
    DateTime? lastChecked,
    BammConnectionConfig? config,
    List<BammWorkOrder>? workOrders,
    List<BammSavedFilter>? savedFilters,
    BammSavedFilter? activeFilter,
    bool clearActiveFilter = false,
    BammFilterCriteria? criteria,
    List<BammLookupItem>? statusLookups,
    List<BammLookupItem>? stepLookups,
    List<BammLookupItem>? maintLookups,
    List<BammLookupItem>? areaLookups,
    List<BammLookupItem>? execLookups,
    BammColumnLayout? columnLayout,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    int? lastQueryTotal,
    bool clearLastQueryTotal = false,
  }) {
    return BammState(
      isOnline: isOnline ?? this.isOnline,
      isPolling: isPolling ?? this.isPolling,
      lastChecked: lastChecked ?? this.lastChecked,
      config: config ?? this.config,
      workOrders: workOrders ?? this.workOrders,
      savedFilters: savedFilters ?? this.savedFilters,
      activeFilter: clearActiveFilter ? null : (activeFilter ?? this.activeFilter),
      criteria: criteria ?? this.criteria,
      statusLookups: statusLookups ?? this.statusLookups,
      stepLookups: stepLookups ?? this.stepLookups,
      maintLookups: maintLookups ?? this.maintLookups,
      areaLookups: areaLookups ?? this.areaLookups,
      execLookups: execLookups ?? this.execLookups,
      columnLayout: columnLayout ?? this.columnLayout,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      lastQueryTotal: clearLastQueryTotal ? null : (lastQueryTotal ?? this.lastQueryTotal),
    );
  }

  /// List of work orders matching current query.
  /// When online, server queries execute filters directly against all 196k+ work orders.
  /// Local in-memory fallback applies only when offline.
  List<BammWorkOrder> get filteredWorkOrders {
    if (criteria.isEmpty) return workOrders;
    if (isOnline) return workOrders; // Server already filtered the results!

    // Fallback offline filter
    return workOrders.where((wo) {
      if (criteria.searchQuery.trim().isNotEmpty) {
        final q = criteria.searchQuery.trim().toLowerCase();
        final match = wo.worNoSeq.toLowerCase().contains(q) ||
            wo.description.toLowerCase().contains(q) ||
            wo.area.toLowerCase().contains(q) ||
            wo.machine.toLowerCase().contains(q) ||
            wo.responsible.toLowerCase().contains(q) ||
            wo.requester.toLowerCase().contains(q) ||
            wo.workDone.toLowerCase().contains(q) ||
            wo.status.toLowerCase().contains(q);
        if (!match) return false;
      }

      final status = criteria.status?.trim() ?? '';
      if (status.isEmpty || status.toLowerCase() == 'all open' || status.toLowerCase() == 'open') {
        final s = wo.status.toLowerCase();
        if (s.contains('complet') || s.contains('close') || s.contains('cancel') || s.contains('declin')) {
          return false;
        }
      } else if (status.toLowerCase() != 'all' && status.toLowerCase() != 'all (including closed)') {
        if (wo.status.toLowerCase() != status.toLowerCase()) return false;
      }

      if (criteria.step != null && criteria.step!.isNotEmpty && criteria.step != 'All') {
        if (!wo.step.toLowerCase().contains(criteria.step!.toLowerCase())) return false;
      }

      final area = criteria.area;
      if (area != null && area.isNotEmpty && area != 'All') {
        if (!wo.area.toLowerCase().contains(area.toLowerCase())) return false;
      }

      if (criteria.maintenanceType != null &&
          criteria.maintenanceType!.isNotEmpty &&
          criteria.maintenanceType != 'All') {
        if (wo.maintenanceType.isNotEmpty &&
            !wo.maintenanceType.toLowerCase().contains(criteria.maintenanceType!.toLowerCase())) {
          return false;
        }
      }

      if (criteria.executionMode != null &&
          criteria.executionMode!.isNotEmpty &&
          criteria.executionMode != 'All') {
        if (wo.executionMode.isNotEmpty &&
            !wo.executionMode.toLowerCase().contains(criteria.executionMode!.toLowerCase())) {
          return false;
        }
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

  int get emergencyCount => workOrders.where((w) => w.step.toLowerCase().contains('emerg')).length;
  int get openCount => workOrders.where((w) {
    final s = w.status.toLowerCase();
    return !s.contains('complet') && !s.contains('clos') && !s.contains('cancel') && !s.contains('declin');
  }).length;
}

class BammNotifier extends StateNotifier<BammState> {
  final BammService _service;
  Timer? _autoPollTimer;
  Timer? _debounceTimer;

  /// Monotonically increasing id for [refreshWorkOrders] - every list query
  /// (search debounce, filter setters, sort, pull-to-refresh, poll button)
  /// funnels through that one method, so a single guard here is enough to
  /// drop a superseded response even when several queries end up in flight
  /// at once (e.g. "Apply Filters" firing several setters back to back).
  int _requestId = 0;

  BammNotifier(this._service) : super(const BammState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    final loadedConfig = await _service.loadConfig();
    final savedFilters = await _service.loadSavedFilters();
    final columnLayout = await _service.loadColumnLayout();

    state = state.copyWith(
      config: loadedConfig,
      savedFilters: savedFilters,
      columnLayout: columnLayout,
      // Default view on boot: all OPEN work orders (the server-side default
      // when `status` is unset) whose step is Emergency - matches the
      // existing "Emergency" saved-filter preset (`_getDefaultSavedFilters`).
      criteria: const BammFilterCriteria(step: 'Emergency', stepId: 3),
    );

    // Initial quick poll & load lookup dropdown options
    final online = await pollNetwork();
    await loadLookups();

    // Query BAMM with default criteria (latest 2000 descending by WO#)
    if (online) {
      await refreshWorkOrders();
    } else {
      state = state.copyWith(isLoading: false);
    }

    // Setup background periodic polling every 20 seconds
    _autoPollTimer?.cancel();
    _autoPollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      pollNetwork();
    });
  }

  @override
  void dispose() {
    _autoPollTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Quickly poll network to see if BAMM is on the current network
  Future<bool> pollNetwork() async {
    state = state.copyWith(isPolling: true);
    final online = await _service.quickPollNetwork();
    state = state.copyWith(
      isOnline: online,
      isPolling: false,
      lastChecked: _service.lastChecked,
    );
    return online;
  }

  /// Loads lookup lists for dropdowns (statuses, steps, maintenance types, areas, execution modes)
  Future<void> loadLookups() async {
    try {
      final statuses = await _service.fetchLookup('GetWorkOrderStatus');
      final steps = await _service.fetchLookup('GetWorkOrderStep');
      final maints = await _service.fetchLookup('GetMaintenanceType');
      final areas = await _service.fetchLookup('GetGrouping1');
      final execs = await _service.fetchLookup('GetExecutionMode');

      state = state.copyWith(
        statusLookups: statuses,
        stepLookups: steps,
        maintLookups: maints,
        areaLookups: areas,
        execLookups: execs,
      );
    } catch (e) {
      debugPrint('Error loading BAMM lookups: $e');
    }
  }

  /// Executes a query against BAMM with current criteria or refreshes
  /// default list. The single funnel point for every list query - see
  /// [_requestId].
  Future<void> refreshWorkOrders() async {
    final myRequestId = ++_requestId;
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final list = await _service.fetchWorkOrders(
        criteria: state.criteria,
        statusLookups: state.statusLookups,
        stepLookups: state.stepLookups,
      );
      if (myRequestId != _requestId) return; // superseded by a newer query
      state = state.copyWith(
        workOrders: list,
        isLoading: false,
        lastQueryTotal: _service.lastQueryTotal,
        clearLastQueryTotal: _service.lastQueryTotal == null,
      );
    } catch (e) {
      if (myRequestId != _requestId) return; // superseded by a newer query
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Updates criteria and runs server-side query across 196k+ work orders.
  void setCriteria(BammFilterCriteria criteria) {
    state = state.copyWith(criteria: criteria);
    _debouncedQuery();
  }

  void _debouncedQuery() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      refreshWorkOrders();
    });
  }

  /// Updates the search query and immediately queries BAMM.
  void setSearchQuery(String query) {
    state = state.copyWith(
      criteria: state.criteria.copyWith(searchQuery: query),
    );
    _debouncedQuery();
  }

  /// Filter by Status dropdown
  void setStatusFilter(String? status, [int? statusId]) {
    final clear = status == null || status.isEmpty;
    state = state.copyWith(
      criteria: state.criteria.copyWith(
        status: status,
        clearStatus: clear,
        statusId: statusId,
      ),
    );
    refreshWorkOrders();
  }

  /// Filter by Step / Urgency dropdown
  void setStepFilter(String? step, [int? stepId]) {
    final clear = step == null || step.isEmpty || step == 'All';
    state = state.copyWith(
      criteria: state.criteria.copyWith(
        step: step,
        clearStep: clear,
        stepId: stepId,
      ),
    );
    refreshWorkOrders();
  }

  /// Filter by Maintenance Type dropdown
  void setMaintenanceTypeFilter(String? maint, [int? maintId]) {
    final clear = maint == null || maint.isEmpty || maint == 'All';
    state = state.copyWith(
      criteria: state.criteria.copyWith(
        maintenanceType: maint,
        clearMaintenanceType: clear,
        maintenanceTypeId: maintId,
      ),
    );
    refreshWorkOrders();
  }

  /// Filter by Area (replaces old cell filter)
  void setAreaFilter(String? area, [int? areaId]) {
    final clear = area == null || area.isEmpty || area == 'All';
    state = state.copyWith(
      criteria: state.criteria.copyWith(
        area: area,
        areaId: areaId,
        clearArea: clear,
      ),
    );
    refreshWorkOrders();
  }

  /// Filter by Responsible Person
  void setResponsibleFilter(String? resp) {
    final clear = resp == null || resp.trim().isEmpty;
    state = state.copyWith(
      criteria: state.criteria.copyWith(
        responsible: resp,
        clearResponsible: clear,
      ),
    );
    _debouncedQuery();
  }

  /// Filter by Requester Person
  void setRequesterFilter(String? req) {
    final clear = req == null || req.trim().isEmpty;
    state = state.copyWith(
      criteria: state.criteria.copyWith(
        requester: req,
        clearRequester: clear,
      ),
    );
    _debouncedQuery();
  }

  /// Filter by Machine / Equipment
  void setMachineFilter(String? machine) {
    final clear = machine == null || machine.trim().isEmpty;
    state = state.copyWith(
      criteria: state.criteria.copyWith(
        machine: machine,
        clearMachine: clear,
      ),
    );
    _debouncedQuery();
  }

  /// Filter by Machine Status / Execution Mode
  void setExecutionModeFilter(String? exec, [int? execId]) {
    final clear = exec == null || exec.isEmpty || exec == 'All';
    state = state.copyWith(
      criteria: state.criteria.copyWith(
        executionMode: exec,
        clearExecutionMode: clear,
        executionModeId: execId,
      ),
    );
    refreshWorkOrders();
  }

  /// Cycles the sort on [columnKey]: unsorted -> ascending -> descending ->
  /// back to unsorted (the server default, `woIssueDate desc`). Sorting is
  /// always server-side (`orderByFields`), matching every other BAMM list
  /// query in this app - there is no client-side fallback to keep in sync
  /// with the server's ordering.
  void setSort(String columnKey) {
    final current = state.criteria;
    String? nextField;
    bool nextAscending = true;
    if (current.sortField != columnKey) {
      nextField = columnKey;
      nextAscending = true;
    } else if (current.sortAscending) {
      nextField = columnKey;
      nextAscending = false;
    } else {
      nextField = null;
      nextAscending = true;
    }
    state = state.copyWith(
      criteria: current.copyWith(sortField: nextField, clearSort: nextField == null, sortAscending: nextAscending),
    );
    refreshWorkOrders();
  }

  /// Sets the sort explicitly (used by the header context menu's "Sort
  /// ascending"/"Sort descending", which must not depend on the current
  /// state the way [setSort]'s click-to-cycle does).
  void setSortField(String columnKey, {required bool ascending}) {
    state = state.copyWith(criteria: state.criteria.copyWith(sortField: columnKey, sortAscending: ascending));
    refreshWorkOrders();
  }

  /// Persists the given column order/visibility and applies it immediately.
  Future<void> setColumnLayout(BammColumnLayout layout) async {
    state = state.copyWith(columnLayout: layout);
    await _service.saveColumnLayout(layout);
  }

  /// Clears all active filters and queries the latest 2000 records.
  void clearFilters() {
    state = state.copyWith(
      criteria: const BammFilterCriteria(),
      clearActiveFilter: true,
    );
    refreshWorkOrders();
  }

  /// Apply a saved filter preset
  void applySavedFilter(BammSavedFilter? filter) {
    if (filter == null) {
      clearFilters();
    } else {
      state = state.copyWith(
        activeFilter: filter,
        criteria: filter.toCriteria(),
      );
      refreshWorkOrders();
    }
  }

  /// Saves the current filter state as a new preset
  Future<void> saveCurrentFilterAsPreset(String name) async {
    if (name.trim().isEmpty) return;
    final newFilter = BammSavedFilter.fromCriteria(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      criteria: state.criteria,
    );

    final updated = [...state.savedFilters, newFilter];
    state = state.copyWith(
      savedFilters: updated,
      activeFilter: newFilter,
    );
    await _service.saveSavedFilters(updated);
  }

  /// Delete a saved filter preset
  Future<void> deleteSavedFilter(String filterId) async {
    final updated = state.savedFilters.where((f) => f.id != filterId).toList();
    final wasActive = state.activeFilter?.id == filterId;
    state = state.copyWith(
      savedFilters: updated,
      clearActiveFilter: wasActive,
    );
    await _service.saveSavedFilters(updated);
  }

  /// Resolves [detail]'s status/step ids against the live lookups already in
  /// state, then merges the result onto the matching list row (if any) so
  /// list-only display columns (worNoSeq's "WO-x.y" form, area, machine,
  /// responsible, requester, ...) survive - `GetById` structurally cannot
  /// carry them (see `BammWorkOrder.fromDynamicDto`'s doc comment). This is
  /// the fix for the regression where tapping/editing a row overwrote it
  /// with a `GetById` model that looked plausible but was missing or wrong.
  BammWorkOrder _resolveAndMerge(BammWorkOrder detail) {
    final resolved = resolveWorkOrderLabels(
      detail,
      statusLookups: state.statusLookups,
      stepLookups: state.stepLookups,
    );
    final existing = state.workOrders.where((w) => w.worId == detail.worId).firstOrNull;
    return existing != null ? existing.mergeDetail(resolved) : resolved;
  }

  /// Fetches individual detail for a single work order on click.
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async {
    final detail = await _service.fetchWorkOrderDetail(worId);
    if (detail != null) {
      final merged = _resolveAndMerge(detail);
      final updatedList = state.workOrders.map((w) => w.worId == worId ? merged : w).toList();
      state = state.copyWith(workOrders: updatedList);
      return merged;
    }
    return detail;
  }

  /// Creates a new Work Order on BAMM
  Future<BammWorkOrder> createWorkOrder({
    required String description,
    String assetId = '',
    int maintenanceTypeId = 107,
    int stepId = 1,
    String priority = '1.0',
    DateTime? requiredDate,
    String responsible = '',
    String area = '',
    String machine = '',
    double? laborHours,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final created = await _service.createWorkOrder(
        description: description,
        assetId: assetId,
        maintenanceTypeId: maintenanceTypeId,
        stepId: stepId,
        priority: priority,
        requiredDate: requiredDate,
        responsible: responsible,
        area: area,
        machine: machine,
        laborHours: laborHours,
      );

      final updatedList = [created, ...state.workOrders.where((w) => w.worId != created.worId)];
      state = state.copyWith(workOrders: updatedList, isLoading: false);
      return created;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Updates an existing Work Order. Returns the honest outcome - the caller
  /// must check `writeResult` rather than assuming a returned value means
  /// every field landed (see `BammUpdateOutcome`).
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
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final outcome = await _service.updateWorkOrder(
        worId: worId,
        description: description,
        workDone: workDone,
        responsible: responsible,
        requiredDate: requiredDate,
        installStart: installStart,
        installEnd: installEnd,
        classificationId: classificationId,
        skillId: skillId,
        classificationTableId: classificationTableId,
        crewShiftId: crewShiftId,
        requiredEmployees: requiredEmployees,
        stepId: stepId,
        maintenanceTypeId: maintenanceTypeId,
        executionModeId: executionModeId,
        priorityEm: priorityEm,
        assetId: assetId,
      );

      final merged = _resolveAndMerge(outcome.workOrder);
      final updatedList = state.workOrders.map((w) => w.worId == worId ? merged : w).toList();
      state = state.copyWith(workOrders: updatedList, isLoading: false);

      // A save must not leave the table showing stale data - re-run the list
      // query so the row's list-only display columns (and any other row a
      // filter/sort now excludes or includes) reflect BAMM's own state.
      await refreshWorkOrders();

      return BammUpdateOutcome(workOrder: merged, writeResult: outcome.writeResult);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  Future<BammAddActivityLineOutcome> addActivityLine({
    required int worId,
    required String activityId,
    required String subActivityId,
    String? description,
    double? hours,
    String? memo,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final outcome = await _service.addActivityLine(
        worId: worId,
        activityId: activityId,
        subActivityId: subActivityId,
        description: description,
        hours: hours,
        memo: memo,
      );
      final merged = _resolveAndMerge(outcome.workOrder);
      final updatedList = state.workOrders.map((w) => w.worId == worId ? merged : w).toList();
      state = state.copyWith(workOrders: updatedList, isLoading: false);
      return BammAddActivityLineOutcome(workOrder: merged, added: outcome.added);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Update connection config
  Future<void> updateConfig(BammConnectionConfig newConfig) async {
    await _service.saveConfig(newConfig);
    state = state.copyWith(config: newConfig);
    await pollNetwork();
    await loadLookups();
    await refreshWorkOrders();
  }
}

final bammProvider = StateNotifierProvider<BammNotifier, BammState>((ref) {
  final service = ref.watch(bammServiceProvider);
  return BammNotifier(service);
});
