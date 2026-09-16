// Regression test for the sidebar-disappearing bug: a nav destination that
// routed to a GoRoute OUTSIDE the StatefulShellRoute rendered without the
// shell chrome (no rail on desktop, no bottom bar on mobile). This drives
// the REAL `appRouter` (not a stand-in) through every desktop nav rail item
// and every mobile bottom-bar item, and after each tap asserts both that the
// shell chrome is still present AND that GoRouter actually moved to the
// expected path - a destination that silently no-ops (wrong index into
// `goBranch`) or escapes the shell would fail one of these two checks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

import 'package:jokarz_engineering/router/app_router.dart';
import 'package:jokarz_engineering/ui/adaptive/nav_shell.dart';

/// Same shape as `_FakeStorageService` elsewhere in `test/ui/` (duplicated -
/// these are file-private and can't be imported across test files).
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

class _FakeBammNotifier extends BammNotifier {
  _FakeBammNotifier() : super(BammService()) {
    state = const BammState();
  }

  @override
  Future<void> init() async {}

  @override
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async => null;
}

List<Override> _overrides() => [
      storageServiceProvider.overrideWithValue(_FakeStorageService()),
      bammProvider.overrideWith((ref) => _FakeBammNotifier()),
    ];

/// Every branch this app's router declares, in branch-index order (0-6),
/// with the label used to find it in each nav surface and the path GoRouter
/// should land on. Desktop and mobile use different label text for the same
/// branch in a couple of cases (`nav_shell.dart`: "Open Orders" vs "Orders",
/// "Workbench Tools" vs "Tools", "Notes" vs "Notes") so both are recorded.
class _Branch {
  final int index;
  final String desktopLabel;
  final String mobileLabel;
  final String path;
  const _Branch(this.index, this.desktopLabel, this.mobileLabel, this.path);
}

const _branches = [
  _Branch(0, 'Dashboard', 'Dashboard', '/'),
  _Branch(1, 'Projects', 'Projects', '/projects'),
  _Branch(2, 'Open Orders', 'Orders', '/orders'),
  _Branch(3, 'Workbench Tools', 'Tools', '/workbench'),
  _Branch(4, 'Notes', 'Notes', '/voice-notes'),
  _Branch(5, 'Settings', 'Settings', '/settings'),
  _Branch(6, 'BAMM Orders', 'BAMM', '/bamm'),
];

String _currentPath(WidgetTester tester) {
  final context = tester.element(find.byType(AdaptiveNavShell));
  return GoRouterState.of(context).uri.toString();
}

void main() {
  testWidgets(
    'every desktop nav-rail destination reaches its branch with the rail intact',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(overrides: _overrides(), child: MaterialApp.router(routerConfig: appRouter)),
      );
      await tester.pumpAndSettle();

      for (final branch in _branches) {
        await tester.tap(find.text(branch.desktopLabel).first);
        await tester.pumpAndSettle();

        expect(
          find.byType(AdaptiveNavShell),
          findsOneWidget,
          reason: 'shell chrome disappeared after tapping "${branch.desktopLabel}" - this is exactly the '
              'sidebar-vanishing bug (a route pushed outside the StatefulShellRoute)',
        );
        // The rail itself - look for another destination's label to prove
        // the rail (not just some other widget) is still on screen.
        expect(find.text('Dashboard'), findsWidgets, reason: 'nav rail item list should still be rendered');
        expect(
          _currentPath(tester),
          branch.path,
          reason: '"${branch.desktopLabel}" should route to branch ${branch.index} (${branch.path})',
        );
      }
    },
  );

  testWidgets(
    'every mobile bottom-bar destination reaches its branch with the bar intact',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(overrides: _overrides(), child: MaterialApp.router(routerConfig: appRouter)),
      );
      await tester.pumpAndSettle();

      for (final branch in _branches) {
        await tester.tap(find.widgetWithText(NavigationDestination, branch.mobileLabel).first.hitTestable());
        await tester.pumpAndSettle();

        expect(
          find.byType(NavigationBar),
          findsOneWidget,
          reason: 'bottom nav bar disappeared after tapping "${branch.mobileLabel}" - the sidebar-vanishing bug\'s '
              'mobile equivalent (a route pushed outside the StatefulShellRoute)',
        );
        expect(
          _currentPath(tester),
          branch.path,
          reason: '"${branch.mobileLabel}" (position ${branch.index} in the bottom bar) should route to branch '
              '${branch.index} (${branch.path}) - the bottom bar has no explicit index wiring, so its list order '
              'IS the branch index',
        );
      }
    },
  );
}
