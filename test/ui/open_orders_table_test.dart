import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/ui/screens/open_orders_screen.dart';

import '../helpers/memory_storage.dart';

StandaloneOrder _order(
  String id,
  String desc,
  double price,
  int etaDays, {
  String po = '',
}) => StandaloneOrder(
  id: id,
  description: desc,
  price: price,
  po: po,
  vendorName: 'Vendor $id',
  eta: DateTime.now().add(Duration(days: etaDays)),
);

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final storage = MemoryStorage(
    orders: [
      _order('a', 'Gearbox seal kit', 412.6, 5, po: '4500187231'),
      _order('b', 'Servo drive', 3180, 1, po: '4500187302'),
      _order('c', 'Bearing set', 96.5, 9, po: '4500187440'),
    ],
  );
  final container = ProviderContainer(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: OpenOrdersScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

double _y(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('table sorts by a header, reverses, then clears', (tester) async {
    await _pump(tester);
    // Default (Open tab) is ETA ascending: Servo (1d), Gearbox (5d), Bearing (9d).
    expect(_y(tester, 'Servo drive') < _y(tester, 'Gearbox seal kit'), isTrue);

    await tester.tap(find.text('DESCRIPTION'));
    await tester.pumpAndSettle();
    expect(_y(tester, 'Bearing set') < _y(tester, 'Gearbox seal kit'), isTrue);
    expect(_y(tester, 'Gearbox seal kit') < _y(tester, 'Servo drive'), isTrue);

    await tester.tap(find.text('DESCRIPTION'));
    await tester.pumpAndSettle();
    expect(
      _y(tester, 'Servo drive') < _y(tester, 'Bearing set'),
      isTrue,
      reason: 'descending',
    );

    await tester.tap(find.text('DESCRIPTION'));
    await tester.pumpAndSettle();
    expect(
      _y(tester, 'Servo drive') < _y(tester, 'Gearbox seal kit'),
      isTrue,
      reason: 'cleared -> ETA order',
    );
  });

  testWidgets(
    'selecting rows raises the bulk bar and marks them delivered with undo',
    (tester) async {
      final container = await _pump(tester);
      expect(find.text('2 selected'), findsNothing);

      final boxes = find.byType(Checkbox);
      await tester.tap(boxes.at(1)); // first data row
      await tester.tap(boxes.at(2));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.text('Mark delivered'));
      await tester.pumpAndSettle();
      final delivered = container
          .read(projectProvider)
          .standaloneOrders
          .where((o) => o.delivered);
      expect(delivered.length, 2);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(projectProvider)
            .standaloneOrders
            .where((o) => o.delivered),
        isEmpty,
      );
    },
  );

  testWidgets('right-click opens the row menu', (tester) async {
    await _pump(tester);
    final row = find.text('Servo drive');
    final gesture = await tester.startGesture(tester.getCenter(row), buttons: kSecondaryButton);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Open details'), findsOneWidget);
    expect(find.text('Copy PO #'), findsOneWidget);
  });

  group('sidebar editor (autosave)', () {
    Future<void> openRow(WidgetTester tester, String desc) async {
      await tester.tap(find.text(desc));
      await tester.pumpAndSettle();
    }

    Finder descField() => find.widgetWithText(TextField, 'Part / Material Description *');
    String descOf(ProviderContainer c, String id) =>
        c.read(projectProvider).standaloneOrders.firstWhere((o) => o.id == id).description;

    testWidgets("clicking a row opens an editable panel with the order's values", (tester) async {
      await _pump(tester);
      await openRow(tester, 'Servo drive');
      expect(find.text('PO 4500187302'), findsOneWidget);
      expect(tester.widget<TextField>(descField()).controller!.text, 'Servo drive');
      expect(find.text('Vendor / Supplier'), findsOneWidget);
    });

    testWidgets('selecting another order saves the edits to the first', (tester) async {
      final c = await _pump(tester);
      await openRow(tester, 'Servo drive');
      await tester.enterText(descField(), 'Servo drive 2.2 kW');
      await tester.pump();
      expect(descOf(c, 'b'), 'Servo drive', reason: 'not saved yet');

      await tester.tap(find.text('Bearing set'));
      await tester.pumpAndSettle();

      expect(descOf(c, 'b'), 'Servo drive 2.2 kW');
      expect(tester.widget<TextField>(descField()).controller!.text, 'Bearing set');
    });

    testWidgets('clicking off the form (focus leaves) saves', (tester) async {
      final c = await _pump(tester);
      await openRow(tester, 'Servo drive');
      await tester.enterText(descField(), 'Servo drive (rush)');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(descOf(c, 'b'), 'Servo drive (rush)');
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('a pause in typing saves', (tester) async {
      final c = await _pump(tester);
      await openRow(tester, 'Servo drive');
      await tester.enterText(descField(), 'Servo drive v2');
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      expect(descOf(c, 'b'), 'Servo drive v2');
    });

    testWidgets('closing the panel saves first', (tester) async {
      final c = await _pump(tester);
      await openRow(tester, 'Servo drive');
      await tester.enterText(descField(), 'Servo drive closed');
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(descOf(c, 'b'), 'Servo drive closed');
      expect(descField(), findsNothing);
    });

    testWidgets('an empty description is never saved', (tester) async {
      final c = await _pump(tester);
      await openRow(tester, 'Servo drive');
      await tester.enterText(descField(), '');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(descOf(c, 'b'), 'Servo drive');
    });

    testWidgets('untouched panels do not rewrite the order', (tester) async {
      final c = await _pump(tester);
      final before = c.read(projectProvider).standaloneOrders.firstWhere((o) => o.id == 'b').updatedAt;
      await openRow(tester, 'Servo drive');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      final after = c.read(projectProvider).standaloneOrders.firstWhere((o) => o.id == 'b').updatedAt;
      expect(after, before);
    });

    testWidgets('Mark delivered works from the panel without losing typed edits', (tester) async {
      final c = await _pump(tester);
      await openRow(tester, 'Servo drive');
      await tester.enterText(descField(), 'Servo drive final');
      await tester.pump();
      final btn = find.widgetWithText(ElevatedButton, 'Mark delivered');
      await tester.tap(btn.first);
      await tester.pumpAndSettle();
      final o = c.read(projectProvider).standaloneOrders.firstWhere((o) => o.id == 'b');
      expect(o.delivered, isTrue);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      final after = c.read(projectProvider).standaloneOrders.firstWhere((o) => o.id == 'b');
      expect(after.description, 'Servo drive final');
      expect(after.delivered, isTrue, reason: 'autosave must not undo the delivery');
    });
  });
}
