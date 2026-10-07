import 'dart:convert';
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
import '../services/storage_service.dart';
import 'engineering_state.dart';
import 'project_ops/bamm_link_ops.dart';
import 'project_ops/cloud_merge_ops.dart';
import 'project_ops/inbox_vendor_ops.dart';
import 'project_ops/notifier_core.dart';
import 'project_ops/parking_ops.dart';
import 'project_ops/standalone_order_ops.dart';

export 'engineering_state.dart';
import '../services/app_logger.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class ProjectNotifier extends EngineeringNotifierCore
    with CloudMergeOps, StandaloneOrderOps, BammLinkOps, InboxVendorOps, ParkingOps {
  /// [storage] is a test seam; production resolves [storageServiceProvider].
  ProjectNotifier([StorageService? storage]) : _injectedStorage = storage;

  final StorageService? _injectedStorage;
  StorageService get _storage =>
      _injectedStorage ?? ref.read(storageServiceProvider);

  @override
  EngineeringState build() {
    // Loading sets `state`, so it must start after build() has returned.
    Future.microtask(_loadInitialData);
    return const EngineeringState();
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true);
    final data = await _storage.loadData();
    var loadedProjects = data['projects'] as List<Project>;
    loadedProjects = rebalancePriorities(loadedProjects);

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
    await applyDueParks();
  }

  /// Records a timestamped action for traceability (persisted separately).
  Future<void> addActivityLog(ActivityLog log) async {
    final full = log.withId();
    state = state.copyWith(activityLog: [full, ...state.activityLog]);
    await _storage.saveActivityLog(state.activityLog);
  }

  @override
  Future<void> logActivity(ActivityType type, String text,
          {String? pid, String? ptitle}) =>
      addActivityLog(ActivityLog(
          type: type, text: text, timestamp: DateTime.now(), projectId: pid, projectTitle: ptitle));

  @override
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

  @override
  Future<void> persist() async {
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
    await persist();
  }

  Future<void> clearSnooze(String projectId) async {
    final updated = Map<String, String>.from(state.snoozedProjects)..remove(projectId);
    state = state.copyWith(snoozedProjects: updated);
    await persist();
  }

  // --- Reusable Project & PM Templates ---
  Future<void> addCustomTemplate(ProjectTemplate template) async {
    final updated = [...state.customTemplates, template];
    state = state.copyWith(customTemplates: updated);
    await persist();
  }

  Future<void> deleteCustomTemplate(String id) async {
    final updated = state.customTemplates.where((t) => t.id != id).toList();
    state = state.copyWith(customTemplates: updated);
    await persist();
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

  @override
  List<Project> rebalancePriorities(List<Project> list) => renumberQueue(
        ParkingOps.queueOrder(list),
        list.where((p) => p.isCompletedOrCancelled).toList(),
      );

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
      final active = ParkingOps.queueOrder(currentProjects);
      // A new project goes among the unparked ones, never below a parked one.
      final unparkedCount = active.where((p) => !p.isParked).length;
      int targetPriority = prepared.priority.clamp(1, unparkedCount + 1);
      active.insert(targetPriority - 1, prepared.copyWith(clearPark: true));
      final terminal = currentProjects.where((p) => p.isCompletedOrCancelled).toList();
      currentProjects
        ..clear()
        ..addAll(renumberQueue(active, terminal));
    }

    await logActivity(ActivityType.projectAdded, 'Project: ${project.title}', pid: project.id, ptitle: project.title);
    state = state.copyWith(projects: currentProjects);
    await persist();
  }

  @override
  Future<void> updateProject(Project updated) async {
    final oldProject = getProjectById(updated.id);
    if (oldProject == null) return;

    var modified = updated.copyWith(updatedAt: DateTime.now());

    // Phase transition completedAt logic
    final wasTerminal = oldProject.isCompletedOrCancelled;
    final isNowTerminal = modified.isCompletedOrCancelled;

    if (!wasTerminal && isNowTerminal) {
      await logActivity(ActivityType.projectCompleted, 'Project closed: ${modified.title}', pid: modified.id, ptitle: modified.title);
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

    // Closing a project, or re-ranking a parked one by hand, ends its park.
    if (isNowTerminal && modified.parkedUntil != null) {
      modified = modified.copyWith(clearPark: true);
    } else if (oldProject.isParked &&
        modified.isParked &&
        modified.priority != oldProject.priority) {
      modified = modified.copyWith(clearPark: true);
    }

    var list = state.projects.map((p) => p.id == modified.id ? modified : p).toList();

    // If active priority changed, reorder active projects
    if (!isNowTerminal) {
      final others = ParkingOps.queueOrder(list.where((p) => p.id != modified.id));
      final unparkedCount = others.where((p) => !p.isParked).length;
      // A parked project stays at the bottom; others never land below one.
      final targetPos = modified.isParked
          ? others.length
          : (modified.priority - 1).clamp(0, unparkedCount);
      others.insert(targetPos, modified);
      list = renumberQueue(others, list.where((p) => p.isCompletedOrCancelled).toList());
    } else {
      list = rebalancePriorities(list);
    }

    state = state.copyWith(projects: list);
    await persist();
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
    final active = ParkingOps.queueOrder(state.projects);

    if (oldIndex < 0 || oldIndex >= active.length) return;
    newIndex = newIndex.clamp(0, active.length);
    if (newIndex > oldIndex) newIndex--;

    var item = active.removeAt(oldIndex);
    if (item.isParked) {
      // Dragging a parked project is taking manual control of its rank.
      item = item.copyWith(clearPark: true);
    } else {
      // An unparked project cannot be dropped below a parked one.
      newIndex = newIndex.clamp(0, active.where((p) => !p.isParked).length);
    }
    active.insert(newIndex, item);

    state = state.copyWith(
      projects: renumberQueue(
        active,
        state.projects.where((p) => p.isCompletedOrCancelled).toList(),
      ),
    );
    await persist();
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
    final rebalanced = rebalancePriorities(list);
    state = state.copyWith(projects: rebalanced);
    await persist();
  }

  /// Removes a project from LOCAL state + disk only (no cloud delete). Used when
  /// a remote snapshot tells us the project was deleted on another device, so we
  /// never push it back up (sync resurrection).
  Future<void> removeProjectLocal(String id) async {
    final list = state.projects.where((p) => p.id != id).toList();
    final rebalanced = rebalancePriorities(list);
    state = state.copyWith(projects: rebalanced);
    await persist();
  }

  @override
  Project? getProjectById(String id) {
    try {
      return state.projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // --- Task Management ---
  @override
  Future<void> addTask(String projectId, TaskItem task) async {
    final project = getProjectById(projectId);
    if (project == null) return;

    await logActivity(ActivityType.taskAdded, 'Task: ${task.description}', pid: projectId, ptitle: project.title);
    final updatedTasks = [...project.tasks, task];
    final updatedProject = project.copyWith(
      tasks: updatedTasks,
      lastActionAt: DateTime.now(),
    );
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
    await logActivity(
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

  /// One-click "make it due today": reschedules an overdue task's scheduled
  /// date to today (date-only), keeping the time-of-day if one was set.
  Future<void> rescheduleTaskToToday(String projectId, String taskId) async {
    final project = getProjectById(projectId);
    if (project == null) return;
    final task = project.tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null || task.scheduledDate == null) return;

    final old = task.scheduledDate!;
    final now = DateTime.now();
    final updated = task.copyWith(
      scheduledDate: DateTime(now.year, now.month, now.day,
          old.hour, old.minute),
    );
    await updateTask(projectId, updated);
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

    await logActivity(ActivityType.orderAdded, 'Order: ${order.description}', pid: projectId, ptitle: project.title);
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
    await logActivity(
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

    await logActivity(ActivityType.storesRequested, 'Stores request: ${order.description}', pid: projectId, ptitle: project.title);

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

    await logActivity(ActivityType.logAdded, log.title, pid: projectId, ptitle: project.title);
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
  @override
  Future<void> addVoiceNote(VoiceNote note) async {
    await logActivity(ActivityType.noteAdded, note.title, pid: note.projectId);
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

    await persist();
  }

  Future<void> updateVoiceNote(VoiceNote updatedNote) async {
    final withStamp = updatedNote.copyWith(updatedAt: DateTime.now());
    final updatedList = state.voiceNotes.map((n) {
      return n.id == withStamp.id ? withStamp : n;
    }).toList();
    state = state.copyWith(voiceNotes: updatedList);
    await persist();
  }

  /// Removes a note from LOCAL state + disk only (no cloud delete). Used when a
  /// remote snapshot tells us the note was deleted on another device, so we
  /// never push it back up (sync resurrection).
  Future<void> removeVoiceNoteLocal(String id) async {
    final updated = state.voiceNotes.where((n) => n.id != id).toList();
    state = state.copyWith(voiceNotes: updated);
    await persist();
  }

  Future<void> deleteVoiceNote(String id) async {
    final updated = state.voiceNotes.where((n) => n.id != id).toList();
    state = state.copyWith(voiceNotes: updated);
    await persist();
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
        projects: rebalancePriorities(projects),
        voiceNotes: voiceNotes,
      );
      await persist();
      return true;
    } catch (e) {
      log.error('project', 'JSON Import Error: $e');
      return false;
    }
  }

  Future<void> clearAllData() async {
    state = state.copyWith(projects: [], voiceNotes: [], standaloneOrders: []);
    await _storage.clearAllData();
    await persist();
  }

}

final projectProvider =
    NotifierProvider<ProjectNotifier, EngineeringState>(ProjectNotifier.new);
