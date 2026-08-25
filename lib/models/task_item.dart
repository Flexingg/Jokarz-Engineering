import 'package:uuid/uuid.dart';

class TaskItem {
  final String id;
  final String description;
  final DateTime? scheduledDate;
  final String pendingReason; // e.g. "Pending parts", "Pending email", "Pending downtime"
  final bool isCompleted;

  TaskItem({
    String? id,
    required this.description,
    this.scheduledDate,
    this.pendingReason = '',
    this.isCompleted = false,
  }) : id = id ?? const Uuid().v4();

  TaskItem copyWith({
    String? description,
    DateTime? scheduledDate,
    bool clearScheduledDate = false,
    String? pendingReason,
    bool? isCompleted,
  }) {
    return TaskItem(
      id: id,
      description: description ?? this.description,
      scheduledDate: clearScheduledDate ? null : (scheduledDate ?? this.scheduledDate),
      pendingReason: pendingReason ?? this.pendingReason,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'pendingReason': pendingReason,
      'isCompleted': isCompleted,
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String?,
      description: json['description'] as String? ?? '',
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.tryParse(json['scheduledDate'] as String)
          : null,
      pendingReason: json['pendingReason'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}
