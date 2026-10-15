// Regression: dialogs launched from the command palette used the palette's
// `ref`, which is disposed as soon as the palette closes. The dialog's first
// build worked; the first rebuild (picking a vendor, picking an ETA date)
// threw "Cannot use ref after the widget was disposed" and left a grey barrier.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/router/app_router.dart';
import 'package:jokarz_engineering/ui/widgets/app_shortcuts.dart';

import '../helpers/memory_storage.dart';

Future<void> _openPaletteAndRun(WidgetTester tester, String query) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, query);
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  appRouter.go('/orders');
  await tester.pumpWidget(ProviderScope(
    overrides: [
      storageServiceProvider.overrideWithValue(
        MemoryStorage(vendors: [Vendor(id: 'v1', name: 'Rexel', accountNumber: '100234')]),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: appRouter,
      builder: (context, child) => AppShortcuts(child: child ?? const SizedBox.shrink()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('palette -> New order -> pick a vendor keeps the dialog usable', (tester) async {
    await _pump(tester);
    await _openPaletteAndRun(tester, 'new order');
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Vendor / Supplier').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rexel').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'the order dialog must survive the vendor pick');
    expect(find.text('Rexel'), findsWidgets, reason: 'the chosen vendor is shown');
    expect(find.text('100234'), findsOneWidget, reason: 'SAP code appears beside the vendor field');
  });

  testWidgets('palette -> New order -> Set ETA keeps the dialog usable', (tester) async {
    await _pump(tester);
    await _openPaletteAndRun(tester, 'new order');

    await tester.tap(find.text('Set ETA'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('No ETA'), findsNothing, reason: 'the picked date replaced "No ETA"');
  });

  testWidgets('palette -> New note opens and closes cleanly', (tester) async {
    await _pump(tester);
    await _openPaletteAndRun(tester, 'new note');
    expect(find.text('New Engineering Field Note'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('palette -> Toggle sidebar still works after the palette closed', (tester) async {
    await _pump(tester);
    await _openPaletteAndRun(tester, 'toggle sidebar');
    expect(tester.takeException(), isNull);
  });
}
