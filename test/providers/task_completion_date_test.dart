// Tasks remember the moment they were checked off.
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/activity_log.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/services/storage_service.dart';

import '../helpers/mount_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('checking a task stamps completedAt; reopening clears it', () async {
    final h = mountProject(StorageService());
    await h.loaded();
    await h.notifier.addProject(
      Project(id: 'p', title: 'P', tasks: [TaskItem(id: 't', description: 'Do it')]),
    );
    TaskItem task() => h.notifier.getProjectById('p')!.tasks.single;

    final before = DateTime.now();
    await h.notifier.toggleTaskCompleted('p', 't');
    expect(task().isCompleted, isTrue);
    expect(task().completedAt, isNotNull);
    expect(task().completedAt!.isBefore(before), isFalse);

    await h.notifier.toggleTaskCompleted('p', 't');
    expect(task().isCompleted, isFalse);
    expect(task().completedAt, isNull);
  });

  test('completedAt survives a JSON round trip', () {
    final at = DateTime(2026, 9, 1, 14, 30);
    final t = TaskItem(description: 'x', isCompleted: true, completedAt: at);
    expect(TaskItem.fromJson(t.toJson()).completedAt, at);
    expect(TaskItem.fromJson({'description': 'old', 'isCompleted': true}).completedAt, isNull);
  });

  test('older completed tasks are dated from the activity log', () async {
    final h = mountProject(StorageService());
    await h.loaded();
    await h.notifier.addProject(
      Project(id: 'p', title: 'P', tasks: [
        TaskItem(id: 't', description: 'Old job', isCompleted: true),
        TaskItem(id: 'u', description: 'Mystery', isCompleted: true),
      ]),
    );
    final when = DateTime(2026, 8, 3, 9);
    await h.notifier.addActivityLog(ActivityLog(
      type: ActivityType.taskCompleted,
      text: 'Completed task: Old job',
      timestamp: when,
      projectId: 'p',
    ));
    await h.notifier.backfillTaskCompletionDates();
    final tasks = h.notifier.getProjectById('p')!.tasks;
    expect(tasks.firstWhere((t) => t.id == 't').completedAt, when);
    expect(tasks.firstWhere((t) => t.id == 'u').completedAt, isNull);
  });
}
