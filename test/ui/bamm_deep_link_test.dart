// Coverage for the inbound-deep-link fix: a scanned report QR's worId is
// often NOT in whatever's currently loaded (the app boots with a
// step=Emergency default filter; a non-Emergency WO from a printed sheet
// would never be in that initial list). Before this fix, `_autoOpenTargetWo`
// silently did nothing in that case - these tests fail without the
// fetchWorkOrderDetail fallback. Also covers the sheet-integrity staleness
// banner driven by the embedded snapshot hash.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/providers/bamm_provider.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/services/bamm_report_integrity.dart';
import 'package:jokarz_engineering/services/bamm_service.dart';
import 'package:jokarz_engineering/services/storage_service.dart';
import 'package:jokarz_engineering/ui/screens/bamm_screen.dart';

import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/models/filament_profile.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/inbox_item.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/models/project_template.dart';
import 'package:jokarz_engineering/models/activity_log.dart';
import 'package:jokarz_engineering/models/downtime_event.dart';

class _FakeStorageService extends StorageService {
  @override
  Future<Map<String, dynamic>> loadData() async => {
        'projects': <Project>[],
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
}

/// Seed list deliberately does NOT contain the scanned work order - the
/// exact cold-start scenario the fix addresses.
class _ColdStartNotifier extends BammNotifier {
  final BammWorkOrder detail;
  _ColdStartNotifier(this.detail) : super(BammService()) {
    state = BammState(workOrders: [
      BammWorkOrder(worId: 1, worNoSeq: '1', description: 'Unrelated WO', status: 'Registered', step: 'Emergency'),
    ]);
  }

  @override
  Future<void> init() async {}

  @override
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async => worId == detail.worId ? detail : null;
}

List<Override> _overrides(BammNotifier notifier) => [
      storageServiceProvider.overrideWithValue(_FakeStorageService()),
      projectProvider.overrideWith((ref) => ProjectNotifier(_FakeStorageService())),
      bammProvider.overrideWith((ref) => notifier),
    ];

Future<void> _pump(WidgetTester tester, Widget screen, {required BammNotifier notifier}) async {
  await tester.pumpWidget(
    ProviderScope(overrides: _overrides(notifier), child: MaterialApp(home: screen)),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  final scannedWo = BammWorkOrder(
    worId: 700203549,
    worNoSeq: '185610',
    description: 'Motor replacement',
    status: 'Registered',
    step: 'Normal', // NOT Emergency - would never be in the default-filtered list
  );

  testWidgets('a targetWo not in the currently-loaded list is fetched directly and opened', (tester) async {
    await _pump(
      tester,
      BammScreen(targetWo: '${scannedWo.worId}'),
      notifier: _ColdStartNotifier(scannedWo),
    );

    expect(find.textContaining('185610'), findsWidgets, reason: 'the detail dialog must open with the fetched work order');
  });

  testWidgets('a mismatched embedded hash shows the sheet-integrity staleness banner', (tester) async {
    final wrongHash = 'ffffffff'; // definitely not scannedWo's real hash
    await _pump(
      tester,
      BammScreen(targetWo: '${scannedWo.worId}', snapshotHash: wrongHash),
      notifier: _ColdStartNotifier(scannedWo),
    );

    expect(find.byKey(const Key('bamm_stale_warning')), findsOneWidget);
  });

  testWidgets('a matching embedded hash shows no staleness banner', (tester) async {
    final correctHash = bammSnapshotHash(scannedWo);
    await _pump(
      tester,
      BammScreen(targetWo: '${scannedWo.worId}', snapshotHash: correctHash),
      notifier: _ColdStartNotifier(scannedWo),
    );

    expect(find.byKey(const Key('bamm_stale_warning')), findsNothing);
  });

  // The banner text itself is the safety feature - a scan that only checks
  // for the warning KEY (as the three tests above do) would not notice if
  // the print timestamp carried alongside the hash got dropped on the way
  // from the deep link into the dialog. These pin the exact wording.
  group('printed-at timestamp in the warning text', () {
    final wrongHash = 'ffffffff';
    const baseMessage = 'This sheet is out of date - BAMM has changed since it was printed.';

    testWidgets('a mismatched hash with a printed-at timestamp includes the formatted print date', (tester) async {
      final printedAt = DateTime(2026, 9, 17, 8, 30);
      await _pump(
        tester,
        BammScreen(
          targetWo: '${scannedWo.worId}',
          snapshotHash: wrongHash,
          printedAtEpochMs: '${printedAt.millisecondsSinceEpoch}',
        ),
        notifier: _ColdStartNotifier(scannedWo),
      );

      final expectedDate = DateFormat('MMM d, y').format(printedAt);
      expect(
        find.text('This sheet is out of date (printed $expectedDate) - BAMM has changed since it was printed.'),
        findsOneWidget,
        reason: 'the print timestamp carried in the deep link must reach the warning text verbatim',
      );
    });

    testWidgets('a mismatched hash with no printed-at timestamp warns without a date suffix', (tester) async {
      await _pump(
        tester,
        BammScreen(targetWo: '${scannedWo.worId}', snapshotHash: wrongHash),
        notifier: _ColdStartNotifier(scannedWo),
      );

      expect(find.text(baseMessage), findsOneWidget);
    });

    testWidgets('a mismatched hash with a malformed printed-at timestamp does not crash and does not fabricate a date',
        (tester) async {
      await _pump(
        tester,
        BammScreen(
          targetWo: '${scannedWo.worId}',
          snapshotHash: wrongHash,
          printedAtEpochMs: 'not-a-number',
        ),
        notifier: _ColdStartNotifier(scannedWo),
      );

      expect(tester.takeException(), isNull, reason: 'a malformed t= value must never crash the screen');
      expect(find.text(baseMessage), findsOneWidget,
          reason: 'an unparsable timestamp should fall back to the plain warning, not a garbage date');
    });

    testWidgets('a matching hash with a printed-at timestamp still shows no banner', (tester) async {
      final correctHash = bammSnapshotHash(scannedWo);
      await _pump(
        tester,
        BammScreen(
          targetWo: '${scannedWo.worId}',
          snapshotHash: correctHash,
          printedAtEpochMs: '${DateTime(2026, 9, 17).millisecondsSinceEpoch}',
        ),
        notifier: _ColdStartNotifier(scannedWo),
      );

      expect(find.byKey(const Key('bamm_stale_warning')), findsNothing,
          reason: 'a printed-at timestamp alone must never trigger a warning - only a hash mismatch does');
    });
  });
}
