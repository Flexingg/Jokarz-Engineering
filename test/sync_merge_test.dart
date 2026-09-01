import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/services/storage_service.dart';

/// Waits for the notifier's async initial load to finish. In tests the platform
/// storage calls (path_provider) are unmocked, so StorageService degrades
/// gracefully to blank data and all saves are no-ops — which is fine for
/// exercising the in-memory merge/removal logic.
Future<void> _waitForLoad(ProjectNotifier n) async {
  while (n.state.isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceNote updatedAt (conflict resolution field)', () {
    test('defaults to not earlier than timestamp when not provided', () {
      final note = VoiceNote(title: 't', transcript: 'x');
      expect(note.updatedAt.isBefore(note.timestamp), isFalse);
    });

    test('round-trips through JSON', () {
      final note = VoiceNote(
        id: 'n1',
        title: 't',
        transcript: 'x',
        updatedAt: DateTime.utc(2026, 9, 1, 12, 30),
      );
      expect(VoiceNote.fromJson(note.toJson()).updatedAt, note.updatedAt);
    });

    test('legacy records without updatedAt fall back to timestamp', () {
      final legacy = VoiceNote.fromJson({
        'id': 'n1',
        'timestamp': '2020-01-01T00:00:00.000',
      });
      expect(legacy.updatedAt.toIso8601String(), '2020-01-01T00:00:00.000');
    });
  });

  group('mergeCloudNotes', () {
    test('keeps the newer edit instead of cloud last-write-wins', () async {
      final notifier = ProjectNotifier(StorageService());
      await _waitForLoad(notifier);

      final local = VoiceNote(
        id: 'n1',
        title: 'Local',
        transcript: 'local v2',
        updatedAt: DateTime.utc(2026, 9, 1, 12),
      );
      await notifier.addVoiceNote(local);

      // Stale remote copy is OLDER than the local edit -> local must win.
      final staleRemote = VoiceNote(
        id: 'n1',
        title: 'Local',
        transcript: 'stale remote v1',
        updatedAt: DateTime.utc(2026, 9, 1, 10),
      );
      await notifier.mergeCloudNotes([staleRemote]);
      expect(notifier.state.voiceNotes.first.transcript, 'local v2');

      // Newer remote edit -> remote wins.
      final newRemote = VoiceNote(
        id: 'n1',
        title: 'Local',
        transcript: 'fresh remote v3',
        updatedAt: DateTime.utc(2026, 9, 1, 14),
      );
      await notifier.mergeCloudNotes([newRemote]);
      expect(notifier.state.voiceNotes.first.transcript, 'fresh remote v3');
    });
  });

  group('local-only removals (sync resurrection guard)', () {
    test('removeVoiceNoteLocal removes from local state', () async {
      final notifier = ProjectNotifier(StorageService());
      await _waitForLoad(notifier);

      await notifier.addVoiceNote(
          VoiceNote(id: 'a', title: 'A', transcript: 'x'));
      await notifier.removeVoiceNoteLocal('a');
      expect(notifier.state.voiceNotes.where((n) => n.id == 'a'), isEmpty);
    });

    test('removeProjectLocal removes from local state', () async {
      final notifier = ProjectNotifier(StorageService());
      await _waitForLoad(notifier);

      await notifier.addProject(Project(id: 'p1', title: 'Test project'));
      expect(notifier.getProjectById('p1'), isNotNull);
      await notifier.removeProjectLocal('p1');
      expect(notifier.getProjectById('p1'), isNull);
    });
  });

  group('overdueTasks', () {
    test('only incomplete tasks with a past date are overdue', () async {
      final n = ProjectNotifier(StorageService());
      await _waitForLoad(n);
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final tomorrow = DateTime(today.year, today.month, today.day + 1);

      await n.addProject(Project(id: 'p1', title: 'P', tasks: [
        TaskItem(id: 't1', description: 'past incomplete', scheduledDate: yesterday),
        TaskItem(id: 't2', description: 'today incomplete', scheduledDate: today),
        TaskItem(id: 't3', description: 'future', scheduledDate: tomorrow),
        TaskItem(id: 't4', description: 'past done', scheduledDate: yesterday, isCompleted: true),
      ]));

      expect(n.state.overdueTasks.length, 1);
      expect(n.state.overdueTasks.first.task.id, 't1');
    });

    test('rescheduleTaskToToday moves an overdue task to today, keeping time',
        () async {
      final n = ProjectNotifier(StorageService());
      await _waitForLoad(n);
      final today = DateTime.now();
      final past = DateTime(today.year, today.month, today.day - 5, 9, 30);

      await n.addProject(Project(id: 'p1', title: 'P', tasks: [
        TaskItem(id: 't1', description: 'x', scheduledDate: past),
      ]));

      await n.rescheduleTaskToToday('p1', 't1');
      final task = n.getProjectById('p1')!.tasks.first;
      expect(task.scheduledDate!.day, today.day);
      expect(task.scheduledDate!.hour, 9); // time-of-day preserved
      expect(n.state.overdueTasks, isEmpty);
    });
  });
}
