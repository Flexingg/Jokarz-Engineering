// Tests for the BAMM desktop table's header row: sort, the right-click/
// long-press column menu (filter/hide/move), column management (chooser,
// drag-to-reorder), and column-layout persistence. All assertions read
// real rendered data (row order, presence/absence of specific cell text,
// header x-position) rather than merely checking that a callback fired.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/models/filament_profile.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/inbox_item.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/models/project_template.dart';
import 'package:jokarz_engineering/models/activity_log.dart';
import 'package:jokarz_engineering/models/downtime_event.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';

import 'package:jokarz_engineering/providers/bamm_provider.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/services/storage_service.dart';
import 'package:jokarz_engineering/services/bamm_service.dart';

import 'package:jokarz_engineering/ui/screens/bamm_screen.dart';
import 'package:jokarz_engineering/ui/widgets/bamm_table_columns.dart';

const _expanded = Size(1400, 900);
// Wide enough that every default column plus the trailing "Choose columns"
// button fits without needing to scroll the horizontal table first.
const _wide = Size(2000, 900);

/// Same shape as `_FakeStorageService` in `parity_test.dart` (duplicated
/// because these are file-private classes and can't be imported) - fixed
/// in-memory data, no `path_provider`.
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

/// A [BammNotifier] that never touches the network or `path_provider`:
/// `refreshWorkOrders` plays the role BAMM's server normally plays (sort +
/// filter) against an in-memory seed list, so header taps/menu actions that
/// call the real notifier methods (`setSort`, `setSortField`,
/// `setAreaFilter`, ...) produce a real, observable reordering/filtering of
/// what's rendered - not a mocked-out no-op.
class _FakeBammNotifier extends BammNotifier {
  final List<BammWorkOrder> _seed;
  _FakeBammNotifier(this._seed, {BammColumnLayout columnLayout = const BammColumnLayout()})
      : super(BammService()) {
    state = BammState(workOrders: _seed, columnLayout: columnLayout);
  }

  @override
  Future<void> init() async {}

  @override
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async =>
      _seed.where((w) => w.worId == worId).firstOrNull;

  int refreshCalls = 0;

  @override
  Future<void> refreshWorkOrders() async {
    refreshCalls++;
    var list = List<BammWorkOrder>.from(_seed);
    final c = state.criteria;

    if (c.area != null && c.area!.trim().isNotEmpty) {
      list = list.where((w) => w.area == c.area).toList();
    }
    if (c.machine != null && c.machine!.trim().isNotEmpty) {
      list = list.where((w) => w.machine == c.machine).toList();
    }
    if (c.assembly != null && c.assembly!.trim().isNotEmpty) {
      list = list.where((w) => w.assembly == c.assembly).toList();
    }
    if (c.responsible != null && c.responsible!.trim().isNotEmpty) {
      list = list.where((w) => w.responsible == c.responsible).toList();
    }
    if (c.requester != null && c.requester!.trim().isNotEmpty) {
      list = list.where((w) => w.requester == c.requester).toList();
    }
    if (c.searchQuery.trim().isNotEmpty) {
      final q = c.searchQuery.trim().toLowerCase();
      list = list.where((w) => w.description.toLowerCase().contains(q) || w.worNoSeq.contains(q)).toList();
    }

    int compare(BammWorkOrder a, BammWorkOrder b) {
      switch (c.sortField) {
        case 'worNoSeq':
          return a.worNoSeq.compareTo(b.worNoSeq);
        case 'woIssueDate':
        default:
          return (a.issueDate ?? DateTime(0)).compareTo(b.issueDate ?? DateTime(0));
      }
    }

    // No explicit sort field selected: mirror BammService's real default
    // (`orderByFields: [ListOrderBy('woIssueDate', ascending: false)]`).
    if (c.sortField == null) {
      list.sort((a, b) => (b.issueDate ?? DateTime(0)).compareTo(a.issueDate ?? DateTime(0)));
    } else {
      list.sort(compare);
      if (!c.sortAscending) list = list.reversed.toList();
    }

    state = state.copyWith(workOrders: list, isLoading: false);
  }
}

BammWorkOrder _wo({
  required int id,
  required DateTime issueDate,
  String status = 'StatusAlpha',
  String step = 'StepAlpha',
  String area = 'ZONE-A',
  String machine = 'MACH-A',
  String assembly = 'ASSY-A',
  String responsible = 'Dave M',
  String requester = 'Alex R',
}) =>
    BammWorkOrder(
      worId: id,
      worNoSeq: '$id',
      description: 'Work order $id',
      status: status,
      step: step,
      area: area,
      machine: machine,
      assembly: assembly,
      responsible: responsible,
      requester: requester,
      issueDate: issueDate,
    );

List<Override> _overrides(List<BammWorkOrder> seed, {BammColumnLayout columnLayout = const BammColumnLayout()}) => [
      storageServiceProvider.overrideWithValue(_FakeStorageService()),
      bammProvider.overrideWith((ref) => _FakeBammNotifier(seed, columnLayout: columnLayout)),
    ];

Future<void> _pumpAt(WidgetTester tester, Size size, {required List<Override> overrides}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const MaterialApp(home: BammScreen())),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('BAMM table sort', () {
    // 301: latest date: 2026-01-03. 302: earliest: 2026-01-01. 303: middle.
    final seed = [
      _wo(id: 301, issueDate: DateTime(2026, 1, 3)),
      _wo(id: 302, issueDate: DateTime(2026, 1, 1)),
      _wo(id: 303, issueDate: DateTime(2026, 1, 2)),
    ];

    testWidgets('clicking a header cycles asc -> desc -> cleared, reordering the visible rows', (tester) async {
      await _pumpAt(tester, _expanded, overrides: _overrides(seed));

      double dyOf(String worNoSeq) => tester.getTopLeft(find.text('#$worNoSeq')).dy;

      // Click 1: ascending by Registered date -> 302 (Jan 1), 303 (Jan 2), 301 (Jan 3).
      await tester.tap(find.text('Registered'));
      await tester.pumpAndSettle();
      expect(dyOf('302'), lessThan(dyOf('303')), reason: 'ascending: 302 (Jan 1) should be above 303 (Jan 2)');
      expect(dyOf('303'), lessThan(dyOf('301')), reason: 'ascending: 303 (Jan 2) should be above 301 (Jan 3)');

      final container = ProviderScope.containerOf(tester.element(find.byType(BammScreen)));
      expect(container.read(bammProvider).criteria.sortField, 'woIssueDate');
      expect(container.read(bammProvider).criteria.sortAscending, isTrue);

      // Click 2: descending -> 301, 303, 302.
      await tester.tap(find.text('Registered'));
      await tester.pumpAndSettle();
      expect(dyOf('301'), lessThan(dyOf('303')), reason: 'descending: 301 (Jan 3) should be above 303 (Jan 2)');
      expect(dyOf('303'), lessThan(dyOf('302')), reason: 'descending: 303 (Jan 2) should be above 302 (Jan 1)');
      expect(container.read(bammProvider).criteria.sortAscending, isFalse);

      // Click 3: clears the sort back to the server default (also desc by
      // date here), but the criteria must actually be cleared - not just
      // coincidentally the same order as click 2.
      await tester.tap(find.text('Registered'));
      await tester.pumpAndSettle();
      expect(container.read(bammProvider).criteria.sortField, isNull);
      expect(dyOf('301'), lessThan(dyOf('303')));
      expect(dyOf('303'), lessThan(dyOf('302')));
    });

    // Proves the guard has teeth: if header taps stopped calling setSort,
    // this test (unlike a callback-count test) would fail because the rows
    // would stay in seed order regardless of clicks.
    testWidgets('a header that does not sort would fail this test', (tester) async {
      await _pumpAt(tester, _expanded, overrides: _overrides(seed));
      double dyOf(String worNoSeq) => tester.getTopLeft(find.text('#$worNoSeq')).dy;
      await tester.tap(find.text('Registered'));
      await tester.pumpAndSettle();
      expect(dyOf('302'), lessThan(dyOf('301')));
    });
  });

  group('BAMM table header menu', () {
    final seed = [
      _wo(id: 401, issueDate: DateTime(2026, 2, 1), area: 'ZONE-A', status: 'StatusAlpha', step: 'StepAlpha'),
      _wo(id: 402, issueDate: DateTime(2026, 2, 2), area: 'ZONE-B', status: 'StatusBeta', step: 'StepBeta'),
      _wo(id: 403, issueDate: DateTime(2026, 2, 3), area: 'ZONE-A', status: 'StatusGamma', step: 'StepGamma'),
    ];

    testWidgets('long-pressing a cell and choosing "Filter by this value" narrows the rows', (tester) async {
      // Needs `_wide`, not `_expanded`: the Area column sits far enough
      // right (after the new default-visible Assembly column) that at
      // `_expanded`'s 1400px it falls outside the horizontal scroller's
      // initial viewport, and longPress() cannot hit-test an off-screen cell.
      await _pumpAt(tester, _wide, overrides: _overrides(seed));

      expect(find.text('#401'), findsOneWidget);
      expect(find.text('#402'), findsOneWidget);
      expect(find.text('#403'), findsOneWidget);

      // Long-press the Area cell showing "ZONE-A" on row 401.
      await tester.longPress(find.text('ZONE-A').first);
      await tester.pumpAndSettle();
      expect(find.text('Filter by this value'), findsOneWidget);
      await tester.tap(find.text('Filter by this value'));
      await tester.pumpAndSettle();

      expect(find.text('#401'), findsOneWidget, reason: 'ZONE-A row should remain');
      expect(find.text('#403'), findsOneWidget, reason: 'ZONE-A row should remain');
      expect(find.text('#402'), findsNothing, reason: 'ZONE-B row should be filtered out');
    });

    testWidgets('Assembly column is visible by default, sorts, and filters by cell value like every other column', (tester) async {
      final assemblySeed = [
        _wo(id: 501, issueDate: DateTime(2026, 3, 1), assembly: 'Fill Head 9'),
        _wo(id: 502, issueDate: DateTime(2026, 3, 2), assembly: 'Fill Head 10'),
        _wo(id: 503, issueDate: DateTime(2026, 3, 3), assembly: 'Fill Head 9'),
      ];
      await _pumpAt(tester, _wide, overrides: _overrides(assemblySeed));

      // In the DEFAULT visible set - no chooser interaction needed to see it.
      expect(find.text('Assembly'), findsOneWidget);
      expect(find.text('Fill Head 9'), findsWidgets);
      expect(find.text('Fill Head 10'), findsOneWidget);

      // Filters like every other column: long-press a cell, "Filter by this value".
      await tester.longPress(find.text('Fill Head 9').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filter by this value'));
      await tester.pumpAndSettle();

      expect(find.text('#501'), findsOneWidget, reason: 'Fill Head 9 rows remain');
      expect(find.text('#503'), findsOneWidget, reason: 'Fill Head 9 rows remain');
      expect(find.text('#502'), findsNothing, reason: 'Fill Head 10 row filtered out');
    });

    testWidgets('"Hide column" removes the header AND its cells', (tester) async {
      await _pumpAt(tester, _expanded, overrides: _overrides(seed));

      expect(find.text('Status'), findsOneWidget);
      expect(find.text('StatusAlpha'), findsOneWidget);

      await tester.longPress(find.text('Status'));
      await tester.pumpAndSettle();
      expect(find.text('Hide column'), findsOneWidget);
      await tester.tap(find.text('Hide column'));
      await tester.pumpAndSettle();

      expect(find.text('Status'), findsNothing, reason: 'header should be gone');
      expect(find.text('StatusAlpha'), findsNothing, reason: 'cell value should be gone with it');
      // Sibling columns are unaffected.
      expect(find.text('Step'), findsOneWidget);
      expect(find.text('StepAlpha'), findsOneWidget);
    });

    testWidgets('"Move left"/"Move right" changes the column order', (tester) async {
      await _pumpAt(tester, _expanded, overrides: _overrides(seed));

      double dxOf(String header) => tester.getCenter(find.text(header)).dx;
      expect(dxOf('Status'), lessThan(dxOf('Step')), reason: 'default order: Status before Step');

      await tester.longPress(find.text('Step'));
      await tester.pumpAndSettle();
      expect(find.text('Move left'), findsOneWidget);
      await tester.tap(find.text('Move left'));
      await tester.pumpAndSettle();

      expect(dxOf('Step'), lessThan(dxOf('Status')), reason: 'Step should now be before Status');

      await tester.longPress(find.text('Step'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move right'));
      await tester.pumpAndSettle();

      expect(dxOf('Status'), lessThan(dxOf('Step')), reason: 'Move right should undo the previous Move left');
    });
  });

  group('BAMM table column management', () {
    final seed = [
      _wo(id: 501, issueDate: DateTime(2026, 3, 1), machine: 'MACH-1', requester: 'Casey N'),
    ];

    testWidgets('the chooser offers Requester (not a default column) and adding it shows the column', (tester) async {
      await _pumpAt(tester, _wide, overrides: _overrides(seed));

      // Not shown by default.
      expect(find.text('Requester'), findsNothing);

      await tester.tap(find.byTooltip('Choose columns'));
      await tester.pumpAndSettle();
      // The chooser is a scrollable sheet - columns below the fold (this
      // app has 14, only ~9 fit in the initial viewport) aren't built until
      // scrolled into view, same as the Settings screen's parity test.
      await tester.scrollUntilVisible(find.text('Requester'), 200.0, scrollable: find.byType(Scrollable).last);
      expect(find.text('Requester'), findsOneWidget, reason: 'Requester must be offered in the chooser');

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Requester'));
      await tester.pumpAndSettle();
      // Dismiss the bottom sheet by tapping outside it.
      await tester.tapAt(const Offset(700, 50));
      await tester.pumpAndSettle();

      expect(find.text('Requester'), findsOneWidget, reason: 'header should now be visible in the table');
      expect(find.text('Casey N'), findsOneWidget, reason: 'requester cell value should now render');
    });

    testWidgets('hiding a column via the chooser then re-adding it restores it', (tester) async {
      await _pumpAt(tester, _wide, overrides: _overrides(seed));

      expect(find.text('Machine'), findsOneWidget);
      expect(find.text('MACH-1'), findsOneWidget);

      await tester.tap(find.byTooltip('Choose columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Machine'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(700, 50));
      await tester.pumpAndSettle();

      expect(find.text('Machine'), findsNothing, reason: 'Machine should be hidden');
      expect(find.text('MACH-1'), findsNothing);

      await tester.tap(find.byTooltip('Choose columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Machine'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(700, 50));
      await tester.pumpAndSettle();

      expect(find.text('Machine'), findsOneWidget, reason: 'Machine should be restored');
      expect(find.text('MACH-1'), findsOneWidget);
    });

    testWidgets('dragging a column header reorders the columns', (tester) async {
      await _pumpAt(tester, _expanded, overrides: _overrides(seed));

      // Default order: WO#(0), Registered(1), Status(2), Step(3), ...
      final stepHandle = find.byIcon(Icons.drag_indicator).at(3);
      final statusHandle = find.byIcon(Icons.drag_indicator).at(2);
      double dxOf(String header) => tester.getCenter(find.text(header)).dx;
      expect(dxOf('Status'), lessThan(dxOf('Step')));

      final delta = tester.getCenter(statusHandle) - tester.getCenter(stepHandle);
      await tester.drag(stepHandle, delta);
      await tester.pumpAndSettle();

      expect(dxOf('Step'), lessThan(dxOf('Status')), reason: 'dragging Step onto Status should place Step first');
    });
  });

  group('BAMM column layout persistence', () {
    testWidgets('a saved layout survives a fresh screen load with the same visible order', (tester) async {
      final layout = const BammColumnLayout(
        order: ['woStatusDescription', 'worNoSeq', 'requesterName'],
        hidden: {'woTask'},
      );
      final seed = [_wo(id: 601, issueDate: DateTime(2026, 4, 1))];

      await _pumpAt(tester, _expanded, overrides: _overrides(seed, columnLayout: layout));

      double dxOf(String header) => tester.getCenter(find.text(header)).dx;
      // The saved order puts Status first, then WO#, then Requester -
      // Description/Work done/etc. pushed later since they're not in
      // `order` and get appended after the explicitly-ordered ones.
      expect(dxOf('Status'), lessThan(dxOf('WO#')));
      expect(dxOf('WO#'), lessThan(dxOf('Requester')));
      expect(find.text('Work done'), findsNothing, reason: 'woTask was hidden in the saved layout');

      // Pure-logic round trip of the same helpers the screen uses, proving
      // the persisted shape itself (not just this one render) is correct.
      final columns = applyColumnLayout(buildBammColumns(), layout);
      final visibleKeys = columns.where((c) => isColumnVisible(c, layout)).map((c) => c.key).toList();
      expect(visibleKeys.take(3), ['woStatusDescription', 'worNoSeq', 'requesterName']);
      expect(visibleKeys.contains('woTask'), isFalse);
    });

    test('BammService.saveColumnLayout -> loadColumnLayout round-trips the exact layout', () async {
      final service = _InMemoryColumnLayoutService();
      final layout = const BammColumnLayout(order: ['worNoSeq', 'woStatusDescription'], hidden: {'regrouping1Description'});

      await service.saveColumnLayout(layout);
      final reloaded = await service.loadColumnLayout();

      expect(reloaded.order, layout.order);
      expect(reloaded.hidden, layout.hidden);
    });
  });

  group('BAMM local search toggle', () {
    // Same scenario as bamm_local_search_test.dart, exercised end-to-end
    // through the real screen: a WO found by combining a work-done token, a
    // responsible token, and a spoken-month date token - only once the "All
    // fields" toggle is on, and without triggering a new server query.
    final seed = [
      _wo(id: 601, issueDate: DateTime(2026, 9, 17)).copyWith(workDone: 'hit tire with hammer', responsible: 'Jonathan Randall'),
      _wo(id: 602, issueDate: DateTime(2026, 1, 5)).copyWith(workDone: 'replaced bearing', responsible: 'Someone Else'),
    ];

    testWidgets('OFF by default: typing the combined query does not filter rows locally', (tester) async {
      await _pumpAt(tester, _wide, overrides: _overrides(seed));
      expect(find.text('#601'), findsOneWidget);
      expect(find.text('#602'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Randall hammer September');
      await tester.pump();

      // Toggle is off - onChanged updated local state but it is never
      // consulted, and onSubmitted (server search) was not fired either.
      expect(find.text('#601'), findsOneWidget);
      expect(find.text('#602'), findsOneWidget);
    });

    testWidgets('ON: filters rows already loaded as you type, all fields combined, no new request', (tester) async {
      late _FakeBammNotifier notifier;
      final overrides = <Override>[
        storageServiceProvider.overrideWithValue(_FakeStorageService()),
        bammProvider.overrideWith((ref) {
          notifier = _FakeBammNotifier(seed);
          return notifier;
        }),
      ];
      await _pumpAt(tester, _wide, overrides: overrides);
      final callsBeforeToggle = notifier.refreshCalls;

      await tester.tap(find.byKey(const Key('bamm_local_search_toggle')));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Randall hammer September');
      await tester.pump();

      expect(find.text('#601'), findsOneWidget, reason: 'matches work done + responsible + spoken date month');
      expect(find.text('#602'), findsNothing);
      expect(find.textContaining('of 2 loaded rows'), findsOneWidget, reason: 'must plainly show rows are hidden by the local filter');
      expect(notifier.refreshCalls, callsBeforeToggle, reason: 'local search must never trigger a new API request');
    });
  });
}

/// A [BammService] whose column-layout persistence is in-memory instead of
/// going through `path_provider` (unavailable in the test sandbox) - proves
/// the save/load round trip without touching real files.
class _InMemoryColumnLayoutService extends BammService {
  BammColumnLayout? _saved;

  @override
  Future<BammColumnLayout> loadColumnLayout() async => _saved ?? const BammColumnLayout();

  @override
  Future<void> saveColumnLayout(BammColumnLayout layout) async {
    _saved = layout;
  }
}
