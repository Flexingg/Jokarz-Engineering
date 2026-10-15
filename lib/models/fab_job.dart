import 'package:uuid/uuid.dart';

enum FabStatus { pending, inProgress, completed }

String fabStatusLabel(FabStatus s) => switch (s) {
      FabStatus.pending => 'Pending',
      FabStatus.inProgress => 'In progress',
      FabStatus.completed => 'Completed',
    };

/// One job on the fabricators' list: what to make, who is making it, the
/// dates, and where the drawings live. Can be created from a project task
/// ([projectId] / [taskId]) or typed in directly.
class FabJob {
  final String id;
  final String title;
  final String who;
  final DateTime? dueDate;
  final DateTime? startedDate;
  final DateTime? completedAt;

  /// A Windows folder (or file) path, e.g. `\\server\drawings\J-1042`.
  final String drawingPath;
  final String notes;
  final FabStatus status;
  final String? projectId;
  final String? taskId;
  final DateTime createdAt;

  /// Last edit time; drives last-write-wins cloud merging.
  final DateTime updatedAt;

  FabJob({
    String? id,
    required this.title,
    this.who = '',
    this.dueDate,
    this.startedDate,
    this.completedAt,
    this.drawingPath = '',
    this.notes = '',
    this.status = FabStatus.pending,
    this.projectId,
    this.taskId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  bool get isOpen => status != FabStatus.completed;

  bool isOverdue([DateTime? now]) {
    final d = dueDate;
    if (d == null || !isOpen) return false;
    final n = now ?? DateTime.now();
    return DateTime(d.year, d.month, d.day).isBefore(DateTime(n.year, n.month, n.day));
  }

  /// Changing [status] keeps the dates honest: starting a job stamps today as
  /// its start (unless one is set), finishing stamps the completion, and
  /// moving it back clears the completion.
  FabJob copyWith({
    String? title,
    String? who,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? startedDate,
    bool clearStartedDate = false,
    String? drawingPath,
    String? notes,
    FabStatus? status,
    String? projectId,
    bool clearProject = false,
    String? taskId,
    DateTime? updatedAt,
  }) {
    final newStatus = status ?? this.status;
    var started = clearStartedDate ? null : (startedDate ?? this.startedDate);
    var completed = completedAt;
    if (newStatus != this.status) {
      if (newStatus != FabStatus.pending && started == null) {
        started = DateTime.now();
      }
      completed = newStatus == FabStatus.completed ? DateTime.now() : null;
    }
    return FabJob(
      id: id,
      title: title ?? this.title,
      who: who ?? this.who,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      startedDate: started,
      completedAt: completed,
      drawingPath: drawingPath ?? this.drawingPath,
      notes: notes ?? this.notes,
      status: newStatus,
      projectId: clearProject ? null : (projectId ?? this.projectId),
      taskId: clearProject ? null : (taskId ?? this.taskId),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'who': who,
        'dueDate': dueDate?.toIso8601String(),
        'startedDate': startedDate?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'drawingPath': drawingPath,
        'notes': notes,
        'status': status.name,
        'projectId': projectId,
        'taskId': taskId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FabJob.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        json[key] != null ? DateTime.tryParse(json[key] as String) : null;
    return FabJob(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      who: json['who'] as String? ?? '',
      dueDate: date('dueDate'),
      startedDate: date('startedDate'),
      completedAt: date('completedAt'),
      drawingPath: json['drawingPath'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      status: FabStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => FabStatus.pending,
      ),
      projectId: json['projectId'] as String?,
      taskId: json['taskId'] as String?,
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
    );
  }
}
