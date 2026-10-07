// The README's headline rule: active projects hold unique priorities 1..X,
// moving one to #1 bumps the rest down, and closed projects leave the queue
// but keep their last priority as a lifetime record.
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/services/storage_service.dart';

import '../helpers/mount_notifier.dart';

List<String> _activeOrder(MountedProject h) =>
    (h.state.activeProjects.toList()
          ..sort((a, b) => a.priority.compareTo(b.priority)))
        .map((p) => p.id)
        .toList();

List<int> _activePriorities(MountedProject h) =>
    (h.state.activeProjects.map((p) => p.priority).toList()..sort());

Future<MountedProject> _mountWith(List<String> ids) async {
  final h = mountProject(StorageService());
  await h.loaded();
  for (final id in ids) {
    // priority 99 => append at the end of the active queue
    await h.notifier.addProject(Project(id: id, title: id, priority: 99));
  }
  return h;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new active projects append and stay unique 1..N', () async {
    final h = await _mountWith(['a', 'b', 'c']);
    expect(_activeOrder(h), ['a', 'b', 'c']);
    expect(_activePriorities(h), [1, 2, 3]);
  });

  test('adding at #1 bumps every existing project down one', () async {
    final h = await _mountWith(['a', 'b']);
    await h.notifier.addProject(Project(id: 'top', title: 'top', priority: 1));
    expect(_activeOrder(h), ['top', 'a', 'b']);
    expect(_activePriorities(h), [1, 2, 3]);
  });

  test('setProjectPriority moves a project and re-numbers the rest', () async {
    final h = await _mountWith(['a', 'b', 'c', 'd']);
    await h.notifier.setProjectPriority('d', 1);
    expect(_activeOrder(h), ['d', 'a', 'b', 'c']);
    expect(_activePriorities(h), [1, 2, 3, 4]);

    await h.notifier.setProjectPriority('d', 3);
    expect(_activeOrder(h), ['a', 'b', 'd', 'c']);
    expect(_activePriorities(h), [1, 2, 3, 4]);
  });

  test('an out-of-range priority is clamped, never creating gaps', () async {
    final h = await _mountWith(['a', 'b']);
    await h.notifier.setProjectPriority('a', 50);
    expect(_activeOrder(h), ['b', 'a']);
    expect(_activePriorities(h), [1, 2]);
  });

  test(
    'completing a project removes it from the queue, freezes its priority and stamps completedAt',
    () async {
      final h = await _mountWith(['a', 'b', 'c']);
      final b = h.notifier.getProjectById('b')!;
      expect(b.priority, 2);

      await h.notifier.updateProject(b.copyWith(phase: ProjectPhases.complete));

      expect(_activeOrder(h), ['a', 'c']);
      expect(_activePriorities(h), [
        1,
        2,
      ], reason: 'remaining active projects close the gap');
      final done = h.notifier.getProjectById('b')!;
      expect(
        done.priority,
        2,
        reason: 'lifetime priority is frozen as a record',
      );
      expect(done.completedAt, isNotNull);
      expect(h.state.terminalProjects.map((p) => p.id), ['b']);
    },
  );

  test(
    'reopening a closed project clears completedAt and re-enters the queue',
    () async {
      final h = await _mountWith(['a', 'b']);
      await h.notifier.updateProject(
        h.notifier
            .getProjectById('a')!
            .copyWith(phase: ProjectPhases.cancelled),
      );
      expect(h.notifier.getProjectById('a')!.completedAt, isNotNull);

      await h.notifier.updateProject(
        h.notifier
            .getProjectById('a')!
            .copyWith(phase: ProjectPhases.pending, priority: 1),
      );

      expect(h.notifier.getProjectById('a')!.completedAt, isNull);
      expect(_activeOrder(h), ['a', 'b']);
      expect(_activePriorities(h), [1, 2]);
    },
  );

  test(
    'drag-and-drop reorder follows Flutter ReorderableListView semantics',
    () async {
      final h = await _mountWith(['a', 'b', 'c', 'd']);
      // Drag "a" (index 0) to after "c": Flutter reports newIndex 3.
      await h.notifier.reorderProjects(0, 3);
      expect(_activeOrder(h), ['b', 'c', 'a', 'd']);
      expect(_activePriorities(h), [1, 2, 3, 4]);

      // Out-of-range drag source is ignored.
      await h.notifier.reorderProjects(9, 0);
      expect(_activeOrder(h), ['b', 'c', 'a', 'd']);
    },
  );

  test('deleting a project re-numbers the active queue', () async {
    final h = await _mountWith(['a', 'b', 'c']);
    await h.notifier.deleteProject('a');
    expect(_activeOrder(h), ['b', 'c']);
    expect(_activePriorities(h), [1, 2]);
  });
}
