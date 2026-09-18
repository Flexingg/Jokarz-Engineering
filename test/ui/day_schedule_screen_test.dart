// Widget coverage for the Day Schedule screen: gaps render with real
// durations, scheduling from the tray (both tap and real drag) creates a
// block, and the weekly slip summary line / cascade toggle are visible and
// wired to the real provider. Also proves the "no notifications" guard: no
// platform notification/permission channel is ever invoked from this
// screen or the time-block provider.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/models/filament_profile.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/inbox_item.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/models/project_template.dart';
import 'package:jokarz_engineering/models/activity_log.dart';
import 'package:jokarz_engineering/models/downtime_event.dart';
import 'package:jokarz_engineering/models/time_block.dart';
import 'package:jokarz_engineering/models/slip_log_entry.dart';

import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/providers/time_block_provider.dart';
import 'package:jokarz_engineering/services/storage_service.dart';
import 'package:jokarz_engineering/ui/screens/day_schedule_screen.dart';

class _FakeStorage extends StorageService {
  final List<Project> seedProjects;
  List<TimeBlock> blocks;
  List<SlipLogEntry> slipLog = [];

  _FakeStorage({this.seedProjects = const [], this.blocks = const []});

  @override
  Future<Map<String, dynamic>> loadData() async => {
        'projects': [...seedProjects],
        'voiceNotes': <VoiceNote>[],
        'filaments': <FilamentProfile>[],
        'standaloneOrders': <StandaloneOrder>[],
        'inboxItems': <InboxItem>[],
        'vendors': <Vendor>[],
        'customTemplates': <ProjectTemplate>[],
        'snoozedProjects': <String, String>{},
      };

  @override
  Future<List<ActivityLog>> loadActivityLog() async => [];
  @override
  Future<List<DowntimeEvent>> loadDowntimes() async => [];
  @override
  Future<void> saveActivityLog(List<ActivityLog> logs) async {}
  @override
  Future<void> saveDowntimes(List<DowntimeEvent> downtimes) async {}
  @override
  Future<Map<String, String>> loadKeyBindings() async => {};
  @override
  Future<void> saveKeyBindings(Map<String, String> bindings) async {}
  @override
  Future<void> saveData({
    required List<Project> projects,
    required List<VoiceNote> voiceNotes,
    required List<FilamentProfile> customFilaments,
    List<StandaloneOrder> standaloneOrders = const [],
    List<InboxItem> inboxItems = const [],
    List<Vendor> vendors = const [],
    List<ProjectTemplate> customTemplates = const [],
    Map<String, String> snoozedProjects = const {},
  }) async {}

  @override
  Future<List<TimeBlock>> loadTimeBlocks() async => blocks;
  @override
  Future<void> saveTimeBlocks(List<TimeBlock> b) async => blocks = b;
  @override
  Future<List<SlipLogEntry>> loadSlipLog() async => slipLog;
  @override
  Future<void> saveSlipLog(List<SlipLogEntry> e) async => slipLog = e;
  @override
  Future<bool> loadCascadeEnabled() async => true;
  @override
  Future<void> saveCascadeEnabled(bool v) async {}
}

Project _projectWithTask(String taskDescription, {String projectId = 'proj-1', String taskId = 'task-1'}) {
  return Project(
    id: projectId,
    title: 'Line 3 Rebuild',
    tasks: [TaskItem(id: taskId, description: taskDescription)],
  );
}

Future<void> _pump(WidgetTester tester, {required List<Override> overrides}) async {
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const MaterialApp(home: DayScheduleScreen())),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('gaps and timeline', () {
    testWidgets('a real gap between two blocks renders with the correct minute count', (tester) async {
      final today = DateTime.now();
      final morning = DateTime(today.year, today.month, today.day, 8, 0);
      final storage = _FakeStorage(blocks: [
        TimeBlock(id: 'a', projectId: 'p', taskId: 't1', title: 'First', start: morning, estimatedMinutes: 30),
        // Gap: 08:30 -> 09:15 = 45 minutes free.
        TimeBlock(id: 'b', projectId: 'p', taskId: 't2', title: 'Second', start: morning.add(const Duration(minutes: 75)), estimatedMinutes: 30),
      ]);

      await _pump(tester, overrides: [
        storageServiceProvider.overrideWithValue(storage),
        timeBlockProvider.overrideWith((ref) => TimeBlockNotifier(storage)),
        projectProvider.overrideWith((ref) => ProjectNotifier(storage)),
      ]);

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.textContaining('45 min free'), findsOneWidget);
    });

    testWidgets('no gap strip renders when blocks are back-to-back', (tester) async {
      final today = DateTime.now();
      final morning = DateTime(today.year, today.month, today.day, 8, 0);
      final storage = _FakeStorage(blocks: [
        TimeBlock(id: 'a', projectId: 'p', taskId: 't1', title: 'First', start: morning, estimatedMinutes: 30),
        TimeBlock(id: 'b', projectId: 'p', taskId: 't2', title: 'Second', start: morning.add(const Duration(minutes: 30)), estimatedMinutes: 30),
      ]);

      await _pump(tester, overrides: [
        storageServiceProvider.overrideWithValue(storage),
        timeBlockProvider.overrideWith((ref) => TimeBlockNotifier(storage)),
        projectProvider.overrideWith((ref) => ProjectNotifier(storage)),
      ]);

      expect(find.textContaining('min free'), findsNothing);
    });
  });

  group('scheduling from the tray', () {
    testWidgets('tapping a gap opens the tray and picking a task schedules it there', (tester) async {
      final today = DateTime.now();
      final morning = DateTime(today.year, today.month, today.day, 8, 0);
      final project = _projectWithTask('Replace bearing');
      final storage = _FakeStorage(seedProjects: [project], blocks: [
        TimeBlock(id: 'a', projectId: 'p', taskId: 'other-task', title: 'Anchor', start: morning, estimatedMinutes: 30),
        TimeBlock(id: 'b', projectId: 'p', taskId: 'other-task-2', title: 'Later', start: morning.add(const Duration(minutes: 90)), estimatedMinutes: 30),
      ]);

      await _pump(tester, overrides: [
        storageServiceProvider.overrideWithValue(storage),
        timeBlockProvider.overrideWith((ref) => TimeBlockNotifier(storage)),
        projectProvider.overrideWith((ref) => ProjectNotifier(storage)),
      ]);

      // The unscheduled task is offered in the bottom tray.
      expect(find.text('Replace bearing'), findsOneWidget);

      await tester.tap(find.byKey(const Key('gap_0')));
      await tester.pumpAndSettle();
      expect(find.text('Schedule a task here'), findsOneWidget);

      await tester.tap(find.text('Replace bearing').last);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(DayScheduleScreen)));
      final scheduled = container.read(timeBlockProvider).blocks.where((b) => b.taskId == 'task-1');
      expect(scheduled, hasLength(1), reason: 'tapping the task in the gap sheet must create a block');
      expect(scheduled.single.start, morning.add(const Duration(minutes: 30)), reason: 'scheduled at the gap start');
    });

    testWidgets('dragging a tray task onto a gap creates a block', (tester) async {
      final today = DateTime.now();
      final morning = DateTime(today.year, today.month, today.day, 8, 0);
      final project = _projectWithTask('Grease conveyor', taskId: 'drag-task');
      final storage = _FakeStorage(seedProjects: [project], blocks: [
        TimeBlock(id: 'a', projectId: 'p', taskId: 'other-task', title: 'Anchor', start: morning, estimatedMinutes: 30),
        TimeBlock(id: 'b', projectId: 'p', taskId: 'other-task-2', title: 'Later', start: morning.add(const Duration(minutes: 90)), estimatedMinutes: 30),
      ]);

      await _pump(tester, overrides: [
        storageServiceProvider.overrideWithValue(storage),
        timeBlockProvider.overrideWith((ref) => TimeBlockNotifier(storage)),
        projectProvider.overrideWith((ref) => ProjectNotifier(storage)),
      ]);

      final traySource = find.byKey(const Key('tray_drag-task'));
      final gapTarget = find.byKey(const Key('gap_0'));
      expect(traySource, findsOneWidget);
      expect(gapTarget, findsOneWidget);

      final delta = tester.getCenter(gapTarget) - tester.getCenter(traySource);
      await tester.drag(traySource, delta);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(DayScheduleScreen)));
      final scheduled = container.read(timeBlockProvider).blocks.where((b) => b.taskId == 'drag-task');
      expect(scheduled, hasLength(1), reason: 'dropping onto a gap must create a block');
    });
  });

  group('weekly slip summary + cascade toggle', () {
    testWidgets('the summary line is visible and the cascade switch reflects/updates real state', (tester) async {
      final storage = _FakeStorage();
      await _pump(tester, overrides: [
        storageServiceProvider.overrideWithValue(storage),
        timeBlockProvider.overrideWith((ref) => TimeBlockNotifier(storage)),
        projectProvider.overrideWith((ref) => ProjectNotifier(storage)),
      ]);

      expect(find.byKey(const Key('weekly_slip_summary')), findsOneWidget);
      expect(find.textContaining('No pushes this week'), findsOneWidget);

      final switchFinder = find.byKey(const Key('cascade_toggle'));
      expect(tester.widget<Switch>(switchFinder).value, isTrue, reason: 'cascade defaults ON');

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(DayScheduleScreen)));
      expect(container.read(timeBlockProvider).cascadeEnabled, isFalse);
    });
  });

  group('no notifications guard', () {
    testWidgets('scheduling a task and pushing it never invokes a platform notification/permission channel', (tester) async {
      final calls = <String>[];
      const channels = [
        'dexterous.com/flutter/local_notifications',
        'flutter_local_notifications',
        'com.dexterous.flutterlocalnotifications',
        'permission_handler',
      ];
      for (final name in channels) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel(name),
          (call) async {
            calls.add('$name:${call.method}');
            return null;
          },
        );
      }
      addTearDown(() {
        for (final name in channels) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(MethodChannel(name), null);
        }
      });

      final today = DateTime.now();
      final morning = DateTime(today.year, today.month, today.day, 8, 0);
      final project = _projectWithTask('Inspect belt');
      final storage = _FakeStorage(seedProjects: [project], blocks: [
        TimeBlock(id: 'a', projectId: 'p', taskId: 'other', title: 'Anchor', start: morning, estimatedMinutes: 30),
      ]);

      await _pump(tester, overrides: [
        storageServiceProvider.overrideWithValue(storage),
        timeBlockProvider.overrideWith((ref) => TimeBlockNotifier(storage)),
        projectProvider.overrideWith((ref) => ProjectNotifier(storage)),
      ]);

      await tester.tap(find.byKey(const Key('block_a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+15 minutes'));
      await tester.pumpAndSettle();

      expect(calls, isEmpty, reason: 'time blocking must stay quiet - no phone/Home Assistant notifications');
    });
  });
}
