import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/time_block.dart';
import '../models/slip_log_entry.dart';
import '../services/storage_service.dart';
import 'project_provider.dart' show storageServiceProvider;

/// Weekly slip summary line - the one place the brief says this data must
/// "actually be seen." Derived, never stored.
class WeeklySlipSummary {
  final int pushCount;
  final double averageMinutes;
  final String? worstDayLabel;

  const WeeklySlipSummary({
    required this.pushCount,
    required this.averageMinutes,
    this.worstDayLabel,
  });

  /// "12 pushes this week, average slip 38 min, worst Tuesday" - the exact
  /// wording shape named in the brief.
  String get summaryLine {
    if (pushCount == 0) return 'No pushes this week';
    final avg = averageMinutes.round();
    final worst = worstDayLabel != null ? ', worst $worstDayLabel' : '';
    return '$pushCount push${pushCount == 1 ? '' : 'es'} this week, average slip $avg min$worst';
  }
}

class TimeBlockState {
  final List<TimeBlock> blocks;
  final List<SlipLogEntry> slipLog;
  final bool cascadeEnabled;
  final bool isLoaded;

  const TimeBlockState({
    this.blocks = const [],
    this.slipLog = const [],
    this.cascadeEnabled = true,
    this.isLoaded = false,
  });

  TimeBlockState copyWith({
    List<TimeBlock>? blocks,
    List<SlipLogEntry>? slipLog,
    bool? cascadeEnabled,
    bool? isLoaded,
  }) {
    return TimeBlockState(
      blocks: blocks ?? this.blocks,
      slipLog: slipLog ?? this.slipLog,
      cascadeEnabled: cascadeEnabled ?? this.cascadeEnabled,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  List<TimeBlock> blocksForDay(DateTime day) {
    final list = blocks.where((b) =>
        b.start.year == day.year && b.start.month == day.month && b.start.day == day.day).toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  /// Weekly slip summary over the trailing 7 days from [now].
  WeeklySlipSummary weeklySlipSummary([DateTime? now]) {
    final ref = now ?? DateTime.now();
    final since = ref.subtract(const Duration(days: 7));
    final recent = slipLog.where((e) => e.timestamp.isAfter(since)).toList();
    if (recent.isEmpty) {
      return const WeeklySlipSummary(pushCount: 0, averageMinutes: 0);
    }
    final total = recent.fold<int>(0, (sum, e) => sum + e.minutesMoved);
    final average = total / recent.length;

    const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final byWeekday = <int, int>{};
    for (final e in recent) {
      byWeekday.update(e.timestamp.weekday, (v) => v + e.minutesMoved, ifAbsent: () => e.minutesMoved);
    }
    final worstWeekday = byWeekday.entries.fold<MapEntry<int, int>?>(null, (best, entry) {
      if (best == null || entry.value > best.value) return entry;
      return best;
    });

    return WeeklySlipSummary(
      pushCount: recent.length,
      averageMinutes: average,
      worstDayLabel: worstWeekday != null ? weekdayNames[worstWeekday.key - 1] : null,
    );
  }
}

final timeBlockProvider = StateNotifierProvider<TimeBlockNotifier, TimeBlockState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return TimeBlockNotifier(storage);
});

class TimeBlockNotifier extends StateNotifier<TimeBlockState> {
  final StorageService _storage;

  /// Resolves once the initial load from storage has completed - tests
  /// await this instead of racing the fire-and-forget load in the
  /// constructor (mirrors why `bamm_provider_test.dart`'s fakes bypass
  /// `init()` entirely; here we just expose it since the load is trivial).
  late final Future<void> ready;

  TimeBlockNotifier(this._storage) : super(const TimeBlockState()) {
    ready = _load();
  }

  Future<void> _load() async {
    final blocks = await _storage.loadTimeBlocks();
    final slipLog = await _storage.loadSlipLog();
    final cascadeEnabled = await _storage.loadCascadeEnabled();
    state = state.copyWith(blocks: blocks, slipLog: slipLog, cascadeEnabled: cascadeEnabled, isLoaded: true);
  }

  Future<void> _persistBlocks() => _storage.saveTimeBlocks(state.blocks);
  Future<void> _persistSlipLog() => _storage.saveSlipLog(state.slipLog);

  Future<void> setCascadeEnabled(bool enabled) async {
    state = state.copyWith(cascadeEnabled: enabled);
    await _storage.saveCascadeEnabled(enabled);
  }

  Future<void> scheduleTask({
    required String taskId,
    required String projectId,
    required String title,
    required DateTime start,
    int estimatedMinutes = 30,
  }) async {
    final block = TimeBlock(
      projectId: projectId,
      taskId: taskId,
      title: title,
      start: start,
      estimatedMinutes: estimatedMinutes,
    );
    state = state.copyWith(blocks: [...state.blocks, block]);
    await _persistBlocks();
  }

  TimeBlock? _find(String blockId) => state.blocks.where((b) => b.id == blockId).firstOrNull;

  /// +15 min / +1 hour on [blockId]. When cascade is on, every later block
  /// THAT DAY also moves forward by [by] (a ripple, logged separately from
  /// the manual push on the touched block).
  Future<void> pushBy(String blockId, Duration by, {required SlipLogPushKind kind}) async {
    final touched = _find(blockId);
    if (touched == null) return;
    final now = DateTime.now();
    final newBlocks = <TimeBlock>[];
    final newEntries = <SlipLogEntry>[];

    for (final b in state.blocks) {
      if (b.id == blockId) {
        newBlocks.add(b.copyWith(start: b.start.add(by)));
        newEntries.add(SlipLogEntry(
          blockId: b.id,
          taskId: b.taskId,
          projectId: b.projectId,
          timestamp: now,
          minutesMoved: by.inMinutes,
          pushType: kind == SlipLogPushKind.plus15 ? SlipPushType.plus15Min : SlipPushType.plus1Hour,
          isManual: true,
        ));
      } else if (state.cascadeEnabled && _isSameDay(b.start, touched.start) && b.start.isAfter(touched.start)) {
        newBlocks.add(b.copyWith(start: b.start.add(by)));
        newEntries.add(SlipLogEntry(
          blockId: b.id,
          taskId: b.taskId,
          projectId: b.projectId,
          timestamp: now,
          minutesMoved: by.inMinutes,
          pushType: SlipPushType.rippleCascade,
          isManual: false,
        ));
      } else {
        newBlocks.add(b);
      }
    }

    state = state.copyWith(blocks: newBlocks, slipLog: [...state.slipLog, ...newEntries]);
    await _persistBlocks();
    await _persistSlipLog();
  }

  /// Moves just [blockId] to the same time tomorrow. Never cascades - a
  /// different day doesn't ripple today's remaining blocks.
  Future<void> pushToTomorrow(String blockId) async {
    final touched = _find(blockId);
    if (touched == null) return;
    final newStart = touched.start.add(const Duration(days: 1));
    state = state.copyWith(
      blocks: [
        for (final b in state.blocks) b.id == blockId ? b.copyWith(start: newStart) : b,
      ],
      slipLog: [
        ...state.slipLog,
        SlipLogEntry(
          blockId: blockId,
          taskId: touched.taskId,
          projectId: touched.projectId,
          timestamp: DateTime.now(),
          minutesMoved: newStart.difference(touched.start).inMinutes,
          pushType: SlipPushType.pushTomorrow,
          isManual: true,
        ),
      ],
    );
    await _persistBlocks();
    await _persistSlipLog();
  }

  /// Moves [blockId] AND every later block that day to the same time
  /// tomorrow - a deliberate bulk action the user chose, not a ripple
  /// side-effect, so every moved block logs a manual entry.
  Future<void> pushRestOfDay(String blockId) async {
    final touched = _find(blockId);
    if (touched == null) return;
    final now = DateTime.now();
    final newBlocks = <TimeBlock>[];
    final newEntries = <SlipLogEntry>[];

    for (final b in state.blocks) {
      final isTouchedOrLater =
          b.id == blockId || (_isSameDay(b.start, touched.start) && b.start.isAfter(touched.start));
      if (isTouchedOrLater) {
        final newStart = b.start.add(const Duration(days: 1));
        newBlocks.add(b.copyWith(start: newStart));
        newEntries.add(SlipLogEntry(
          blockId: b.id,
          taskId: b.taskId,
          projectId: b.projectId,
          timestamp: now,
          minutesMoved: newStart.difference(b.start).inMinutes,
          pushType: SlipPushType.pushRestOfDay,
          isManual: true,
        ));
      } else {
        newBlocks.add(b);
      }
    }

    state = state.copyWith(blocks: newBlocks, slipLog: [...state.slipLog, ...newEntries]);
    await _persistBlocks();
    await _persistSlipLog();
  }

  /// Marks [blockId] partial (some work done, logged in [doneNote]) and
  /// schedules a new block for whatever's left, placed right after the last
  /// block currently scheduled that day (or now, if it was the last one).
  Future<void> markInterrupted(String blockId, {required String doneNote}) async {
    final touched = _find(blockId);
    if (touched == null) return;
    final now = DateTime.now();
    final elapsed = now.difference(touched.start).inMinutes.clamp(0, touched.estimatedMinutes);
    final remainder = touched.estimatedMinutes - elapsed;

    final sameDay = state.blocksForDay(touched.start);
    final last = sameDay.isEmpty ? touched : sameDay.last;
    final remainderStart = last.id == touched.id ? now : last.end;

    final remainderBlock = TimeBlock(
      projectId: touched.projectId,
      taskId: touched.taskId,
      title: touched.title,
      start: remainderStart,
      estimatedMinutes: remainder > 0 ? remainder : touched.estimatedMinutes,
    );

    state = state.copyWith(
      blocks: [
        for (final b in state.blocks)
          if (b.id == blockId)
            b.copyWith(status: TimeBlockStatus.partial, actualMinutes: elapsed, doneNote: doneNote)
          else
            b,
        remainderBlock,
      ],
      slipLog: [
        ...state.slipLog,
        SlipLogEntry(
          blockId: remainderBlock.id,
          taskId: touched.taskId,
          projectId: touched.projectId,
          timestamp: now,
          minutesMoved: remainderBlock.estimatedMinutes,
          pushType: SlipPushType.interruptedRemainder,
          isManual: true,
        ),
      ],
    );
    await _persistBlocks();
    await _persistSlipLog();
  }

  /// Closes [blockId] with the actual minutes it took. No slip-log entry -
  /// closing on time (or early/late) isn't a "push"; the estimate/actual
  /// pair alone is the data the brief asks to keep.
  Future<void> closeBlock(String blockId, {required int actualMinutes}) async {
    state = state.copyWith(
      blocks: [
        for (final b in state.blocks)
          if (b.id == blockId) b.copyWith(status: TimeBlockStatus.done, actualMinutes: actualMinutes) else b,
      ],
    );
    await _persistBlocks();
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

enum SlipLogPushKind { plus15, plus1Hour }
