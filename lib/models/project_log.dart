import 'package:uuid/uuid.dart';

enum LogType {
  update('Log Update'),
  milestone('Milestone Achieved'),
  issue('Engineering Issue'),
  fix('Fix / Modification'),
  inspection('Inspection & Measurement'),
  voice('Voice Field Note');

  final String label;
  const LogType(this.label);
}

class ProjectLog {
  final String id;
  final DateTime timestamp;
  final String title;
  final String content;
  final LogType type;
  final List<String> imagePaths;

  ProjectLog({
    String? id,
    DateTime? timestamp,
    required this.title,
    this.content = '',
    this.type = LogType.update,
    List<String>? imagePaths,
  })  : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        imagePaths = imagePaths ?? [];

  ProjectLog copyWith({
    String? title,
    String? content,
    LogType? type,
    List<String>? imagePaths,
  }) {
    return ProjectLog(
      id: id,
      timestamp: timestamp,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'content': content,
      'type': type.name,
      'imagePaths': imagePaths,
    };
  }

  factory ProjectLog.fromJson(Map<String, dynamic> json) {
    return ProjectLog(
      id: json['id'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      title: json['title'] as String? ?? 'Log Entry',
      content: json['content'] as String? ?? '',
      type: LogType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LogType.update,
      ),
      imagePaths: (json['imagePaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
