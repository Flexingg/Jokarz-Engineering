import 'package:uuid/uuid.dart';

enum ActivityType {
  taskAdded,
  taskCompleted,
  taskReopened,
  orderAdded,
  orderDelivered,
  orderUndelivered,
  standaloneOrderAdded,
  projectAdded,
  projectCompleted,
  noteAdded,
  noteDeleted,
  logAdded,
  storesRequested,
}

String activityTypeLabel(ActivityType t) => switch (t) {
      ActivityType.taskAdded => 'Task added',
      ActivityType.taskCompleted => 'Task completed',
      ActivityType.taskReopened => 'Task reopened',
      ActivityType.orderAdded => 'Order added',
      ActivityType.orderDelivered => 'Order delivered',
      ActivityType.orderUndelivered => 'Order reopened',
      ActivityType.standaloneOrderAdded => 'Unlinked order added',
      ActivityType.projectAdded => 'Project created',
      ActivityType.projectCompleted => 'Project closed',
      ActivityType.noteAdded => 'Note added',
      ActivityType.noteDeleted => 'Note deleted',
      ActivityType.logAdded => 'Log entry added',
      ActivityType.storesRequested => 'Stores request sent',
    };

String activityTypeIcon(ActivityType t) => switch (t) {
      ActivityType.taskAdded => '➕',
      ActivityType.taskCompleted => '✅',
      ActivityType.taskReopened => '🔄',
      ActivityType.orderAdded => '🛒',
      ActivityType.orderDelivered => '📦',
      ActivityType.orderUndelivered => '↩️',
      ActivityType.standaloneOrderAdded => '🧾',
      ActivityType.projectAdded => '🏗️',
      ActivityType.projectCompleted => '🏁',
      ActivityType.noteAdded => '📝',
      ActivityType.noteDeleted => '🗑️',
      ActivityType.logAdded => '📋',
      ActivityType.storesRequested => '🏬',
    };

/// A timestamped record of an action taken in the app, kept for traceability.
class ActivityLog {
  final String id;
  final ActivityType type;
  final String text;
  final DateTime timestamp;
  final String? projectId;
  final String? projectTitle;

  const ActivityLog({
    String? id,
    required this.type,
    required this.text,
    required this.timestamp,
    this.projectId,
    this.projectTitle,
  }) : id = id ?? '';

  ActivityLog withId() => ActivityLog(
        id: id.isNotEmpty ? id : const Uuid().v4(),
        type: type,
        text: text,
        timestamp: timestamp,
        projectId: projectId,
        projectTitle: projectTitle,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'projectId': projectId,
        'projectTitle': projectTitle,
      };

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    ActivityType parse(String? n) {
      for (final t in ActivityType.values) {
        if (t.name == n) return t;
      }
      return ActivityType.noteAdded;
    }

    return ActivityLog(
      id: json['id'] as String? ?? '',
      type: parse(json['type'] as String?),
      text: json['text'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      projectId: json['projectId'] as String?,
      projectTitle: json['projectTitle'] as String?,
    );
  }
}
