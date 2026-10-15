// The fabricators' list: model rules and the operations behind it.
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/fab_job.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/services/open_path.dart';
import 'package:jokarz_engineering/services/storage_service.dart';

import '../helpers/mount_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FabJob', () {
    test('starting and finishing stamp the dates, moving back clears completion', () {
      final j = FabJob(title: 'Bracket');
      expect(j.startedDate, isNull);

      final started = j.copyWith(status: FabStatus.inProgress);
      expect(started.startedDate, isNotNull);
      expect(started.completedAt, isNull);

      final done = started.copyWith(status: FabStatus.completed);
      expect(done.completedAt, isNotNull);
      expect(done.startedDate, started.startedDate);

      final reopened = done.copyWith(status: FabStatus.inProgress);
      expect(reopened.completedAt, isNull);
    });

    test('an explicit start date is kept when work begins', () {
      final day = DateTime(2026, 9, 1);
      final j = FabJob(title: 'x', startedDate: day).copyWith(status: FabStatus.inProgress);
      expect(j.startedDate, day);
    });

    test('overdue only while open and past due', () {
      final now = DateTime(2026, 10, 15, 9);
      expect(FabJob(title: 'a', dueDate: DateTime(2026, 10, 14)).isOverdue(now), isTrue);
      expect(FabJob(title: 'a', dueDate: DateTime(2026, 10, 15)).isOverdue(now), isFalse);
      expect(
        FabJob(title: 'a', dueDate: DateTime(2026, 10, 1), status: FabStatus.completed).isOverdue(now),
        isFalse,
      );
    });

    test('JSON round trip, and unknown status falls back to pending', () {
      final j = FabJob(
        title: 'Guard',
        who: 'Sam',
        dueDate: DateTime(2026, 11, 2),
        drawingPath: r'\\srv\dwg\J-1',
        notes: 'rush',
        status: FabStatus.inProgress,
        projectId: 'p',
        taskId: 't',
      );
      final back = FabJob.fromJson(j.toJson());
      expect(back.who, 'Sam');
      expect(back.dueDate, DateTime(2026, 11, 2));
      expect(back.drawingPath, r'\\srv\dwg\J-1');
      expect(back.status, FabStatus.inProgress);
      expect(back.taskId, 't');
      expect(FabJob.fromJson({'title': 'x', 'status': 'bogus'}).status, FabStatus.pending);
    });
  });

  group('adding project tasks', () {
    test('a task goes on the list once, carrying its title, date and reason', () async {
      final h = mountProject(StorageService());
      await h.loaded();
      await h.notifier.addProject(Project(id: 'p', title: 'Line 3', tasks: [
        TaskItem(
          id: 't',
          description: 'Make guard plates',
          scheduledDate: DateTime(2026, 10, 30),
          pendingReason: 'Pending material',
        ),
      ]));

      final first = await h.notifier.addTaskToFabList('p', 't');
      final again = await h.notifier.addTaskToFabList('p', 't');
      expect(again!.id, first!.id);
      expect(h.state.fabJobs, hasLength(1));
      final job = h.state.fabJobs.single;
      expect(job.title, 'Make guard plates');
      expect(job.dueDate, DateTime(2026, 10, 30));
      expect(job.notes, 'Pending material');
      expect(job.projectId, 'p');
      expect(h.notifier.fabJobForTask('t')!.id, job.id);
      expect(await h.notifier.addTaskToFabList('p', 'missing'), isNull);
    });

    test('update and delete', () async {
      final h = mountProject(StorageService());
      await h.loaded();
      final job = FabJob(title: 'Plate');
      await h.notifier.addFabJob(job);
      await h.notifier.updateFabJob(job.copyWith(who: 'Dana'));
      expect(h.state.fabJobs.single.who, 'Dana');
      await h.notifier.deleteFabJob(job.id);
      expect(h.state.fabJobs, isEmpty);
    });

    test('cloud merge keeps the newest edit', () async {
      final h = mountProject(StorageService());
      await h.loaded();
      final old = FabJob(title: 'Plate', updatedAt: DateTime(2026, 1, 1));
      await h.notifier.addFabJob(old);
      final newer = old.copyWith(who: 'Remote', updatedAt: DateTime(2026, 6, 1));
      await h.notifier.mergeCloudFabJobs([newer, FabJob(title: 'Other')]);
      expect(h.state.fabJobs, hasLength(2));
      expect(h.state.fabJobs.firstWhere((j) => j.id == old.id).who, 'Remote');
    });
  });

  test('cleanFolderPath strips quotes and spaces', () {
    expect(cleanFolderPath('  "C:\\Drawings\\J-1"  '), r'C:\Drawings\J-1');
    expect(cleanFolderPath(r'\\srv\dwg'), r'\\srv\dwg');
    expect(cleanFolderPath('   '), '');
  });
}
