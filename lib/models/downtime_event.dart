import 'package:uuid/uuid.dart';

/// A planned maintenance / downtime event attached to a calendar date and a
/// machine/line. Tapping it shows all projects on that machine.
class DowntimeEvent {
  final String id;
  final String machine;
  final String title;
  final DateTime date; // the day
  final String timeRange; // free text e.g. "07:00 - 11:00"

  const DowntimeEvent({
    String? id,
    required this.machine,
    required this.title,
    required this.date,
    this.timeRange = '',
  }) : id = id ?? '';

  DowntimeEvent withId() => DowntimeEvent(
        id: id.isNotEmpty ? id : const Uuid().v4(),
        machine: machine,
        title: title,
        date: date,
        timeRange: timeRange,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'machine': machine,
        'title': title,
        'date': date.toIso8601String(),
        'timeRange': timeRange,
      };

  factory DowntimeEvent.fromJson(Map<String, dynamic> json) => DowntimeEvent(
        id: json['id'] as String? ?? '',
        machine: json['machine'] as String? ?? '',
        title: json['title'] as String? ?? '',
        date: json['date'] != null
            ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
            : DateTime.now(),
        timeRange: json['timeRange'] as String? ?? '',
      );
}
