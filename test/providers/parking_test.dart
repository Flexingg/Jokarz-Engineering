// "Park until": a project drops to the bottom of the queue and returns to its
// old rank by itself on the chosen day.
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/activity_log.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/services/storage_service.dart';

import '../helpers/mount_notifier.dart';

List<String> _queue(MountedProject h) =>
    h.state.activeProjects.map((p) => '${p.id}:${p.priority}').toList();

Future<MountedProject> _mountWith(List<String> ids) async {
  final h = mountProject(StorageService());
  await h.loaded();
  for (final id in ids) {
    await h.notifier.addProject(Project(id: id, title: id, priority: 99));
  }
  return h;
}

final _today = DateTime(2026, 10, 7);
DateTime _day(int offset) => _today.add(Duration(days: offset));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parking', () {
    test(
      'parks to the bottom, remembers its rank, and the rest close the gap',
      () async {
        final h = await _mountWith(['a', 'b', 'c', 'd']);
        await h.notifier.parkProject('b', _day(3), reason: 'Waiting on parts');

        expect(_queue(h), ['a:1', 'c:2', 'd:3', 'b:4']);
        final b = h.notifier.getProjectById('b')!;
        expect(b.isParked, isTrue);
        expect(b.parkRestorePriority, 2);
        expect(b.parkReason, 'Waiting on parts');
        expect(b.parkedUntil, _day(3));
      },
    );

    test(
      'nothing happens before the date; it returns on the date, at its old rank',
      () async {
        final h = await _mountWith(['a', 'b', 'c', 'd']);
        await h.notifier.parkProject('b', _day(3));

        expect(await h.notifier.applyDueParks(now: _day(2)), isEmpty);
        expect(_queue(h), ['a:1', 'c:2', 'd:3', 'b:4']);

        expect(await h.notifier.applyDueParks(now: _day(3)), ['b']);
        expect(_queue(h), ['a:1', 'b:2', 'c:3', 'd:4']);
        final b = h.notifier.getProjectById('b')!;
        expect(b.isParked, isFalse);
        expect(b.parkRestorePriority, isNull);
      },
    );

    test('applyDueParks is idempotent (every device runs it)', () async {
      final h = await _mountWith(['a', 'b', 'c']);
      await h.notifier.parkProject('a', _day(1));
      await h.notifier.applyDueParks(now: _day(5));
      final first = _queue(h);
      expect(await h.notifier.applyDueParks(now: _day(5)), isEmpty);
      expect(_queue(h), first);
      expect(first, ['a:1', 'b:2', 'c:3']);
    });

    test(
      'a late return (app was closed for days) still lands correctly',
      () async {
        final h = await _mountWith(['a', 'b', 'c']);
        await h.notifier.parkProject('a', _day(1));
        expect(await h.notifier.applyDueParks(now: _day(30)), ['a']);
        expect(_queue(h), ['a:1', 'b:2', 'c:3']);
      },
    );

    test('the remembered rank is clamped when the queue got shorter', () async {
      final h = await _mountWith(['a', 'b', 'c', 'd']);
      await h.notifier.parkProject('d', _day(2)); // remembers rank 4
      await h.notifier.deleteProject('a');
      await h.notifier.deleteProject('b');
      await h.notifier.applyDueParks(now: _day(2));
      expect(_queue(h), ['c:1', 'd:2']);
    });

    test(
      'several projects returning together keep their old relative order',
      () async {
        final h = await _mountWith(['a', 'b', 'c', 'd']);
        await h.notifier.parkProject('c', _day(1));
        await h.notifier.parkProject('a', _day(1));
        expect(_queue(h), ['b:1', 'd:2', 'c:3', 'a:4']);
        await h.notifier.applyDueParks(now: _day(1));
        expect(_queue(h), ['a:1', 'b:2', 'c:3', 'd:4']);
      },
    );

    test(
      're-parking keeps the original rank and just changes the date',
      () async {
        final h = await _mountWith(['a', 'b', 'c']);
        await h.notifier.parkProject('a', _day(2), reason: 'Waiting on parts');
        await h.notifier.parkProject('a', _day(9), reason: 'Downtime window');
        final a = h.notifier.getProjectById('a')!;
        expect(a.parkRestorePriority, 1);
        expect(a.parkedUntil, _day(9));
        expect(a.parkReason, 'Downtime window');
      },
    );

    test('"Return now" ends the park immediately', () async {
      final h = await _mountWith(['a', 'b', 'c']);
      await h.notifier.parkProject('a', _day(9));
      await h.notifier.unparkProject('a');
      expect(_queue(h), ['a:1', 'b:2', 'c:3']);
    });

    test('a new project is inserted above parked ones, never below', () async {
      final h = await _mountWith(['a', 'b']);
      await h.notifier.parkProject('a', _day(5));
      await h.notifier.addProject(Project(id: 'n', title: 'n', priority: 99));
      expect(_queue(h), ['b:1', 'n:2', 'a:3']);
    });

    test('manually re-ranking a parked project cancels the park', () async {
      final h = await _mountWith(['a', 'b', 'c']);
      await h.notifier.parkProject('a', _day(5));
      await h.notifier.setProjectPriority('a', 1);
      expect(h.notifier.getProjectById('a')!.isParked, isFalse);
      expect(_queue(h), ['a:1', 'b:2', 'c:3']);
    });

    test(
      'dragging a parked project cancels the park; dragging others cannot go below it',
      () async {
        final h = await _mountWith(['a', 'b', 'c']);
        await h.notifier.parkProject('c', _day(5));
        // queue: a, b, c(parked). Drag "a" to the very end.
        await h.notifier.reorderProjects(0, 3);
        expect(_queue(h), ['b:1', 'a:2', 'c:3']);
        expect(h.notifier.getProjectById('c')!.isParked, isTrue);

        // Drag the parked one to the top.
        await h.notifier.reorderProjects(2, 0);
        expect(_queue(h), ['c:1', 'b:2', 'a:3']);
        expect(h.notifier.getProjectById('c')!.isParked, isFalse);
      },
    );

    test(
      'closing a parked project clears the park and keeps the queue tidy',
      () async {
        final h = await _mountWith(['a', 'b', 'c']);
        await h.notifier.parkProject('a', _day(5));
        await h.notifier.updateProject(
          h.notifier
              .getProjectById('a')!
              .copyWith(phase: ProjectPhases.complete),
        );
        expect(h.notifier.getProjectById('a')!.parkedUntil, isNull);
        expect(_queue(h), ['b:1', 'c:2']);
      },
    );

    test('editing other fields of a parked project keeps it parked', () async {
      final h = await _mountWith(['a', 'b']);
      await h.notifier.parkProject('a', _day(5));
      await h.notifier.updateProject(
        h.notifier.getProjectById('a')!.copyWith(title: 'Renamed'),
      );
      expect(h.notifier.getProjectById('a')!.isParked, isTrue);
      expect(_queue(h), ['b:1', 'a:2']);
    });

    test(
      'parked projects are left out of the "needs attention" queue',
      () async {
        final h = await _mountWith(['a', 'b']);
        await h.notifier.parkProject('a', _day(5));
        expect(h.state.queuedProjects.map((p) => p.id), ['b']);
      },
    );

    test('parking and returning are written to the activity log', () async {
      final h = await _mountWith(['a', 'b']);
      await h.notifier.parkProject('a', _day(2), reason: 'Waiting on parts');
      await h.notifier.applyDueParks(now: _day(2));
      final types = h.state.activityLog.map((l) => l.type).toList();
      expect(
        types,
        containsAll([ActivityType.projectParked, ActivityType.projectUnparked]),
      );
      expect(
        h.state.activityLog.any((l) => l.text.contains('Waiting on parts')),
        isTrue,
      );
    });

    test('a closed project cannot be parked', () async {
      final h = await _mountWith(['a', 'b']);
      await h.notifier.updateProject(
        h.notifier.getProjectById('a')!.copyWith(phase: ProjectPhases.complete),
      );
      await h.notifier.parkProject('a', _day(3));
      expect(h.notifier.getProjectById('a')!.parkedUntil, isNull);
    });
  });

  group('Project JSON', () {
    test('park fields round-trip', () {
      final p = Project(
        title: 't',
        parkedUntil: DateTime(2026, 10, 10),
        parkRestorePriority: 2,
        parkReason: 'Waiting on parts',
      );
      final back = Project.fromJson(p.toJson());
      expect(back.parkedUntil, DateTime(2026, 10, 10));
      expect(back.parkRestorePriority, 2);
      expect(back.parkReason, 'Waiting on parts');
      expect(back.isParked, isTrue);
    });

    test('older data without park fields loads as not parked', () {
      final p = Project.fromJson({'title': 'old', 'priority': 3});
      expect(p.isParked, isFalse);
      expect(p.parkReason, '');
    });

    test('copyWith(clearPark) removes all three fields', () {
      final p = Project(
        title: 't',
        parkedUntil: DateTime(2026, 1, 1),
        parkRestorePriority: 2,
        parkReason: 'x',
      ).copyWith(clearPark: true);
      expect(p.parkedUntil, isNull);
      expect(p.parkRestorePriority, isNull);
      expect(p.parkReason, '');
    });
  });
}
