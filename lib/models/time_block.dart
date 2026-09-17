import 'package:uuid/uuid.dart';

/// Lifecycle of a scheduled [TimeBlock].
enum TimeBlockStatus {
  scheduled,
  partial, // interrupted - some work done, remainder pushed to a new block
  done;

  static TimeBlockStatus fromName(String? name) => TimeBlockStatus.values
      .firstWhere((s) => s.name == name, orElse: () => TimeBlockStatus.scheduled);
}

/// A scheduled start time + duration for a project task - personal planning
/// data, stored locally only (`StorageService.loadTimeBlocks`/`saveTimeBlocks`).
/// NEVER written to BAMM.
class TimeBlock {
  final String id;
  final String projectId;
  final String taskId;
  /// Denormalized task description at scheduling time, so the block still
  /// displays correctly even if the source task is later edited or removed.
  final String title;
  final DateTime start;
  final int estimatedMinutes;
  /// Set when the block is closed (done) or interrupted (partial).
  final int? actualMinutes;
  final TimeBlockStatus status;
  /// What got done, recorded on an interrupted (partial) block.
  final String doneNote;
  final DateTime createdAt;

  TimeBlock({
    String? id,
    required this.projectId,
    required this.taskId,
    required this.title,
    required this.start,
    required this.estimatedMinutes,
    this.actualMinutes,
    this.status = TimeBlockStatus.scheduled,
    this.doneNote = '',
    DateTime? createdAt,
  })  : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  DateTime get end => start.add(Duration(minutes: estimatedMinutes));

  TimeBlock copyWith({
    String? projectId,
    String? taskId,
    String? title,
    DateTime? start,
    int? estimatedMinutes,
    int? actualMinutes,
    bool clearActualMinutes = false,
    TimeBlockStatus? status,
    String? doneNote,
  }) {
    return TimeBlock(
      id: id,
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      start: start ?? this.start,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: clearActualMinutes ? null : (actualMinutes ?? this.actualMinutes),
      status: status ?? this.status,
      doneNote: doneNote ?? this.doneNote,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'taskId': taskId,
        'title': title,
        'start': start.toIso8601String(),
        'estimatedMinutes': estimatedMinutes,
        'actualMinutes': actualMinutes,
        'status': status.name,
        'doneNote': doneNote,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TimeBlock.fromJson(Map<String, dynamic> json) => TimeBlock(
        id: json['id'] as String?,
        projectId: json['projectId'] as String? ?? '',
        taskId: json['taskId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        start: DateTime.tryParse(json['start'] as String? ?? '') ?? DateTime.now(),
        estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 30,
        actualMinutes: (json['actualMinutes'] as num?)?.toInt(),
        status: TimeBlockStatus.fromName(json['status'] as String?),
        doneNote: json['doneNote'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
