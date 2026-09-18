// Coverage for the time-blocking provider: cascading push (default ON),
// the non-cascading toggle, push-to-tomorrow/push-rest-of-day, interrupted
// blocks, closing, and the weekly slip summary line. Every push-family
// method must be proven to actually move blocks and log the right slip
// entries - a callback-count test would not catch a broken cascade.
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/slip_log_entry.dart';
import 'package:jokarz_engineering/models/time_block.dart';
import 'package:jokarz_engineering/providers/time_block_provider.dart';
import 'package:jokarz_engineering/services/storage_service.dart';

/// In-memory fake - never touches `path_provider`.
class _FakeStorage extends StorageService {
  List<TimeBlock> blocks = [];
  List<SlipLogEntry> slipLog = [];
  bool cascadeEnabled = true;

  @override
  Future<List<TimeBlock>> loadTimeBlocks() async => blocks;
  @override
  Future<void> saveTimeBlocks(List<TimeBlock> b) async => blocks = b;
  @override
  Future<List<SlipLogEntry>> loadSlipLog() async => slipLog;
  @override
  Future<void> saveSlipLog(List<SlipLogEntry> e) async => slipLog = e;
  @override
  Future<bool> loadCascadeEnabled() async => cascadeEnabled;
  @override
  Future<void> saveCascadeEnabled(bool v) async => cascadeEnabled = v;
}

/// Exposes a way to seed `state` directly for the pure-`weeklySlipSummary`
/// test below, since `StateNotifier.state` is protected outside subclasses.
class _SeedableNotifier extends TimeBlockNotifier {
  _SeedableNotifier(super.storage);
  void seed(TimeBlockState s) => state = s;
}

TimeBlock _block(String id, DateTime start, {int minutes = 30, String taskId = 't1'}) => TimeBlock(
      id: id,
      projectId: 'p1',
      taskId: taskId,
      title: 'Task $id',
      start: start,
      estimatedMinutes: minutes,
    );

void main() {
  group('cascading push', () {
    late _FakeStorage storage;
    late TimeBlockNotifier notifier;
    final day = DateTime(2026, 9, 21, 8, 0);

    setUp(() async {
      storage = _FakeStorage();
      storage.blocks = [
        _block('a', day), // 08:00
        _block('b', day.add(const Duration(hours: 1))), // 09:00
        _block('c', day.add(const Duration(hours: 2))), // 10:00
      ];
      notifier = TimeBlockNotifier(storage);
      await notifier.ready;
    });

    test('cascade ON (default): +15 min ripples every later block that day', () async {
      await notifier.pushBy('a', const Duration(minutes: 15), kind: SlipLogPushKind.plus15);

      final byId = {for (final b in notifier.state.blocks) b.id: b};
      expect(byId['a']!.start, day.add(const Duration(minutes: 15)));
      expect(byId['b']!.start, day.add(const Duration(hours: 1, minutes: 15)), reason: 'later block ripples forward');
      expect(byId['c']!.start, day.add(const Duration(hours: 2, minutes: 15)), reason: 'later block ripples forward');

      // One manual entry (the touched block) + two ripple entries.
      expect(notifier.state.slipLog.length, 3);
      final manual = notifier.state.slipLog.where((e) => e.isManual).toList();
      final ripples = notifier.state.slipLog.where((e) => !e.isManual).toList();
      expect(manual.length, 1);
      expect(manual.single.blockId, 'a');
      expect(manual.single.pushType, SlipPushType.plus15Min);
      expect(ripples.length, 2);
      expect(ripples.every((e) => e.pushType == SlipPushType.rippleCascade), isTrue);
      expect(ripples.map((e) => e.blockId).toSet(), {'b', 'c'});
    });

    test('cascade OFF: +1 hour moves only the touched block', () async {
      await notifier.setCascadeEnabled(false);
      await notifier.pushBy('a', const Duration(hours: 1), kind: SlipLogPushKind.plus1Hour);

      final byId = {for (final b in notifier.state.blocks) b.id: b};
      expect(byId['a']!.start, day.add(const Duration(hours: 1)));
      expect(byId['b']!.start, day.add(const Duration(hours: 1)), reason: 'must NOT ripple with cascade off');
      expect(byId['c']!.start, day.add(const Duration(hours: 2)), reason: 'must NOT ripple with cascade off');

      expect(notifier.state.slipLog.length, 1, reason: 'no ripple entries when cascade is off');
      expect(notifier.state.slipLog.single.pushType, SlipPushType.plus1Hour);
    });

    test('a push that does not cascade would fail the ON test above', () async {
      // Guard has teeth: prove the ON-by-default test isn't accidentally
      // passing because of coincidental block placement.
      await notifier.pushBy('a', const Duration(minutes: 15), kind: SlipLogPushKind.plus15);
      final b = notifier.state.blocks.firstWhere((x) => x.id == 'b');
      expect(b.start, isNot(day.add(const Duration(hours: 1))), reason: 'b must have moved if cascade worked');
    });

    test('push to tomorrow moves only the touched block, never cascades', () async {
      await notifier.pushToTomorrow('a');
      final byId = {for (final b in notifier.state.blocks) b.id: b};
      expect(byId['a']!.start, day.add(const Duration(days: 1)));
      expect(byId['b']!.start, day.add(const Duration(hours: 1)), reason: 'same-day blocks stay put');
      expect(notifier.state.slipLog.single.pushType, SlipPushType.pushTomorrow);
      expect(notifier.state.slipLog.single.isManual, isTrue);
    });

    test('push rest of day moves the touched block AND every later block to tomorrow, all manual', () async {
      await notifier.pushRestOfDay('b');
      final byId = {for (final b in notifier.state.blocks) b.id: b};
      expect(byId['a']!.start, day, reason: 'earlier block is untouched');
      expect(byId['b']!.start, day.add(const Duration(hours: 1)).add(const Duration(days: 1)));
      expect(byId['c']!.start, day.add(const Duration(hours: 2)).add(const Duration(days: 1)));
      expect(notifier.state.slipLog.length, 2);
      expect(notifier.state.slipLog.every((e) => e.isManual && e.pushType == SlipPushType.pushRestOfDay), isTrue);
    });
  });

  group('interrupted / close', () {
    late _FakeStorage storage;
    late TimeBlockNotifier notifier;

    setUp(() async {
      storage = _FakeStorage();
      storage.blocks = [_block('a', DateTime.now().subtract(const Duration(minutes: 10)), minutes: 30)];
      notifier = TimeBlockNotifier(storage);
      await notifier.ready;
    });

    test('interrupted marks the block partial, records the done note, and pushes a remainder block', () async {
      await notifier.markInterrupted('a', doneNote: 'Got the cover off, waiting on a part');

      final original = notifier.state.blocks.firstWhere((b) => b.id == 'a');
      expect(original.status, TimeBlockStatus.partial);
      expect(original.doneNote, 'Got the cover off, waiting on a part');
      expect(original.actualMinutes, isNotNull);

      final remainder = notifier.state.blocks.where((b) => b.id != 'a').toList();
      expect(remainder, hasLength(1), reason: 'the remainder must be pushed as a new block');
      expect(remainder.single.taskId, original.taskId);
      expect(remainder.single.estimatedMinutes, greaterThan(0));

      final entry = notifier.state.slipLog.single;
      expect(entry.pushType, SlipPushType.interruptedRemainder);
      expect(entry.isManual, isTrue);
    });

    test('closing records the actual and does NOT write a slip-log entry', () async {
      await notifier.closeBlock('a', actualMinutes: 25);
      final closed = notifier.state.blocks.single;
      expect(closed.status, TimeBlockStatus.done);
      expect(closed.actualMinutes, 25);
      expect(notifier.state.slipLog, isEmpty, reason: 'closing on time/early/late is not a push');
    });
  });

  group('weeklySlipSummary', () {
    test('matches a hand-computed count/average/worst-day over a fixed reference time', () async {
      final storage = _FakeStorage();
      final notifier = _SeedableNotifier(storage);
      await notifier.ready;

      final now = DateTime(2026, 9, 22, 12, 0); // a Tuesday
      SlipLogEntry entry(DateTime ts, int minutes) => SlipLogEntry(
            blockId: 'b',
            taskId: 't',
            projectId: 'p',
            timestamp: ts,
            minutesMoved: minutes,
            pushType: SlipPushType.plus15Min,
            isManual: true,
          );

      notifier.seed(notifier.state.copyWith(slipLog: [
        entry(now.subtract(const Duration(days: 1)), 30), // Monday: 30
        entry(now, 60), // Tuesday: 60 + 20 = 80 (worst)
        entry(now, 20),
        entry(now.subtract(const Duration(days: 10)), 999), // outside the 7-day window
      ]));

      final summary = notifier.state.weeklySlipSummary(now);
      expect(summary.pushCount, 3, reason: 'the 10-day-old entry must be excluded');
      expect(summary.averageMinutes, closeTo((30 + 60 + 20) / 3, 0.001));
      expect(summary.worstDayLabel, 'Tuesday');
      expect(summary.summaryLine, contains('3 pushes this week'));
      expect(summary.summaryLine, contains('worst Tuesday'));
    });

    test('no pushes in the window produces the empty-state line, not a divide-by-zero crash', () {
      const state = TimeBlockState();
      final summary = state.weeklySlipSummary(DateTime(2026, 9, 22));
      expect(summary.pushCount, 0);
      expect(summary.summaryLine, 'No pushes this week');
    });
  });
}
