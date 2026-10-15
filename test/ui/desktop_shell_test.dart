import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/ui_prefs.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/router/app_router.dart';
import 'package:jokarz_engineering/ui/adaptive/nav_shell.dart';
import 'package:jokarz_engineering/ui/motion/motion.dart';
import 'package:jokarz_engineering/ui/widgets/app_shortcuts.dart';

import '../helpers/memory_storage.dart';

Future<MemoryStorage> _pumpApp(
  WidgetTester tester, {
  UiPrefs prefs = const UiPrefs(),
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  appRouter.go('/');
  final storage = MemoryStorage(prefs: prefs);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: MaterialApp.router(
        routerConfig: appRouter,
        // Same wrapping as JokarzEngineeringApp in main.dart.
        builder: (context, child) => MotionScope(
          motion: const Motion(MotionLevel.off),
          child: AppShortcuts(child: child ?? const SizedBox.shrink()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

String _path(WidgetTester tester) =>
    appRouter.routeInformationProvider.value.uri.toString();

void main() {
  testWidgets(
    'desktop shell shows the menu bar and the rail with every destination',
    (tester) async {
      await _pumpApp(tester);
      for (final m in ['File', 'View', 'Go', 'Help']) {
        expect(find.text(m), findsOneWidget);
      }
      for (final l in [
        'Dashboard',
        'Projects',
        'Open Orders',
        'Workbench Tools',
        'BAMM Orders',
        'Notes',
        'Settings',
      ]) {
        expect(find.text(l), findsWidgets, reason: l);
      }
      expect(find.byType(AdaptiveNavShell), findsOneWidget);
    },
  );

  testWidgets(
    'collapsing the rail hides labels, keeps tooltips, and is saved',
    (tester) async {
      final storage = await _pumpApp(tester);
      expect(find.text('Open Orders'), findsOneWidget);

      await tester.tap(find.byTooltip('Collapse sidebar'));
      await tester.pumpAndSettle();
      expect(find.text('Open Orders'), findsNothing);
      expect(find.byTooltip('Open Orders'), findsOneWidget);
      expect(storage.prefs.railCollapsed, isTrue);

      await tester.tap(find.byTooltip('Expand sidebar'));
      await tester.pumpAndSettle();
      expect(find.text('Open Orders'), findsOneWidget);
      expect(storage.prefs.railCollapsed, isFalse);
    },
  );

  testWidgets('a saved collapsed rail is restored on launch', (tester) async {
    await _pumpApp(tester, prefs: const UiPrefs(railCollapsed: true));
    expect(find.text('Open Orders'), findsNothing);
    expect(find.byTooltip('Expand sidebar'), findsOneWidget);
  });

  testWidgets('Ctrl+K opens the command palette and Enter runs the top match', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Type a command, project, PO or note'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'open orders');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(_path(tester), '/orders');
    expect(find.text('Type a command, project, PO or note'), findsNothing);
  });

  testWidgets('Ctrl+F also opens the palette (the old Search screen is gone)', (tester) async {
    await _pumpApp(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Type a command, project, PO or note'), findsOneWidget);
  });

  testWidgets('typing text offers to create a project, order or note from it', (tester) async {
    await _pumpApp(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'conveyor belt tracking');
    await tester.pumpAndSettle();
    expect(find.text('Create project "Conveyor Belt Tracking"'), findsOneWidget);
    expect(find.text('Create order "conveyor belt tracking"'), findsOneWidget);
    expect(find.text('Create note "conveyor belt tracking"'), findsOneWidget);
  });

  testWidgets('Escape closes the palette without navigating', (tester) async {
    await _pumpApp(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Type a command, project, PO or note'), findsNothing);
    expect(_path(tester), '/');
  });

  testWidgets('menu bar Go menu navigates', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Orders').last);
    await tester.pumpAndSettle();
    expect(_path(tester), '/orders');
  });

  testWidgets('Ctrl+B toggles the sidebar', (tester) async {
    final storage = await _pumpApp(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(storage.prefs.railCollapsed, isTrue);
  });
}
