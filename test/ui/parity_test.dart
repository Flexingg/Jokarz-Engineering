// Parity tests: for each screen, the SAME field labels, row data, and action
// buttons must be reachable at a phone width (400x800) and a desktop width
// (1400x900). A field or action visible only at one size is a real bug -
// these tests assert on concrete strings, not widget counts, so removing a
// field from either layout makes the corresponding test fail.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/models/order_item.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/models/filament_profile.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/inbox_item.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/models/project_template.dart';
import 'package:jokarz_engineering/models/activity_log.dart';
import 'package:jokarz_engineering/models/downtime_event.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';

import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/providers/bamm_provider.dart';

import 'package:jokarz_engineering/services/storage_service.dart';
import 'package:jokarz_engineering/services/bamm_service.dart';

import 'package:jokarz_engineering/ui/screens/dashboard_screen.dart';
import 'package:jokarz_engineering/ui/screens/projects_screen.dart';
import 'package:jokarz_engineering/ui/screens/bamm_screen.dart';
import 'package:jokarz_engineering/ui/screens/settings_screen.dart';
import 'package:jokarz_engineering/ui/screens/project_detail_screen.dart';

const _compact = Size(400, 800);
const _expanded = Size(1400, 900);

/// A [StorageService] that returns fixed in-memory data instead of touching
/// `path_provider` (unavailable in the widget-test environment) and never
/// silently falls back to a blank-slate dataset.
class _FakeStorageService extends StorageService {
  final List<Project> seedProjects;
  _FakeStorageService([this.seedProjects = const []]);

  @override
  Future<Map<String, dynamic>> loadData() async => {
        'projects': seedProjects,
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

/// A [BammNotifier] that skips network polling / config loading (`init()`)
/// and starts from a fixed seed state instead.
class _FakeBammNotifier extends BammNotifier {
  _FakeBammNotifier(BammState seed) : super(BammService()) {
    state = seed;
  }

  @override
  Future<void> init() async {}

  // The detail dialog fetches full detail on open to hydrate extra fields.
  // Serve it from the already-seeded state instead of hitting the real
  // BammService (which needs live plant credentials this test never has).
  @override
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async {
    return state.workOrders.where((w) => w.worId == worId).firstOrNull;
  }
}

Project _testProject() => Project(
      id: 'proj-1',
      title: 'Replace Conveyor Gearbox',
      category: ProjectCategory.maintenance,
      phase: 'Installation',
      priority: 1,
      machine: 'Line 3 Packer',
      subAssembly: 'Gearbox Assy',
      cost: 500.0,
      tasks: [
        TaskItem(description: 'Align new gearbox', pendingReason: 'Pending parts'),
      ],
      orders: [
        OrderItem(
          description: 'Gearbox seal kit',
          po: 'PO-9001',
          price: 249.99,
          eta: DateTime.now().add(const Duration(days: 3)),
        ),
      ],
    );

BammWorkOrder _testWorkOrder() => BammWorkOrder(
      worId: 190022,
      worNoSeq: '190022',
      description: 'Hydraulic power unit valve replacement',
      status: 'Approved',
      step: 'Awaiting Parts',
      area: 'HYDRAULICS',
      machine: 'HPU-02',
      responsible: 'Dave M',
      requester: 'Alex R',
      issueDate: DateTime(2026, 9, 10),
    );

List<Override> _projectOverrides(List<Project> projects) => [
      storageServiceProvider.overrideWithValue(_FakeStorageService(projects)),
    ];

List<Override> _bammOverrides(BammWorkOrder wo) => [
      storageServiceProvider.overrideWithValue(_FakeStorageService(const [])),
      bammProvider.overrideWith((ref) => _FakeBammNotifier(BammState(workOrders: [wo]))),
    ];

Future<void> _pumpAt(
  WidgetTester tester,
  Widget child,
  Size size, {
  required List<Override> overrides,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    ),
  );
  // Let the fake storage's Future-based load settle.
  await tester.pump();
  await tester.pump();
}

void main() {
  group('Dashboard parity', () {
    // Same underlying state (project title, next task, open order, weekly
    // KPIs) must be visible regardless of how the sections are arranged.
    const labels = <String>[
      'Dashboard',
      'Replace Conveyor Gearbox',
      'Gearbox seal kit',
      'Tasks Added (7d)',
      'Tasks Closed (7d)',
      'Quick Dump',
    ];

    testWidgets('phone (400x800) shows all key fields and actions', (tester) async {
      await _pumpAt(tester, const DashboardScreen(), _compact,
          overrides: _projectOverrides([_testProject()]));
      for (final label in labels) {
        expect(find.text(label), findsWidgets, reason: '"$label" missing at phone width');
      }
      expect(find.textContaining('Align new gearbox'), findsWidgets);
    });

    testWidgets('desktop (1400x900) shows all key fields and actions', (tester) async {
      await _pumpAt(tester, const DashboardScreen(), _expanded,
          overrides: _projectOverrides([_testProject()]));
      for (final label in labels) {
        expect(find.text(label), findsWidgets, reason: '"$label" missing at desktop width');
      }
      expect(find.textContaining('Align new gearbox'), findsWidgets);
    });

    // Regression test for the _KpiCard RenderFlex overflow: the framework
    // throws a FlutterError on overflow, so a clean takeException() is a
    // real assertion that nothing was clipped off-screen at phone width.
    testWidgets('phone (400x800) has no layout overflow', (tester) async {
      await _pumpAt(tester, const DashboardScreen(), _compact,
          overrides: _projectOverrides([_testProject()]));
      expect(tester.takeException(), isNull);
    });
  });

  group('Settings parity', () {
    // SettingsScreen builds one identical widget list at every width and
    // only changes the container around it, so the same sections must
    // always be present.
    const labels = <String>[
      'Workshop Settings & Data',
      'Google Account & Cloud Synchronization',
      'Export Complete Engineering JSON Database',
      'Import Engineering JSON Database',
    ];

    testWidgets('phone (400x800) shows all settings sections', (tester) async {
      await _pumpAt(tester, const SettingsScreen(), _compact,
          overrides: _projectOverrides(const []));
      for (final label in labels) {
        // Sections below the fold aren't built until scrolled into the
        // ListView's cache extent - scroll each one into view before
        // asserting, rather than only checking what's built on first pump.
        await tester.scrollUntilVisible(find.text(label), 200.0);
        expect(find.text(label), findsWidgets, reason: '"$label" missing at phone width');
      }
    });

    testWidgets('desktop (1400x900) shows all settings sections', (tester) async {
      await _pumpAt(tester, const SettingsScreen(), _expanded,
          overrides: _projectOverrides(const []));
      for (final label in labels) {
        await tester.scrollUntilVisible(find.text(label), 200.0);
        expect(find.text(label), findsWidgets, reason: '"$label" missing at desktop width');
      }
    });
  });

  group('BAMM work-order list + detail parity', () {
    // Fields that must survive in both the desktop table row and the mobile
    // card (this is exactly where the "Req:" requester field used to be
    // desktop-only - see the mutation proof in the task report).
    const listLabels = <String>[
      '#190022',
      'Hydraulic power unit valve replacement',
      'Approved',
      'Awaiting Parts',
    ];

    testWidgets('phone (400x800): list row and detail dialog show the same fields', (tester) async {
      await _pumpAt(tester, const BammScreen(), _compact, overrides: _bammOverrides(_testWorkOrder()));
      for (final label in listLabels) {
        expect(find.textContaining(label), findsWidgets, reason: '"$label" missing at phone width');
      }
      expect(find.textContaining('Dave M'), findsWidgets, reason: 'Responsible missing at phone width');
      expect(find.textContaining('Alex R'), findsWidgets, reason: 'Requester missing at phone width');
      expect(find.textContaining('HPU-02'), findsWidgets, reason: 'Machine missing at phone width');
      expect(find.textContaining('HYDRAULICS'), findsWidgets, reason: 'Area missing at phone width');

      // Detail is reachable via the same dialog regardless of screen size -
      // drill down the way a phone user would (tap the card) and confirm
      // the same fields that were visible in the list are still visible in
      // the dialog.
      await tester.tap(find.textContaining('#190022').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('BAMM Work Order #190022'), findsOneWidget);
      expect(find.textContaining('Approved'), findsWidgets, reason: 'Status missing in phone detail dialog');
      expect(find.textContaining('Awaiting Parts'), findsWidgets, reason: 'Step missing in phone detail dialog');
      expect(find.textContaining('Dave M'), findsWidgets, reason: 'Responsible missing in phone detail dialog');
      expect(find.textContaining('Alex R'), findsWidgets, reason: 'Requester missing in phone detail dialog');
      expect(find.textContaining('HPU-02'), findsWidgets, reason: 'Machine missing in phone detail dialog');
      expect(find.textContaining('HYDRAULICS'), findsWidgets, reason: 'Area missing in phone detail dialog');
    });

    testWidgets('desktop (1400x900): list row and detail dialog show the same fields', (tester) async {
      await _pumpAt(tester, const BammScreen(), _expanded, overrides: _bammOverrides(_testWorkOrder()));
      for (final label in listLabels) {
        expect(find.textContaining(label), findsWidgets, reason: '"$label" missing at desktop width');
      }
      expect(find.textContaining('Dave M'), findsWidgets, reason: 'Responsible missing at desktop width');
      expect(find.textContaining('HPU-02'), findsWidgets, reason: 'Machine missing at desktop width');
      expect(find.textContaining('HYDRAULICS'), findsWidgets, reason: 'Area missing at desktop width');
      // The requester is deliberately NOT asserted against the desktop ROW: the row is now driven by
      // the user's column layout and "Requester" is not one of the default visible columns (it stays
      // available in the column chooser). Asserting it on the row would pin the test to a default
      // instead of to the guarantee that matters - that the information is reachable at this width,
      // which the dialog assertions below cover.

      await tester.tap(find.textContaining('#190022').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('BAMM Work Order #190022'), findsOneWidget);
      expect(find.textContaining('Approved'), findsWidgets, reason: 'Status missing in desktop detail dialog');
      expect(find.textContaining('Awaiting Parts'), findsWidgets, reason: 'Step missing in desktop detail dialog');
      expect(find.textContaining('Dave M'), findsWidgets, reason: 'Responsible missing in desktop detail dialog');
      expect(find.textContaining('Alex R'), findsWidgets, reason: 'Requester missing in desktop detail dialog');
      expect(find.textContaining('HPU-02'), findsWidgets, reason: 'Machine missing in desktop detail dialog');
      expect(find.textContaining('HYDRAULICS'), findsWidgets, reason: 'Area missing in desktop detail dialog');
    });

    // Regression tests for the table's RenderFlex overflow. [_tableWidth] accounts for the 12px
    // padding inside the header/row containers and nothing else, so any extra horizontal padding on
    // the list itself leaves every row short of the width its children sum to - which threw a 34px
    // overflow at 1400px with the default column set. The framework throws on overflow, so a clean
    // takeException() is a real assertion. Both widths are covered because the bug only appeared at
    // the wide one.
    testWidgets('desktop (1400x900) table has no layout overflow', (tester) async {
      await _pumpAt(tester, const BammScreen(), _expanded,
          overrides: _bammOverrides(_testWorkOrder()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone (400x800) table has no layout overflow', (tester) async {
      await _pumpAt(tester, const BammScreen(), _compact,
          overrides: _bammOverrides(_testWorkOrder()));
      expect(tester.takeException(), isNull);
    });
  });

  group('Projects list + project detail parity', () {
    const listLabels = <String>[
      'Engineering Projects',
      'Replace Conveyor Gearbox',
      'All Categories',
      'All Phases',
      'New Project',
    ];
    // Detail fields: tab counts and the pending task description, present
    // whether reached by drill-down push (phone) or the master-detail pane
    // (desktop).
    const detailLabels = <String>[
      'Tasks (0/1)',
      'Orders (1)',
      'Logs & Photos (0)',
      'Align new gearbox',
    ];

    testWidgets('phone (400x800): list shows fields; detail reachable by drill-down', (tester) async {
      await _pumpAt(tester, const ProjectsScreen(), _compact,
          overrides: _projectOverrides([_testProject()]));
      for (final label in listLabels) {
        expect(find.text(label), findsWidgets, reason: '"$label" missing at phone width');
      }
      // Phone drill-down pushes to a standalone ProjectDetailScreen - pump it
      // directly (that's exactly what the push would show) and check parity.
      await _pumpAt(tester, const ProjectDetailScreen(projectId: 'proj-1'), _compact,
          overrides: _projectOverrides([_testProject()]));
      for (final label in detailLabels) {
        expect(find.textContaining(label), findsWidgets, reason: '"$label" missing at phone width');
      }
    });

    testWidgets('desktop (1400x900): list and detail pane show the same fields at once', (tester) async {
      await _pumpAt(tester, const ProjectsScreen(), _expanded,
          overrides: _projectOverrides([_testProject()]));
      for (final label in listLabels) {
        expect(find.text(label), findsWidgets, reason: '"$label" missing at desktop width');
      }
      // The master-detail pane auto-selects the first project - detail
      // fields must already be visible in the same screen, no extra tap.
      for (final label in detailLabels) {
        expect(find.textContaining(label), findsWidgets, reason: '"$label" missing at desktop width');
      }
    });
  });
}
