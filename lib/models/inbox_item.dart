import 'package:uuid/uuid.dart';

/// An unprocessed item in the quick-capture inbox.
/// Engineers can quickly dump ideas, issues, or requests and triage them later.
class InboxItem {
  final String id;
  final String text;
  final DateTime createdAt;
  final String? audioFilePath;
  final String? photoPath;
  final bool isProcessed;

  InboxItem({
    String? id,
    required this.text,
    DateTime? createdAt,
    this.audioFilePath,
    this.photoPath,
    this.isProcessed = false,
  })  : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  InboxItem copyWith({
    String? text,
    DateTime? createdAt,
    String? audioFilePath,
    bool clearAudio = false,
    String? photoPath,
    bool clearPhoto = false,
    bool? isProcessed,
  }) {
    return InboxItem(
      id: id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      audioFilePath: clearAudio ? null : (audioFilePath ?? this.audioFilePath),
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      isProcessed: isProcessed ?? this.isProcessed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'audioFilePath': audioFilePath,
      'photoPath': photoPath,
      'isProcessed': isProcessed,
    };
  }

  factory InboxItem.fromJson(Map<String, dynamic> json) {
    return InboxItem(
      id: json['id'] as String?,
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      audioFilePath: json['audioFilePath'] as String?,
      photoPath: json['photoPath'] as String?,
      isProcessed: json['isProcessed'] as bool? ?? false,
    );
  }
}
