import 'package:uuid/uuid.dart';

class VoiceNote {
  final String id;
  final DateTime timestamp;
  final String title;
  final String transcript;
  final int durationSeconds;
  final String? projectId;
  final DateTime? date; // calendar-attached date (if any)
  final String? photoPath; // annotated photo for photo notes

  VoiceNote({
    String? id,
    DateTime? timestamp,
    required this.title,
    required this.transcript,
    this.durationSeconds = 0,
    this.projectId,
    this.date,
    this.photoPath,
  })  : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  VoiceNote copyWith({
    String? title,
    String? transcript,
    int? durationSeconds,
    String? projectId,
    bool clearProjectId = false,
    DateTime? date,
    bool clearDate = false,
    String? photoPath,
    bool clearPhotoPath = false,
  }) {
    return VoiceNote(
      id: id,
      timestamp: timestamp,
      title: title ?? this.title,
      transcript: transcript ?? this.transcript,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      date: clearDate ? null : (date ?? this.date),
      photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'transcript': transcript,
      'durationSeconds': durationSeconds,
      'projectId': projectId,
      'date': date?.toIso8601String(),
      'photoPath': photoPath,
    };
  }

  factory VoiceNote.fromJson(Map<String, dynamic> json) {
    return VoiceNote(
      id: json['id'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      title: json['title'] as String? ?? 'Voice Note',
      transcript: json['transcript'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      projectId: json['projectId'] as String?,
      date: json['date'] != null ? DateTime.tryParse(json['date'] as String) : null,
      photoPath: json['photoPath'] as String?,
    );
  }
}
