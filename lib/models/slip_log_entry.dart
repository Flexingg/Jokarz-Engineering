import 'package:uuid/uuid.dart';

/// Why a [TimeBlock] moved. Distinguishes a direct user action on the
/// touched block from a same-day ripple caused by [SlipPushType.plus15Min]/
/// [SlipPushType.plus1Hour] cascading later blocks forward.
enum SlipPushType {
  plus15Min,
  plus1Hour,
  pushTomorrow,
  pushRestOfDay,
  rippleCascade,
  interruptedRemainder;

  static SlipPushType fromName(String? name) => SlipPushType.values
      .firstWhere((s) => s.name == name, orElse: () => SlipPushType.plus15Min);
}

/// One recorded push of a [TimeBlock] - the reason the time-blocking feature
/// exists at all: enough detail per block/task to later tell "under-estimated"
/// apart from "got interrupted." Personal planning data, stored locally only,
/// never written to BAMM.
class SlipLogEntry {
  final String id;
  final String blockId;
  final String taskId;
  final String projectId;
  final DateTime timestamp;
  final int minutesMoved;
  final SlipPushType pushType;
  /// False only for [SlipPushType.rippleCascade] entries - every other push
  /// type is something the user directly chose on the touched block.
  final bool isManual;

  SlipLogEntry({
    String? id,
    required this.blockId,
    required this.taskId,
    required this.projectId,
    required this.timestamp,
    required this.minutesMoved,
    required this.pushType,
    required this.isManual,
  }) : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'blockId': blockId,
        'taskId': taskId,
        'projectId': projectId,
        'timestamp': timestamp.toIso8601String(),
        'minutesMoved': minutesMoved,
        'pushType': pushType.name,
        'isManual': isManual,
      };

  factory SlipLogEntry.fromJson(Map<String, dynamic> json) => SlipLogEntry(
        id: json['id'] as String?,
        blockId: json['blockId'] as String? ?? '',
        taskId: json['taskId'] as String? ?? '',
        projectId: json['projectId'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        minutesMoved: (json['minutesMoved'] as num?)?.toInt() ?? 0,
        pushType: SlipPushType.fromName(json['pushType'] as String?),
        isManual: json['isManual'] as bool? ?? true,
      );
}
