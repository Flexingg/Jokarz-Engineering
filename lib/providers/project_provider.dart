import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/task_item.dart';
import '../models/order_item.dart';
import '../models/project_log.dart';
import '../models/voice_note.dart';
import '../models/activity_log.dart';
import '../models/downtime_event.dart';
import '../models/filament_profile.dart';
import '../models/standalone_order.dart';
import '../models/inbox_item.dart';
import '../models/vendor.dart';
import '../models/project_template.dart';
import '../models/machine_asset.dart';
import '../models/search_result.dart';
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
  final List<InboxItem> inboxItems;
  final List<Vendor> vendors;
  final List<ProjectTemplate> customTemplates;
  final Map<String, String> snoozedProjects;
  final List<ActivityLog> activityLog;
  final List<DowntimeEvent> downtimes;
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
    this.inboxItems = const [],
    this.vendors = const [],
    this.customTemplates = const [],
    this.snoozedProjects = const {},
    this.activityLog = const [],
    this.downtimes = const [],
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

  static String get todayString {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  /// Returns active projects sorted by "needs attention" score (highest first).
  /// Score = daysSinceLastAction / priority  →  low priority + long ignored = top of queue.
  /// Projects snoozed for today are excluded.
  List<Project> get queuedProjects {
    final today = todayString;
    final active = activeProjects
        .where((p) => snoozedProjects[p.id] != today)
        .toList();
    final scored = active.map((p) {
      final days = p.daysSinceLastAction.toDouble();
      final score = days / p.priority.toDouble();
      return _ScoredProject(p, score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.project).toList();
  }

  List<InboxItem> get unprocessedInboxItems =>
      inboxItems.where((i) => !i.isProcessed).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get unprocessedInboxCount => unprocessedInboxItems.length;

  List<ProjectTemplate> get allTemplates =>
      [...ProjectTemplate.systemTemplates, ...customTemplates];

  List<MachineAsset> get machineAssets {
    final machines = availableMachines;
    final assets = <MachineAsset>[];

    for (final m in machines) {
      final mLower = m.toLowerCase();

      final mActiveProjects = projects.where((p) =>
          !p.isCompletedOrCancelled &&
          (p.machineList.any((pm) => pm.toLowerCase() == mLower) ||
              p.machine.toLowerCase() == mLower)).toList();

      final mCompletedProjects = projects.where((p) =>
          p.isCompletedOrCancelled &&
          (p.machineList.any((pm) => pm.toLowerCase() == mLower) ||
              p.machine.toLowerCase() == mLower)).toList();

      final mOrders = <MachineOrderEntry>[];
      for (final p in projects) {
        if (p.machineList.any((pm) => pm.toLowerCase() == mLower) ||
            p.machine.toLowerCase() == mLower) {
          for (final o in p.orders) {
            mOrders.add(MachineOrderEntry(project: p, order: o));
          }
        }
      }
      for (final so in standaloneOrders) {
        if (so.notes.toLowerCase().contains(mLower) ||
            so.description.toLowerCase().contains(mLower)) {
          mOrders.add(MachineOrderEntry(standaloneOrder: so));
        }
      }

      final mDowntimes = downtimes.where((d) =>
          d.machine.toLowerCase() == mLower ||
          d.machine.split('/').any((dm) => dm.trim().toLowerCase() == mLower)).toList();

      final mNotes = voiceNotes.where((n) {
        if (n.title.toLowerCase().contains(mLower) || n.transcript.toLowerCase().contains(mLower)) return true;
        if (n.projectId != null) {
          final p = projects.where((p) => p.id == n.projectId).firstOrNull;
          if (p != null && (p.machineList.any((pm) => pm.toLowerCase() == mLower) || p.machine.toLowerCase() == mLower)) {
            return true;
          }
        }
        return false;
      }).toList();

      assets.add(MachineAsset(
        name: m,
        activeProjects: mActiveProjects,
        completedProjects: mCompletedProjects,
        openOrders: mOrders,
        downtimes: mDowntimes,
        notes: mNotes,
        subAssemblies: availableSubAssembliesFor(m),
      ));
    }

    return assets;
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

  /// Sub-assemblies that exist under the given machine(s) for drill-down
  /// suggestions. [machineText] may contain multiple machines split on `/` or
  /// `,`. Falls back to all sub-assemblies when no machine is specified.
  List<String> availableSubAssembliesFor(String machineText) {
    final tokens = machineText
        .split(RegExp(r'[/,]'))
        .map((m) => m.trim().toLowerCase())
        .where((m) => m.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return availableSubAssemblies;

    final set = <String>{};
    for (final p in projects) {
      if (p.subAssembly.trim().isEmpty) continue;
      final pMachines = p.machine
          .split(RegExp(r'[/,]'))
          .map((m) => m.trim().toLowerCase())
          .where((m) => m.isNotEmpty)
          .toList();
      final matches =
          tokens.any((t) => pMachines.any((pm) => pm.contains(t) || t.contains(pm)));
      if (matches) set.add(p.subAssembly.trim());
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Universal live search across projects, orders (attached + standalone),
  /// and notes (voice/written + project-attached). Tokenized: every non-empty
  /// query token must match at least one field on the entity.
  SearchResults searchAll(String query) {
    final tokens = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return const SearchResults();

    bool matches(String field) {
      if (field.isEmpty) return false;
      final f = field.toLowerCase();
      return tokens.every((t) => f.contains(t));
    }

    final projectHits = <ProjectSearchHit>[];
    final orderHits = <OrderSearchHit>[];
    final noteHits = <NoteSearchHit>[];
    final taskHits = <TaskSearchHit>[];

    for (final p in projects) {
      final projectMatch = matches(p.title) ||
          matches(p.machine) ||
          matches(p.subAssembly) ||
          matches(p.phase) ||
          matches(p.description) ||
          p.tags.any((t) => matches(t));
      if (projectMatch) projectHits.add(ProjectSearchHit(p));

      for (final o in p.orders) {
        if (matches(o.description) ||
            matches(o.pr) ||
            matches(o.po) ||
            matches(p.title) ||
            matches(o.vendorName)) {
          orderHits.add(OrderSearchHit.fromOrder(o, p));
        }
      }

      if (p.notes.trim().isNotEmpty && matches(p.notes)) {
        noteHits.add(NoteSearchHit(
          title: p.title,
          content: p.notes,
          projectId: p.id,
          projectTitle: p.title,
          isProjectNote: true,
        ));
      }

      for (final t in p.tasks) {
        if (matches(t.description) || matches(t.pendingReason)) {
          taskHits.add(TaskSearchHit(p, t));
        }
      }
    }

    for (final o in standaloneOrders) {
      if (matches(o.description) ||
          matches(o.pr) ||
          matches(o.po) ||
          matches(o.vendorName)) {
        orderHits.add(OrderSearchHit(
          description: o.description,
          pr: o.pr,
          po: o.po,
          price: o.price,
          eta: o.eta,
          delivered: o.delivered,
          project: null,
          projectTitle: 'Unlinked',
        ));
      }
    }

    for (final n in voiceNotes) {
      if (matches(n.title) || matches(n.transcript)) {
        noteHits.add(NoteSearchHit(
          title: n.title,
          content: n.transcript,
          projectId: n.projectId,
          projectTitle: n.projectId != null ? _titleOf(n.projectId!) : null,
        ));
      }
    }

    return SearchResults(
      projects: projectHits,
      orders: orderHits,
      notes: noteHits,
      tasks: taskHits,
    );
  }

  String? _titleOf(String projectId) {
    try {
      return projects.firstWhere((p) => p.id == projectId).title;
    } catch (_) {
      return null;
    }
  }

  EngineeringState copyWith({
    List<Project>? projects,
    List<VoiceNote>? voiceNotes,
    List<FilamentProfile>? filaments,
    List<StandaloneOrder>? standaloneOrders,
    List<InboxItem>? inboxItems,
    List<Vendor>? vendors,
    List<ProjectTemplate>? customTemplates,
    Map<String, String>? snoozedProjects,
    List<ActivityLog>? activityLog,
    List<DowntimeEvent>? downtimes,
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
      inboxItems: inboxItems ?? this.inboxItems,
      vendors: vendors ?? this.vendors,
      customTemplates: customTemplates ?? this.customTemplates,
      snoozedProjects: snoozedProjects ?? this.snoozedProjects,
      activityLog: activityLog ?? this.activityLog,
      downtimes: downtimes ?? this.downtimes,
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

    // Clean up expired snoozes from previous days
    final today = EngineeringState.todayString;
    final rawSnoozed = data['snoozedProjects'] as Map<String, String>? ?? {};
    final validSnoozed = Map<String, String>.from(rawSnoozed)
      ..removeWhere((key, dateStr) => dateStr != today);

    state = state.copyWith(
      projects: loadedProjects,
      voiceNotes: data['voiceNotes'] as List<VoiceNote>,
      filaments: data['filaments'] as List<FilamentProfile>,
      standaloneOrders: data['standaloneOrders'] as List<StandaloneOrder>? ?? [],
      inboxItems: data['inboxItems'] as List<InboxItem>? ?? [],
      vendors: data['vendors'] as List<Vendor>? ?? [],
      customTemplates: data['customTemplates'] as List<ProjectTemplate>? ?? [],
      snoozedProjects: validSnoozed,
      activityLog: await _storage.loadActivityLog(),
      downtimes: await _storage.loadDowntimes(),
      isLoading: false,
    );
  }

  /// Records a timestamped action for traceability (persisted separately).
  Future<void> addActivityLog(ActivityLog log) async {
    final full = log.withId();
    state = state.copyWith(activityLog: [full, ...state.activityLog]);
    await _storage.saveActivityLog(state.activityLog);
  }

  Future<void> _log(ActivityType type, String text,
          {String? pid, String? ptitle}) =>
      addActivityLog(ActivityLog(
          type: type, text: text, timestamp: DateTime.now(), projectId: pid, projectTitle: ptitle));

  Future<void> addDowntime(DowntimeEvent d) async {
    state = state.copyWith(downtimes: [...state.downtimes, d.withId()]);
    await _storage.saveDowntimes(state.downtimes);
  }

  Future<void> updateDowntime(DowntimeEvent d) async {
    state = state.copyWith(
        downtimes: state.downtimes.map((e) => e.id == d.id ? d : e).toList());
    await _storage.saveDowntimes(state.downtimes);
  }

  Future<void> deleteDowntime(String id) async {
    state = state.copyWith(
        downtimes: state.downtimes.where((e) => e.id != id).toList());
    await _storage.saveDowntimes(state.downtimes);
  }

  Future<void> _persist() async {
    await _storage.saveData(
      projects: state.projects,
      voiceNotes: state.voiceNotes,
      customFilaments: state.filaments,
      standaloneOrders: state.standaloneOrders,
      inboxItems: state.inboxItems,
      vendors: state.vendors,
      customTemplates: state.customTemplates,
      snoozedProjects: state.snoozedProjects,
    );
  }

  // --- Queue Snooze (Disk-persisted) ---
  Future<void> snoozeProjectUntilTomorrow(String projectId) async {
    final updated = Map<String, String>.from(state.snoozedProjects);
    updated[projectId] = EngineeringState.todayString;
    state = state.copyWith(snoozedProjects: updated);
    await _persist();
  }

  Future<void> clearSnooze(String projectId) async {
    final updated = Map<String, String>.from(state.snoozedProjects)..remove(projectId);
    state = state.copyWith(snoozedProjects: updated);
    await _persist();
  }

  // --- Quick-Capture Inbox Management & Triage ---
  Future<void> addInboxItem(InboxItem item) async {
    final updated = [item, ...state.inboxItems];
    state = state.copyWith(inboxItems: updated);
    await _log(ActivityType.noteAdded, 'Quick dump: ${item.text}');
    await _persist();
  }

  Future<void> updateInboxItem(InboxItem item) async {
    final updated = state.inboxItems.map((i) => i.id == item.id ? item : i).toList();
    state = state.copyWith(inboxItems: updated);
    await _persist();
  }

  Future<void> deleteInboxItem(String id) async {
    final updated = state.inboxItems.where((i) => i.id != id).toList();
    state = state.copyWith(inboxItems: updated);
    await _persist();
  }

  Future<void> dismissInboxItem(String id) async {
    final updated = state.inboxItems.map((i) {
      if (i.id == id) return i.copyWith(isProcessed: true);
      return i;
    }).toList();
    state = state.copyWith(inboxItems: updated);
    await _persist();
  }

  /// Triage an inbox item directly into a task on an existing project.
  Future<void> triageToTask(String inboxId, String projectId, {DateTime? scheduledDate}) async {
    final inboxItem = state.inboxItems.where((i) => i.id == inboxId).firstOrNull;
    if (inboxItem == null) return;

    final task = TaskItem(
      description: inboxItem.text,
      scheduledDate: scheduledDate,
    );
    await addTask(projectId, task);
    await dismissInboxItem(inboxId);
  }

  /// Triage an inbox item into a new standalone purchase order.
  Future<void> triageToOrder(String inboxId, StandaloneOrder order) async {
    await addStandaloneOrder(order);
    await dismissInboxItem(inboxId);
  }

  /// Triage an inbox item into a machine downtime event.
  Future<void> triageToDowntime(String inboxId, DowntimeEvent downtime) async {
    await addDowntime(downtime);
    await dismissInboxItem(inboxId);
  }

  /// Triage an inbox item into a field note.
  Future<void> triageToNote(String inboxId, VoiceNote note) async {
    await addVoiceNote(note);
    await dismissInboxItem(inboxId);
  }

  // --- Vendor Directory Management ---
  Future<void> addVendor(Vendor vendor) async {
    final updated = [...state.vendors, vendor];
    state = state.copyWith(vendors: updated);
    await _persist();
  }

  Future<void> updateVendor(Vendor vendor) async {
    final updated = state.vendors.map((v) => v.id == vendor.id ? vendor : v).toList();
    state = state.copyWith(vendors: updated);
    await _persist();
  }

  Future<void> deleteVendor(String id) async {
    final updated = state.vendors.where((v) => v.id != id).toList();
    state = state.copyWith(vendors: updated);
    await _persist();
  }

  // --- Reusable Project & PM Templates ---
  Future<void> addCustomTemplate(ProjectTemplate template) async {
    final updated = [...state.customTemplates, template];
    state = state.copyWith(customTemplates: updated);
    await _persist();
  }

  Future<void> deleteCustomTemplate(String id) async {
    final updated = state.customTemplates.where((t) => t.id != id).toList();
    state = state.copyWith(customTemplates: updated);
    await _persist();
  }

  /// Saves an existing project's structure (tasks & orders) as a reusable template.
  Future<ProjectTemplate?> saveProjectAsTemplate(
    String projectId,
    String templateName, {
    String? description,
  }) async {
    final project = getProjectById(projectId);
    if (project == null) return null;

    final taskTemplates = project.tasks.asMap().entries.map((e) {
      return TaskTemplate(
        description: e.value.description,
        pendingReason: e.value.pendingReason,
        offsetDays: e.key, // sequential offset days
      );
    }).toList();

    final orderTemplates = project.orders.map((o) {
      return OrderTemplate(
        description: o.description,
        estimatedPrice: o.price,
        addToStores: o.addToStores,
      );
    }).toList();

    final template = ProjectTemplate(
      name: templateName.trim(),
      description: description?.trim() ?? project.description,
      category: project.category,
      defaultPhase: project.phase,
      defaultMachine: project.machine,
      tags: project.tags,
      tasks: taskTemplates,
      suggestedOrders: orderTemplates,
      isSystemTemplate: false,
    );

    await addCustomTemplate(template);
    return template;
  }

  /// Instantiates a new project from a template.
  Future<Project> createProjectFromTemplate(
    ProjectTemplate template, {
    String? customTitle,
    String? customMachine,
    DateTime? startDate,
  }) async {
    final baseDate = startDate ?? DateTime.now();
    final newTasks = template.tasks.asMap().entries.map((e) {
      final t = e.value;
      return TaskItem(
        description: t.description,
        pendingReason: t.pendingReason,
        scheduledDate: baseDate.add(Duration(days: t.offsetDays)),
        sortOrder: e.key,
      );
    }).toList();

    final newOrders = template.suggestedOrders.map((o) {
      return OrderItem(
        description: o.description,
        price: o.estimatedPrice,
        addToStores: o.addToStores,
      );
    }).toList();

    final project = Project(
      title: customTitle?.trim().isNotEmpty == true
          ? customTitle!.trim()
          : template.name,
      description: template.description,
      category: template.category,
      phase: template.defaultPhase,
      machine: customMachine?.trim().isNotEmpty == true
          ? customMachine!.trim()
          : template.defaultMachine,
      tags: template.tags,
      tasks: newTasks,
      orders: newOrders,
    );

    await addProject(project);
    return project;
  }

  // --- Cloud Merge Handlers ---
  Future<void> mergeCloudStandaloneOrders(List<StandaloneOrder> remoteOrders) async {
    final localMap = {for (var o in state.standaloneOrders) o.id: o};
    for (final remote in remoteOrders) {
      localMap[remote.id] = remote;
    }
    state = state.copyWith(standaloneOrders: localMap.values.toList());
    await _persist();
  }

  Future<void> mergeCloudInbox(List<InboxItem> remoteItems) async {
    final localMap = {for (var i in state.inboxItems) i.id: i};
    for (final remote in remoteItems) {
      localMap[remote.id] = remote;
    }
    state = state.copyWith(inboxItems: localMap.values.toList());
    await _persist();
  }

  Future<void> mergeCloudVendors(List<Vendor> remoteVendors) async {
    final localMap = {for (var v in state.vendors) v.id: v};
    for (final remote in remoteVendors) {
      localMap[remote.id] = remote;
    }
    state = state.copyWith(vendors: localMap.values.toList());
    await _persist();
  }

  Future<void> mergeCloudTemplates(List<ProjectTemplate> remoteTemplates) async {
    final localMap = {for (var t in state.customTemplates) t.id: t};
    for (final remote in remoteTemplates) {
      if (!remote.isSystemTemplate) {
        localMap[remote.id] = remote;
      }
    }
    state = state.copyWith(customTemplates: localMap.values.toList());
    await _persist();
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

    await _log(ActivityType.projectAdded, 'Project: ${project.title}', pid: project.id, ptitle: project.title);
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
      await _log(ActivityType.projectCompleted, 'Project closed: ${modified.title}', pid: modified.id, ptitle: modified.title);
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

  /// Reorders active projects by drag-and-drop. Indices refer to the
  /// displayed sorted order (active projects come first, then terminal).
  /// Only active projects are reordered; priorities are rebalanced 1..X.
  Future<void> reorderProjects(int oldIndex, int newIndex) async {
    final active = state.projects
        .where((p) => !p.isCompletedOrCancelled)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    if (oldIndex < 0 || oldIndex >= active.length) return;
    newIndex = newIndex.clamp(0, active.length);
    if (newIndex > oldIndex) newIndex--;

    final item = active.removeAt(oldIndex);
    active.insert(newIndex, item);

    final reindexed = active
        .asMap()
        .entries
        .map((e) => e.value.copyWith(priority: e.key + 1))
        .toList();
    final terminal =
        state.projects.where((p) => p.isCompletedOrCancelled).toList();

    state = state.copyWith(projects: [...reindexed, ...terminal]);
    await _persist();
  }

  /// Updates the free-form notes attached directly to the project.
  Future<void> updateProjectNotes(String projectId, String notes) async {
    final project = getProjectById(projectId);
    if (project == null) return;
    final updated = project.copyWith(
      notes: notes.trim(),
      lastActionAt: DateTime.now(),
    );
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

    await _log(ActivityType.taskAdded, 'Task: ${task.description}', pid: projectId, ptitle: project.title);
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

    final task = project.tasks.where((t) => t.id == taskId).firstOrNull;
    final nowDone = task != null && !task.isCompleted;
    await _log(
        nowDone ? ActivityType.taskCompleted : ActivityType.taskReopened,
        '${nowDone ? 'Completed' : 'Reopened'} task: ${task?.description ?? ''}',
        pid: projectId, ptitle: project.title);

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

    await _log(ActivityType.orderAdded, 'Order: ${order.description}', pid: projectId, ptitle: project.title);
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

    final order = project.orders.where((o) => o.id == orderId).firstOrNull;
    final nowDelivered = order != null && !order.delivered;
    await _log(
        nowDelivered ? ActivityType.orderDelivered : ActivityType.orderUndelivered,
        '${nowDelivered ? 'Delivered' : 'Reopened'} order: ${order?.description ?? ''}',
        pid: projectId, ptitle: project.title);

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

  // --- Order Storeroom Tracking ---
  Future<void> setOrderAddToStores(String projectId, String orderId, bool value) async {
    final project = getProjectById(projectId);
    if (project == null) return;
    final updatedOrders = project.orders.map((o) {
      if (o.id == orderId) return o.copyWith(addToStores: value);
      return o;
    }).toList();
    await updateProject(project.copyWith(orders: updatedOrders));
  }

  /// Marks an order's storeroom request as sent and appends a project log entry
  /// for traceability. Requires the order to have a PO number.
  Future<void> markOrderStoreRequested(String projectId, String orderId) async {
    final project = getProjectById(projectId);
    if (project == null) return;
    final order = project.orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return;

    final updatedOrders = project.orders.map((o) {
      if (o.id == orderId) return o.copyWith(storeRequested: true);
      return o;
    }).toList();

    await _log(ActivityType.storesRequested, 'Stores request: ${order.description}', pid: projectId, ptitle: project.title);

    final log = ProjectLog(
      title: '📦 Store request: ${order.description}',
      content: 'Requested "${order.description}" for the storeroom.'
          '${order.po.isNotEmpty ? " (PO: ${order.po})" : ""}',
      type: LogType.update,
    );

    final updatedProject = project.copyWith(
      orders: updatedOrders,
      logs: [log, ...project.logs],
      lastActionAt: DateTime.now(),
    );
    await updateProject(updatedProject);
  }

  /// Records the storeroom request number (and marks the request done).
  Future<void> setOrderStoreRequestNumber(
      String projectId, String orderId, String number) async {
    final project = getProjectById(projectId);
    if (project == null) return;
    final updatedOrders = project.orders.map((o) {
      if (o.id == orderId) {
        return o.copyWith(
          storeRequestNumber: number.trim(),
          storeRequested: true,
        );
      }
      return o;
    }).toList();
    await updateProject(project.copyWith(orders: updatedOrders));
  }

  // --- Project Logs ---
  Future<void> addProjectLog(String projectId, ProjectLog log) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    await _log(ActivityType.logAdded, log.title, pid: projectId, ptitle: project.title);
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
    await _log(ActivityType.noteAdded, note.title, pid: note.projectId);
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
    await _log(ActivityType.standaloneOrderAdded, 'Order: ${order.description}');
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

  Future<void> setStandaloneOrderAddToStores(String id, bool value) async {
    final updated = state.standaloneOrders
        .map((o) => o.id == id ? o.copyWith(addToStores: value) : o)
        .toList();
    state = state.copyWith(standaloneOrders: updated);
    await _persist();
  }

  Future<void> markStandaloneOrderStoreRequested(String id) async {
    final updated = state.standaloneOrders
        .map((o) => o.id == id ? o.copyWith(storeRequested: true) : o)
        .toList();
    state = state.copyWith(standaloneOrders: updated);
    await _persist();
  }

  Future<void> setStandaloneOrderStoreRequestNumber(String id, String num) async {
    final updated = state.standaloneOrders
        .map((o) =>
            o.id == id
                ? o.copyWith(storeRequestNumber: num.trim(), storeRequested: true)
                : o)
        .toList();
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
      addToStores: standalone.addToStores,
      storeRequested: standalone.storeRequested,
      storeRequestNumber: standalone.storeRequestNumber,
      vendorId: standalone.vendorId,
      vendorName: standalone.vendorName,
      vendorQuoteNumber: standalone.vendorQuoteNumber,
      trackingUrl: standalone.trackingUrl,
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
