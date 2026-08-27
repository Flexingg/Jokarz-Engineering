import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/task_item.dart';
import '../models/order_item.dart';
import '../models/project_log.dart';
import '../models/voice_note.dart';
import '../models/filament_profile.dart';
import '../models/standalone_order.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class OpenOrderEntry {
  final Project project;
  final OrderItem order;

  const OpenOrderEntry({required this.project, required this.order});
}

class EngineeringState {
  final List<Project> projects;
  final List<VoiceNote> voiceNotes;
  final List<FilamentProfile> filaments;
  final List<StandaloneOrder> standaloneOrders;
  final bool isLoading;
  final String searchQuery;
  final ProjectCategory? selectedCategory;
  final String? selectedPhase;
  final String? selectedMachine;

  const EngineeringState({
    this.projects = const [],
    this.voiceNotes = const [],
    this.filaments = const [],
    this.standaloneOrders = const [],
    this.isLoading = true,
    this.searchQuery = '',
    this.selectedCategory,
    this.selectedPhase,
    this.selectedMachine,
  });

  List<Project> get activeProjects =>
      projects.where((p) => !p.isCompletedOrCancelled).toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));

  List<Project> get terminalProjects =>
      projects.where((p) => p.isCompletedOrCancelled).toList()
        ..sort((a, b) => (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt));

  List<Project> get sortedProjects => [...activeProjects, ...terminalProjects];

  List<Project> get filteredProjects {
    return sortedProjects.where((p) {
      final matchesSearch = searchQuery.isEmpty ||
          p.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.machine.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.subAssembly.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.tags.any((t) => t.toLowerCase().contains(searchQuery.toLowerCase()));

      final matchesCategory =
          selectedCategory == null || p.category == selectedCategory;
      final matchesPhase =
          selectedPhase == null || p.phase.toLowerCase() == selectedPhase!.toLowerCase();
      // Multi-machine: match if any segment contains the filter value
      final matchesMachine = selectedMachine == null ||
          p.machineList.any((m) =>
              m.toLowerCase().contains(selectedMachine!.toLowerCase())) ||
          p.machine.toLowerCase().contains(selectedMachine!.toLowerCase());

      return matchesSearch && matchesCategory && matchesPhase && matchesMachine;
    }).toList();
  }

  List<OpenOrderEntry> get openOrders {
    final list = <OpenOrderEntry>[];
    for (final p in sortedProjects) {
      for (final o in p.orders) {
        if (!o.delivered) {
          list.add(OpenOrderEntry(project: p, order: o));
        }
      }
    }
    // Sort by ETA ascending (nulls last)
    list.sort((a, b) {
      if (a.order.eta == null && b.order.eta == null) return 0;
      if (a.order.eta == null) return 1;
      if (b.order.eta == null) return -1;
      return a.order.eta!.compareTo(b.order.eta!);
    });
    return list;
  }

  /// Returns active projects sorted by "needs attention" score (highest first).
  /// Score = daysSinceLastAction / priority  →  low priority + long ignored = top of queue.
  List<Project> get queuedProjects {
    final active = activeProjects; // already sorted by priority
    final scored = active.map((p) {
      final days = p.daysSinceLastAction.toDouble();
      final score = days / p.priority.toDouble();
      return _ScoredProject(p, score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.project).toList();
  }

  List<String> get availablePhases {
    final set = <String>{...ProjectPhases.standardPhases};
    for (final p in projects) {
      if (p.phase.trim().isNotEmpty) {
        set.add(p.phase.trim());
      }
    }
    final list = set.toList();
    list.sort((a, b) {
      // Keep standard phases in standard order, custom at end alphabetically
      final idxA = ProjectPhases.standardPhases.indexOf(a);
      final idxB = ProjectPhases.standardPhases.indexOf(b);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return list;
  }

  /// Unique individual machine names across all projects (split on '/').
  List<String> get availableMachines {
    final set = <String>{};
    for (final p in projects) {
      for (final m in p.machineList) {
        if (m.isNotEmpty) set.add(m);
      }
      // Also include unsplit if no slash (single machine)
      if (p.machine.trim().isNotEmpty && !p.machine.contains('/')) {
        set.add(p.machine.trim());
      }
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> get availableSubAssemblies {
    final set = <String>{};
    for (final p in projects) {
      if (p.subAssembly.trim().isNotEmpty) {
        set.add(p.subAssembly.trim());
      }
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  EngineeringState copyWith({
    List<Project>? projects,
    List<VoiceNote>? voiceNotes,
    List<FilamentProfile>? filaments,
    List<StandaloneOrder>? standaloneOrders,
    bool? isLoading,
    String? searchQuery,
    ProjectCategory? selectedCategory,
    bool clearCategory = false,
    String? selectedPhase,
    bool clearPhase = false,
    String? selectedMachine,
    bool clearMachine = false,
  }) {
    return EngineeringState(
      projects: projects ?? this.projects,
      voiceNotes: voiceNotes ?? this.voiceNotes,
      filaments: filaments ?? this.filaments,
      standaloneOrders: standaloneOrders ?? this.standaloneOrders,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedPhase:
          clearPhase ? null : (selectedPhase ?? this.selectedPhase),
      selectedMachine:
          clearMachine ? null : (selectedMachine ?? this.selectedMachine),
    );
  }
}

class _ScoredProject {
  final Project project;
  final double score;
  const _ScoredProject(this.project, this.score);
}

class ProjectNotifier extends StateNotifier<EngineeringState> {
  final StorageService _storage;

  ProjectNotifier(this._storage) : super(const EngineeringState()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true);
    final data = await _storage.loadData();
    var loadedProjects = data['projects'] as List<Project>;
    loadedProjects = _rebalancePriorities(loadedProjects);

    state = state.copyWith(
      projects: loadedProjects,
      voiceNotes: data['voiceNotes'] as List<VoiceNote>,
      filaments: data['filaments'] as List<FilamentProfile>,
      standaloneOrders: data['standaloneOrders'] as List<StandaloneOrder>? ?? [],
      isLoading: false,
    );
  }

  Future<void> _persist() async {
    await _storage.saveData(
      projects: state.projects,
      voiceNotes: state.voiceNotes,
      customFilaments: state.filaments,
      standaloneOrders: state.standaloneOrders,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void filterCategory(ProjectCategory? category) {
    state = state.copyWith(
      selectedCategory: category,
      clearCategory: category == null,
    );
  }

  void filterPhase(String? phase) {
    state = state.copyWith(
      selectedPhase: phase,
      clearPhase: phase == null,
    );
  }

  void filterMachine(String? machine) {
    state = state.copyWith(
      selectedMachine: machine,
      clearMachine: machine == null,
    );
  }

  List<Project> _rebalancePriorities(List<Project> list) {
    final active = list.where((p) => !p.isCompletedOrCancelled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    final terminal = list.where((p) => p.isCompletedOrCancelled).toList();

    final rebalancedActive = <Project>[];
    for (int i = 0; i < active.length; i++) {
      rebalancedActive.add(active[i].copyWith(priority: i + 1));
    }

    return [...rebalancedActive, ...terminal];
  }

  // --- Project CRUD & Priority Ranking ---
  Future<void> addProject(Project project) async {
    // If active, insert at desired priority (default 1 or end)
    final isTerminal = ProjectPhases.isTerminal(project.phase);
    final currentProjects = [...state.projects];

    Project prepared = project;
    if (isTerminal) {
      prepared = prepared.copyWith(
        completedAt: prepared.completedAt ?? DateTime.now(),
      );
      currentProjects.add(prepared);
    } else {
      final active = currentProjects.where((p) => !p.isCompletedOrCancelled).toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
      
      int targetPriority = prepared.priority.clamp(1, active.length + 1);
      // Shift active items
      active.insert(targetPriority - 1, prepared);

      final rebalancedActive = <Project>[];
      for (int i = 0; i < active.length; i++) {
        rebalancedActive.add(active[i].copyWith(priority: i + 1));
      }
      final terminal = currentProjects.where((p) => p.isCompletedOrCancelled).toList();
      currentProjects.clear();
      currentProjects.addAll([...rebalancedActive, ...terminal]);
    }

    state = state.copyWith(projects: currentProjects);
    await _persist();
  }

  Future<void> updateProject(Project updated) async {
    final oldProject = getProjectById(updated.id);
    if (oldProject == null) return;

    var modified = updated.copyWith(updatedAt: DateTime.now());

    // Phase transition completedAt logic
    final wasTerminal = oldProject.isCompletedOrCancelled;
    final isNowTerminal = modified.isCompletedOrCancelled;

    if (!wasTerminal && isNowTerminal) {
      modified = modified.copyWith(
        completedAt: DateTime.now(),
        // Keep highest lifetime priority stored on object
      );
    } else if (wasTerminal && !isNowTerminal) {
      // Restoring to active phase -> clear completedAt
      modified = modified.copyWith(
        clearCompletedAt: true,
      );
    }

    var list = state.projects.map((p) => p.id == modified.id ? modified : p).toList();

    // If active priority changed, reorder active projects
    if (!isNowTerminal) {
      final active = list.where((p) => !p.isCompletedOrCancelled && p.id != modified.id).toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));

      int targetPos = (modified.priority - 1).clamp(0, active.length);
      active.insert(targetPos, modified);

      final rebalancedActive = <Project>[];
      for (int i = 0; i < active.length; i++) {
        rebalancedActive.add(active[i].copyWith(priority: i + 1));
      }
      final terminal = list.where((p) => p.isCompletedOrCancelled).toList();
      list = [...rebalancedActive, ...terminal];
    } else {
      list = _rebalancePriorities(list);
    }

    state = state.copyWith(projects: list);
    await _persist();
  }

  Future<void> setProjectPriority(String projectId, int newPriority) async {
    final project = getProjectById(projectId);
    if (project == null || project.isCompletedOrCancelled) return;

    final updated = project.copyWith(priority: newPriority);
    await updateProject(updated);
  }

  Future<void> deleteProject(String id) async {
    final list = state.projects.where((p) => p.id != id).toList();
    final rebalanced = _rebalancePriorities(list);
    state = state.copyWith(projects: rebalanced);
    await _persist();
  }

  Project? getProjectById(String id) {
    try {
      return state.projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // --- Task Management ---
  Future<void> addTask(String projectId, TaskItem task) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedTasks = [...project.tasks, task];
    final updatedProject = project.copyWith(tasks: updatedTasks);
    await updateProject(updatedProject);
  }

  Future<void> updateTask(String projectId, TaskItem task) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedTasks = project.tasks.map((t) => t.id == task.id ? task : t).toList();
    final updatedProject = project.copyWith(tasks: updatedTasks);
    await updateProject(updatedProject);
  }

  Future<void> toggleTaskCompleted(String projectId, String taskId) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedTasks = project.tasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(isCompleted: !t.isCompleted);
      }
      return t;
    }).toList();
    final updatedProject = project.copyWith(
      tasks: updatedTasks,
      lastActionAt: DateTime.now(),
    );
    await updateProject(updatedProject);
  }

  Future<void> toggleTask(String projectId, String taskId) async {
    await toggleTaskCompleted(projectId, taskId);
  }

  Future<void> deleteTask(String projectId, String taskId) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedTasks = project.tasks.where((t) => t.id != taskId).toList();
    final clearPending = project.nextPendingTaskId == taskId;
    final updatedProject = project.copyWith(
      tasks: updatedTasks,
      clearNextPendingTask: clearPending,
    );
    await updateProject(updatedProject);
  }

  /// Reorders tasks by dragging. Completed tasks are ignored (they stay at bottom).
  Future<void> reorderTasks(String projectId, int oldIndex, int newIndex) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    // Only reorder incomplete tasks; completed tasks stay at the end
    final incompleteTasks = project.tasks
        .where((t) => !t.isCompleted)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final completedTasks = project.tasks
        .where((t) => t.isCompleted)
        .toList();

    if (oldIndex >= incompleteTasks.length || newIndex > incompleteTasks.length) return;

    final item = incompleteTasks.removeAt(oldIndex);
    if (newIndex > oldIndex) newIndex--;
    incompleteTasks.insert(newIndex, item);

    // Reassign sortOrder values
    final reindexed = incompleteTasks
        .asMap()
        .entries
        .map((e) => e.value.copyWith(sortOrder: e.key))
        .toList();

    final updatedProject = project.copyWith(
      tasks: [...reindexed, ...completedTasks],
      lastActionAt: DateTime.now(),
    );
    await updateProject(updatedProject);
  }

  /// Stamps lastActionAt to mark the engineer has taken action on this project today.
  Future<void> markProjectActioned(String projectId) async {
    final project = getProjectById(projectId);
    if (project == null) return;
    final updated = project.copyWith(lastActionAt: DateTime.now());
    await updateProject(updated);
  }

  // --- Order Management ---
  Future<void> addOrder(String projectId, OrderItem order) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedOrders = [...project.orders, order];
    final updatedProject = project.copyWith(orders: updatedOrders);
    await updateProject(updatedProject);
  }

  Future<void> updateOrder(String projectId, OrderItem order) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedOrders = project.orders.map((o) => o.id == order.id ? order : o).toList();
    final updatedProject = project.copyWith(orders: updatedOrders);
    await updateProject(updatedProject);
  }

  Future<void> toggleOrderDelivered(String projectId, String orderId) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedOrders = project.orders.map((o) {
      if (o.id == orderId) {
        return o.copyWith(delivered: !o.delivered);
      }
      return o;
    }).toList();
    final updatedProject = project.copyWith(orders: updatedOrders);
    await updateProject(updatedProject);
  }

  Future<void> deleteOrder(String projectId, String orderId) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedOrders = project.orders.where((o) => o.id != orderId).toList();
    final updatedProject = project.copyWith(orders: updatedOrders);
    await updateProject(updatedProject);
  }

  // --- Project Logs ---
  Future<void> addProjectLog(String projectId, ProjectLog log) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedLogs = [log, ...project.logs];
    final updatedProject = project.copyWith(
      logs: updatedLogs,
      lastActionAt: DateTime.now(),
    );
    await updateProject(updatedProject);
  }

  Future<void> deleteProjectLog(String projectId, String logId) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedLogs = project.logs.where((l) => l.id != logId).toList();
    final updatedProject = project.copyWith(logs: updatedLogs);
    await updateProject(updatedProject);
  }

  // --- Photos ---
  Future<void> addProjectPhoto(String projectId, String photoPath) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    final updatedPhotos = [...project.photoPaths, photoPath];
    final updatedProject = project.copyWith(photoPaths: updatedPhotos);
    await updateProject(updatedProject);
  }

  // --- Voice Notes ---
  Future<void> addVoiceNote(VoiceNote note) async {
    final updated = [note, ...state.voiceNotes];
    state = state.copyWith(voiceNotes: updated);

    if (note.projectId != null) {
      final log = ProjectLog(
        title: '🎤 ${note.title}',
        content: note.transcript,
        type: LogType.voice,
        timestamp: note.timestamp,
      );
      await addProjectLog(note.projectId!, log);
    }

    await _persist();
  }

  Future<void> updateVoiceNote(VoiceNote updatedNote) async {
    final updatedList = state.voiceNotes.map((n) {
      return n.id == updatedNote.id ? updatedNote : n;
    }).toList();
    state = state.copyWith(voiceNotes: updatedList);
    await _persist();
  }

  Future<void> deleteVoiceNote(String id) async {
    final updated = state.voiceNotes.where((n) => n.id != id).toList();
    state = state.copyWith(voiceNotes: updated);
    await _persist();
  }

  Future<bool> importJson(String jsonString) async {
    try {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final projects = (jsonMap['projects'] as List<dynamic>?)
              ?.map((e) => Project.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final voiceNotes = (jsonMap['voiceNotes'] as List<dynamic>?)
              ?.map((e) => VoiceNote.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      state = state.copyWith(
        projects: _rebalancePriorities(projects),
        voiceNotes: voiceNotes,
      );
      await _persist();
      return true;
    } catch (e) {
      debugPrint('JSON Import Error: $e');
      return false;
    }
  }

  Future<void> mergeCloudProjects(List<Project> remoteProjects) async {
    final localMap = {for (var p in state.projects) p.id: p};
    for (final remote in remoteProjects) {
      final local = localMap[remote.id];
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        localMap[remote.id] = remote;
      }
    }
    state = state.copyWith(
      projects: _rebalancePriorities(localMap.values.toList()),
    );
    await _persist();
  }

  Future<void> mergeCloudNotes(List<VoiceNote> remoteNotes) async {
    final localMap = {for (var n in state.voiceNotes) n.id: n};
    for (final remote in remoteNotes) {
      localMap[remote.id] = remote;
    }
    state = state.copyWith(
      voiceNotes: localMap.values.toList(),
    );
    await _persist();
  }

  Future<void> clearAllData() async {
    state = state.copyWith(projects: [], voiceNotes: [], standaloneOrders: []);
    await _storage.clearAllData();
    await _persist();
  }

  // --- Standalone Orders ---
  Future<void> addStandaloneOrder(StandaloneOrder order) async {
    final updated = [...state.standaloneOrders, order];
    state = state.copyWith(standaloneOrders: updated);
    await _persist();
  }

  Future<void> updateStandaloneOrder(StandaloneOrder order) async {
    final updated = state.standaloneOrders
        .map((o) => o.id == order.id ? order : o)
        .toList();
    state = state.copyWith(standaloneOrders: updated);
    await _persist();
  }

  Future<void> deleteStandaloneOrder(String id) async {
    final updated = state.standaloneOrders.where((o) => o.id != id).toList();
    state = state.copyWith(standaloneOrders: updated);
    await _persist();
  }

  /// Moves a standalone order into a project's orders list and removes it from standaloneOrders.
  Future<void> linkOrderToProject(String standaloneOrderId, String projectId) async {
    final project = getProjectById(projectId);
    final standalone = state.standaloneOrders
        .where((o) => o.id == standaloneOrderId)
        .firstOrNull;
    if (project == null || standalone == null) return;

    // Convert StandaloneOrder → OrderItem
    final orderItem = OrderItem(
      id: standalone.id,
      pr: standalone.pr,
      po: standalone.po,
      description: standalone.description,
      price: standalone.price,
      eta: standalone.eta,
      delivered: standalone.delivered,
    );

    final updatedOrders = [...project.orders, orderItem];
    final updatedProject = project.copyWith(orders: updatedOrders);
    final remainingStandalone =
        state.standaloneOrders.where((o) => o.id != standaloneOrderId).toList();

    state = state.copyWith(standaloneOrders: remainingStandalone);
    await updateProject(updatedProject);
  }
}

final projectProvider =
    StateNotifierProvider<ProjectNotifier, EngineeringState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ProjectNotifier(storage);
});
