// Closes the actual gap the widget-level tests in bamm_deep_link_test.dart
// can't reach: those construct BammScreen directly with printedAtEpochMs
// already set, so they never touch the one line that produces it -
// app_router.dart's `printedAtEpochMs: state.uri.queryParameters['t']`.
// Setting that line to `null` broke no test before this file existed.
// These drive the REAL `appRouter` through a `/bamm?...&h=...&t=...` URL
// (the exact shape `parseDeepLinkUri` builds for a scanned report QR) so the
// query-parameter extraction itself is exercised end to end.
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
import 'package:jokarz_engineering/router/app_router.dart';

import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/models/filament_profile.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/inbox_item.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/models/project_template.dart';
import 'package:jokarz_engineering/models/activity_log.dart';
import 'package:jokarz_engineering/models/downtime_event.dart';

/// Same shape as the fake used in bamm_deep_link_test.dart (duplicated -
/// these are file-private and can't be shared across test files).
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

/// Seed list deliberately does NOT contain the scanned work order, matching
/// the cold-start scenario a scanned sheet lands in.
class _ColdStartNotifier extends BammNotifier {
  final BammWorkOrder detail;
  _ColdStartNotifier(this.detail) : super(BammService()) {
    state = BammState(workOrders: [
      BammWorkOrder(worId: 1, worNoSeq: '1', description: 'Unrelated WO', status: 'Registered', step: 'Emergency'),
    ]);
  }

  @override
  Future<void> init() async {}

  // `setSearchQuery` (triggered by BammScreen's targetWo handling) debounces
  // into this - left un-overridden it hits a real BammService socket
  // connect to the (deliberately unreachable, per BAMM docs) live host,
  // which hangs forever under flutter_test's fake async clock and trips the
  // "Timer still pending" teardown assertion once a test pumps far enough
  // (e.g. via pumpAndSettle) for the debounce to fire.
  @override
  Future<void> refreshWorkOrders() async {}

  @override
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async => worId == detail.worId ? detail : null;
}

List<Override> _overrides(BammNotifier notifier) => [
      storageServiceProvider.overrideWithValue(_FakeStorageService()),
      projectProvider.overrideWith((ref) => ProjectNotifier(_FakeStorageService())),
      bammProvider.overrideWith((ref) => notifier),
    ];

void main() {
  final scannedWo = BammWorkOrder(
    worId: 700203549,
    worNoSeq: '185610',
    description: 'Motor replacement',
    status: 'Registered',
    step: 'Normal',
  );

  // `appRouter` is the app's single global GoRouter instance, so its current
  // location survives across tests in this file unless reset.
  tearDown(() => appRouter.go('/'));

  Future<void> pumpAt(WidgetTester tester, String location, {required BammNotifier notifier}) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _overrides(notifier), child: MaterialApp.router(routerConfig: appRouter)),
    );
    appRouter.go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('a scanned-QR URL with mismatched h and a t timestamp surfaces the warning with that printed date',
      (tester) async {
    final printedAt = DateTime(2026, 9, 17, 8, 30);
    await pumpAt(
      tester,
      '/bamm?wo=${scannedWo.worId}&h=ffffffff&t=${printedAt.millisecondsSinceEpoch}',
      notifier: _ColdStartNotifier(scannedWo),
    );

    final expectedDate = DateFormat('MMM d, y').format(printedAt);
    expect(
      find.text('This sheet is out of date (printed $expectedDate) - BAMM has changed since it was printed.'),
      findsOneWidget,
      reason: 'app_router.dart must forward the URL\'s t= query parameter into BammScreen.printedAtEpochMs '
          'unchanged - if that plumbing is dropped (e.g. hardcoded to null) this date can never appear',
    );
  });

  testWidgets('a scanned-QR URL with a matching h shows no warning even though t is present', (tester) async {
    final correctHash = bammSnapshotHash(scannedWo);
    await pumpAt(
      tester,
      '/bamm?wo=${scannedWo.worId}&h=$correctHash&t=${DateTime(2026, 9, 17).millisecondsSinceEpoch}',
      notifier: _ColdStartNotifier(scannedWo),
    );

    expect(find.byKey(const Key('bamm_stale_warning')), findsNothing);
  });

  testWidgets('a scanned-QR URL with a malformed t does not crash and does not fabricate a date', (tester) async {
    await pumpAt(
      tester,
      '/bamm?wo=${scannedWo.worId}&h=ffffffff&t=not-a-number',
      notifier: _ColdStartNotifier(scannedWo),
    );

    expect(tester.takeException(), isNull, reason: 'a malformed t= value reaching the router must never crash');
    expect(
      find.text('This sheet is out of date - BAMM has changed since it was printed.'),
      findsOneWidget,
      reason: 'unparsable timestamp falls back to the plain warning, not a garbage date',
    );
  });

  testWidgets('a scanned-QR URL with no t at all warns (from the hash mismatch) without a date suffix',
      (tester) async {
    await pumpAt(
      tester,
      '/bamm?wo=${scannedWo.worId}&h=ffffffff',
      notifier: _ColdStartNotifier(scannedWo),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text('This sheet is out of date - BAMM has changed since it was printed.'),
      findsOneWidget,
    );
  });
}
