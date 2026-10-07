import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/ui_prefs.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/ui/screens/dashboard_screen.dart';

import '../helpers/memory_storage.dart';

Future<MemoryStorage> _pump(WidgetTester tester, UiPrefs prefs) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final storage = MemoryStorage(prefs: prefs);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

void main() {
  testWidgets('hidden sections are not shown; the rest are', (tester) async {
    await _pump(tester, const UiPrefs(dashboardHidden: ['orders', 'summary']));
    expect(find.text('Orders Due Soon (Next 14 Days)'), findsNothing);
    expect(find.text('Top Priority Projects'), findsOneWidget);
    expect(find.text('Needs Attention (Untouched)'), findsOneWidget);
  });

  testWidgets('saved order is used (orders first)', (tester) async {
    await _pump(tester, const UiPrefs(dashboardOrder: ['orders', 'priority']));
    final orders = tester.getTopLeft(
      find.text('Orders Due Soon (Next 14 Days)'),
    );
    final priority = tester.getTopLeft(find.text('Top Priority Projects'));
    // Same row (two columns): orders is left of priority.
    expect(orders.dx < priority.dx || orders.dy < priority.dy, isTrue);
  });

  testWidgets(
    'the customizer toggles a section off, saves it, and Reset restores',
    (tester) async {
      final storage = await _pump(tester, const UiPrefs());
      expect(find.text('Needs Attention (Untouched)'), findsOneWidget);

      await tester.tap(find.byTooltip('Customize dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Customize dashboard'), findsWidgets);

      final tile = find.widgetWithText(ListTile, 'Needs attention');
      await tester.tap(
        find.descendant(of: tile, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();
      expect(storage.prefs.dashboardHidden, ['attention']);
      expect(find.text('Needs Attention (Untouched)'), findsNothing);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(storage.prefs.dashboardHidden, isEmpty);
      expect(find.text('Needs Attention (Untouched)'), findsOneWidget);
    },
  );
}
