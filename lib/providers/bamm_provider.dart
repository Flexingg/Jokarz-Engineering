import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bamm_models.dart';
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
  final String searchQuery;
  final String? statusFilter;
  final String? stepFilter;
  final String? cellFilter;
  final bool isLoading;
  final String? errorMessage;

  const BammState({
    this.isOnline = false,
    this.isPolling = false,
    this.lastChecked,
    this.config = const BammConnectionConfig(),
    this.workOrders = const [],
    this.savedFilters = const [],
    this.activeFilter,
    this.searchQuery = '',
    this.statusFilter,
    this.stepFilter,
    this.cellFilter,
    this.isLoading = false,
    this.errorMessage,
  });

  BammState copyWith({
    bool? isOnline,
    bool? isPolling,
    DateTime? lastChecked,
    BammConnectionConfig? config,
    List<BammWorkOrder>? workOrders,
    List<BammSavedFilter>? savedFilters,
    BammSavedFilter? activeFilter,
    bool clearActiveFilter = false,
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? stepFilter,
    bool clearStepFilter = false,
    String? cellFilter,
    bool clearCellFilter = false,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return BammState(
      isOnline: isOnline ?? this.isOnline,
      isPolling: isPolling ?? this.isPolling,
      lastChecked: lastChecked ?? this.lastChecked,
      config: config ?? this.config,
      workOrders: workOrders ?? this.workOrders,
      savedFilters: savedFilters ?? this.savedFilters,
      activeFilter: clearActiveFilter ? null : (activeFilter ?? this.activeFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      stepFilter: clearStepFilter ? null : (stepFilter ?? this.stepFilter),
      cellFilter: clearCellFilter ? null : (cellFilter ?? this.cellFilter),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  List<BammWorkOrder> get filteredWorkOrders {
    return workOrders.where((wo) {
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchesQuery = wo.worNoSeq.toLowerCase().contains(q) ||
            wo.description.toLowerCase().contains(q) ||
            wo.cell.toLowerCase().contains(q) ||
            wo.machine.toLowerCase().contains(q) ||
            wo.responsible.toLowerCase().contains(q) ||
            wo.requester.toLowerCase().contains(q) ||
            wo.status.toLowerCase().contains(q);
        if (!matchesQuery) return false;
      }

      if (statusFilter != null && statusFilter!.isNotEmpty && statusFilter != 'All') {
        if (wo.status.toLowerCase() != statusFilter!.toLowerCase()) {
          return false;
        }
      }

      if (stepFilter != null && stepFilter!.isNotEmpty && stepFilter != 'All') {
        if (wo.step.toLowerCase() != stepFilter!.toLowerCase()) {
          return false;
        }
      }

      if (cellFilter != null && cellFilter!.isNotEmpty && cellFilter != 'All') {
        if (!wo.cell.toLowerCase().contains(cellFilter!.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  int get emergencyCount => workOrders.where((w) => w.step.toLowerCase().contains('emerg')).length;
  int get openCount => workOrders.where((w) => !w.status.toLowerCase().contains('complet')).length;
}

class BammNotifier extends StateNotifier<BammState> {
  final BammService _service;
  Timer? _autoPollTimer;

  BammNotifier(this._service) : super(const BammState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    final loadedConfig = await _service.loadConfig();
    final savedFilters = await _service.loadSavedFilters();
    final cachedOrders = await _service.loadCachedWorkOrders();

    state = state.copyWith(
      config: loadedConfig,
      savedFilters: savedFilters,
      workOrders: cachedOrders,
    );

    // Initial quick poll
    await pollNetwork();
    await refreshWorkOrders();

    // Setup background periodic polling every 20 seconds
    _autoPollTimer?.cancel();
    _autoPollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      pollNetwork();
    });
  }

  @override
  void dispose() {
    _autoPollTimer?.cancel();
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

  /// Refresh work orders (hits BAMM API if online, loads cached if offline)
  Future<void> refreshWorkOrders() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final list = await _service.fetchWorkOrders();
      state = state.copyWith(
        workOrders: list,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Apply a saved filter preset
  void applySavedFilter(BammSavedFilter? filter) {
    if (filter == null) {
      state = state.copyWith(
        clearActiveFilter: true,
        clearStatusFilter: true,
        clearStepFilter: true,
        clearCellFilter: true,
        searchQuery: '',
      );
    } else {
      state = state.copyWith(
        activeFilter: filter,
        searchQuery: filter.searchQuery,
        statusFilter: filter.status,
        stepFilter: filter.step,
        cellFilter: filter.cell,
      );
    }
  }

  /// Saves the current filter state as a new preset
  Future<void> saveCurrentFilterAsPreset(String name) async {
    if (name.trim().isEmpty) return;
    final newFilter = BammSavedFilter(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      searchQuery: state.searchQuery,
      status: state.statusFilter,
      step: state.stepFilter,
      cell: state.cellFilter,
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

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String? status) {
    if (status == null || status.isEmpty || status == 'All') {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: status);
    }
  }

  void setStepFilter(String? step) {
    if (step == null || step.isEmpty || step == 'All') {
      state = state.copyWith(clearStepFilter: true);
    } else {
      state = state.copyWith(stepFilter: step);
    }
  }

  void setCellFilter(String? cell) {
    if (cell == null || cell.isEmpty || cell == 'All') {
      state = state.copyWith(clearCellFilter: true);
    } else {
      state = state.copyWith(cellFilter: cell);
    }
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      clearStatusFilter: true,
      clearStepFilter: true,
      clearCellFilter: true,
      clearActiveFilter: true,
    );
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
    String cell = '',
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
        cell: cell,
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

  /// Updates an existing Work Order
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
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final updated = await _service.updateWorkOrder(
        worId: worId,
        description: description,
        status: status,
        step: step,
        priority: priority,
        requiredDate: requiredDate,
        cell: cell,
        machine: machine,
        responsible: responsible,
        laborHours: laborHours,
      );

      final updatedList = state.workOrders.map((w) => w.worId == worId ? updated : w).toList();
      state = state.copyWith(workOrders: updatedList, isLoading: false);
      return updated;
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
    await refreshWorkOrders();
  }
}

final bammProvider = StateNotifierProvider<BammNotifier, BammState>((ref) {
  final service = ref.watch(bammServiceProvider);
  return BammNotifier(service);
});
