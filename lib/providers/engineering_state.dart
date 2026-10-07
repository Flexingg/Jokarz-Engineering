import '../models/project.dart';
import '../models/task_item.dart';
import '../models/order_item.dart';
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
      projects.where((p) => p.isCompletedOrCancelled).toList()..sort(
        (a, b) => (b.completedAt ?? b.updatedAt).compareTo(
          a.completedAt ?? a.updatedAt,
        ),
      );

  List<Project> get sortedProjects => [...activeProjects, ...terminalProjects];

  List<Project> get filteredProjects {
    return sortedProjects.where((p) {
      final matchesSearch =
          searchQuery.isEmpty ||
          p.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.machine.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.subAssembly.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.tags.any(
            (t) => t.toLowerCase().contains(searchQuery.toLowerCase()),
          );

      final matchesCategory =
          selectedCategory == null || p.category == selectedCategory;
      final matchesPhase =
          selectedPhase == null ||
          p.phase.toLowerCase() == selectedPhase!.toLowerCase();
      // Multi-machine: match if any segment contains the filter value
      final matchesMachine =
          selectedMachine == null ||
          p.machineList.any(
            (m) => m.toLowerCase().contains(selectedMachine!.toLowerCase()),
          ) ||
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

  /// Incomplete tasks whose scheduled date is before today (overdue).
  List<({Project project, TaskItem task})> get overdueTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = <({Project project, TaskItem task})>[];
    for (final p in projects) {
      for (final t in p.tasks) {
        if (!t.isCompleted && t.scheduledDate != null) {
          final d = t.scheduledDate!;
          final day = DateTime(d.year, d.month, d.day);
          if (day.isBefore(today)) {
            list.add((project: p, task: t));
          }
        }
      }
    }
    // Most overdue first
    list.sort((a, b) => a.task.scheduledDate!.compareTo(b.task.scheduledDate!));
    return list;
  }

  /// Returns active projects sorted by "needs attention" score (highest first).
  /// Score = daysSinceLastAction / priority  →  low priority + long ignored = top of queue.
  /// Projects snoozed for today are excluded.
  List<Project> get queuedProjects {
    final today = todayString;
    final active = activeProjects
        .where((p) => snoozedProjects[p.id] != today)
        // Parked projects are waiting on purpose; do not nag about them.
        .where((p) => !p.isParked)
        .toList();
    final scored = active.map((p) {
      final days = p.daysSinceLastAction.toDouble();
      final score = days / p.priority.toDouble();
      return _ScoredProject(p, score);
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.project).toList();
  }

  List<InboxItem> get unprocessedInboxItems =>
      inboxItems.where((i) => !i.isProcessed).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get unprocessedInboxCount => unprocessedInboxItems.length;

  List<ProjectTemplate> get allTemplates => [
    ...ProjectTemplate.systemTemplates,
    ...customTemplates,
  ];

  List<MachineAsset> get machineAssets {
    final machines = availableMachines;
    final assets = <MachineAsset>[];

    for (final m in machines) {
      final mLower = m.toLowerCase();

      final mActiveProjects = projects
          .where(
            (p) =>
                !p.isCompletedOrCancelled &&
                (p.machineList.any((pm) => pm.toLowerCase() == mLower) ||
                    p.machine.toLowerCase() == mLower),
          )
          .toList();

      final mCompletedProjects = projects
          .where(
            (p) =>
                p.isCompletedOrCancelled &&
                (p.machineList.any((pm) => pm.toLowerCase() == mLower) ||
                    p.machine.toLowerCase() == mLower),
          )
          .toList();

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

      final mDowntimes = downtimes
          .where(
            (d) =>
                d.machine.toLowerCase() == mLower ||
                d.machine
                    .split('/')
                    .any((dm) => dm.trim().toLowerCase() == mLower),
          )
          .toList();

      final mNotes = voiceNotes.where((n) {
        if (n.title.toLowerCase().contains(mLower) ||
            n.transcript.toLowerCase().contains(mLower))
          return true;
        if (n.projectId != null) {
          final p = projects.where((p) => p.id == n.projectId).firstOrNull;
          if (p != null &&
              (p.machineList.any((pm) => pm.toLowerCase() == mLower) ||
                  p.machine.toLowerCase() == mLower)) {
            return true;
          }
        }
        return false;
      }).toList();

      assets.add(
        MachineAsset(
          name: m,
          activeProjects: mActiveProjects,
          completedProjects: mCompletedProjects,
          openOrders: mOrders,
          downtimes: mDowntimes,
          notes: mNotes,
          subAssemblies: availableSubAssembliesFor(m),
        ),
      );
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
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> get availableSubAssemblies {
    final set = <String>{};
    for (final p in projects) {
      if (p.subAssembly.trim().isNotEmpty) {
        set.add(p.subAssembly.trim());
      }
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
      final matches = tokens.any(
        (t) => pMachines.any((pm) => pm.contains(t) || t.contains(pm)),
      );
      if (matches) set.add(p.subAssembly.trim());
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
      final projectMatch =
          matches(p.title) ||
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
        noteHits.add(
          NoteSearchHit(
            title: p.title,
            content: p.notes,
            projectId: p.id,
            projectTitle: p.title,
            isProjectNote: true,
          ),
        );
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
        orderHits.add(
          OrderSearchHit(
            id: o.id,
            standaloneOrder: o,
            description: o.description,
            pr: o.pr,
            po: o.po,
            price: o.price,
            eta: o.eta,
            delivered: o.delivered,
            project: null,
            projectTitle: 'Unlinked',
          ),
        );
      }
    }

    for (final n in voiceNotes) {
      if (matches(n.title) || matches(n.transcript)) {
        noteHits.add(
          NoteSearchHit(
            id: n.id,
            voiceNote: n,
            title: n.title,
            content: n.transcript,
            projectId: n.projectId,
            projectTitle: n.projectId != null ? _titleOf(n.projectId!) : null,
          ),
        );
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
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      selectedPhase: clearPhase ? null : (selectedPhase ?? this.selectedPhase),
      selectedMachine: clearMachine
          ? null
          : (selectedMachine ?? this.selectedMachine),
    );
  }
}

class _ScoredProject {
  final Project project;
  final double score;
  const _ScoredProject(this.project, this.score);
}
