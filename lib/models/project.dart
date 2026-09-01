import 'package:uuid/uuid.dart';
import 'task_item.dart';
import 'order_item.dart';
import 'project_log.dart';

enum ProjectCategory {
  maintenance('Maintenance'),
  kaizen('Kaizen'),
  capital('Capital');

  final String label;
  const ProjectCategory(this.label);
}

class ProjectPhases {
  static const String idea = 'Idea';
  static const String pending = 'Pending';
  static const String installation = 'Installation';
  static const String validation = 'Validation';
  static const String complete = 'Complete';
  static const String cancelled = 'Cancelled';

  static const List<String> standardPhases = [
    idea,
    pending,
    installation,
    validation,
    complete,
    cancelled,
  ];

  static bool isTerminal(String phase) {
    final lower = phase.trim().toLowerCase();
    return lower == 'complete' || lower == 'completed' || lower == 'cancelled' || lower == 'canceled';
  }
}

class Project {
  final String id;
  final String title;
  final String description;
  /// Free-form engineering notes attached directly to the project
  /// (distinct from per-entry field logs in `logs`).
  final String notes;
  final ProjectCategory category;
  final String phase;
  final DateTime? completedAt;
  final int priority; // 1..X for active, or frozen lifetime highest priority
  final double cost;
  final String machine;
  final String subAssembly;
  final String? nextPendingTaskId;
  final List<String> tags;
  final List<TaskItem> tasks;
  final List<OrderItem> orders;
  final List<ProjectLog> logs;
  final List<String> photoPaths;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Tracks when the engineer last took a meaningful action on this project
  /// (logged a note, toggled a task, changed a phase). Used for queue scoring.
  final DateTime? lastActionAt;

  /// Returns individual machine names split on '/' separator.
  /// e.g. "Line 3 / Packer A" → ['Line 3', 'Packer A']
  List<String> get machineList {
    if (machine.trim().isEmpty) return [];
    return machine.split('/').map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
  }

  /// Days since last action (or since creation if never actioned).
  int get daysSinceLastAction {
    final ref = lastActionAt ?? createdAt;
    return DateTime.now().difference(ref).inDays;
  }

  Project({
    String? id,
    required this.title,
    this.description = '',
    this.notes = '',
    this.category = ProjectCategory.maintenance,
    this.phase = ProjectPhases.idea,
    this.completedAt,
    this.priority = 1,
    this.cost = 0.0,
    this.machine = '',
    this.subAssembly = '',
    this.nextPendingTaskId,
    List<String>? tags,
    List<TaskItem>? tasks,
    List<OrderItem>? orders,
    List<ProjectLog>? logs,
    List<String>? photoPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastActionAt,
  })  : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4(),
        tags = tags ?? [],
        tasks = tasks ?? [],
        orders = orders ?? [],
        logs = logs ?? [],
        photoPaths = photoPaths ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isCompletedOrCancelled => ProjectPhases.isTerminal(phase);

  double get totalOrdersCost =>
      orders.fold(0.0, (prev, o) => prev + o.price);

  /// Total project cost = the manually-entered [cost] plus the value of all
  /// attached orders (PO spend). This is the figure shown to the engineer.
  double get totalProjectCost => cost + totalOrdersCost;

  int get undeliveredOrdersCount =>
      orders.where((o) => !o.delivered).length;

  int get completedTasksCount =>
      tasks.where((t) => t.isCompleted).length;

  TaskItem? get nextPendingTask {
    if (nextPendingTaskId != null) {
      try {
        return tasks.firstWhere((t) => t.id == nextPendingTaskId);
      } catch (_) {}
    }
    // Fallback to first incomplete task with a pending reason or first incomplete task
    try {
      return tasks.firstWhere((t) => !t.isCompleted && t.pendingReason.isNotEmpty);
    } catch (_) {
      try {
        return tasks.firstWhere((t) => !t.isCompleted);
      } catch (_) {
        return null;
      }
    }
  }

  Project copyWith({
    String? title,
    String? description,
    String? notes,
    ProjectCategory? category,
    String? phase,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? priority,
    double? cost,
    String? machine,
    String? subAssembly,
    String? nextPendingTaskId,
    bool clearNextPendingTask = false,
    List<String>? tags,
    List<TaskItem>? tasks,
    List<OrderItem>? orders,
    List<ProjectLog>? logs,
    List<String>? photoPaths,
    DateTime? updatedAt,
    DateTime? lastActionAt,
    bool clearLastActionAt = false,
  }) {
    return Project(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      phase: phase ?? this.phase,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      priority: priority ?? this.priority,
      cost: cost ?? this.cost,
      machine: machine ?? this.machine,
      subAssembly: subAssembly ?? this.subAssembly,
      nextPendingTaskId: clearNextPendingTask
          ? null
          : (nextPendingTaskId ?? this.nextPendingTaskId),
      tags: tags ?? this.tags,
      tasks: tasks ?? this.tasks,
      orders: orders ?? this.orders,
      logs: logs ?? this.logs,
      photoPaths: photoPaths ?? this.photoPaths,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastActionAt: clearLastActionAt ? null : (lastActionAt ?? this.lastActionAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'notes': notes,
      'category': category.name,
      'phase': phase,
      'completedAt': completedAt?.toIso8601String(),
      'priority': priority,
      'cost': cost,
      'machine': machine,
      'subAssembly': subAssembly,
      'nextPendingTaskId': nextPendingTaskId,
      'tags': tags,
      'tasks': tasks.map((e) => e.toJson()).toList(),
      'orders': orders.map((e) => e.toJson()).toList(),
      'logs': logs.map((e) => e.toJson()).toList(),
      'photoPaths': photoPaths,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastActionAt': lastActionAt?.toIso8601String(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Untitled Project',
      description: json['description'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      category: ProjectCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ProjectCategory.maintenance,
      ),
      phase: json['phase'] as String? ?? (json['status'] as String? ?? ProjectPhases.idea),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      cost: (json['cost'] as num?)?.toDouble() ??
          ((json['budget'] as num?)?.toDouble() ?? 0.0),
      machine: json['machine'] as String? ?? '',
      subAssembly: json['subAssembly'] as String? ?? '',
      nextPendingTaskId: json['nextPendingTaskId'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      orders: (json['orders'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      logs: (json['logs'] as List<dynamic>?)
              ?.map((e) => ProjectLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      photoPaths: (json['photoPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastActionAt: json['lastActionAt'] != null
          ? DateTime.tryParse(json['lastActionAt'] as String)
          : null,
    );
  }
}
