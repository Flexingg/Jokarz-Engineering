import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/activity_log.dart';
import '../../models/downtime_event.dart';
import '../../models/project.dart';
import '../../models/standalone_order.dart';
import '../../models/task_item.dart';
import '../../models/voice_note.dart';
import '../engineering_state.dart';

/// The handful of core operations the domain mixins in this folder build on.
/// `ProjectNotifier` implements them; each mixin is `on EngineeringNotifierCore`
/// so it can persist, log and reuse CRUD without owning that logic.
abstract class EngineeringNotifierCore extends Notifier<EngineeringState> {
  /// Writes the current state to disk.
  Future<void> persist();

  /// Records a timestamped, user-visible activity entry.
  Future<void> logActivity(ActivityType type, String text,
      {String? pid, String? ptitle});

  /// Re-numbers active projects 1..N, leaving terminal projects untouched.
  List<Project> rebalancePriorities(List<Project> list);

  Project? getProjectById(String id);
  Future<void> updateProject(Project updated);
  Future<void> addTask(String projectId, TaskItem task);
  Future<void> addStandaloneOrder(StandaloneOrder order);
  Future<void> addDowntime(DowntimeEvent d);
  Future<void> addVoiceNote(VoiceNote note);
}
