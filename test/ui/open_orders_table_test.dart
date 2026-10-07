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

  testWidgets(
    'right-click opens the row menu; clicking a row opens the details drawer',
    (tester) async {
      await _pump(tester);

      final row = find.text('Servo drive');
      final gesture = await tester.startGesture(
        tester.getCenter(row),
        buttons: kSecondaryButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Open details'), findsOneWidget);
      expect(find.text('Copy PO #'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5)); // dismiss
      await tester.pumpAndSettle();

      await tester.tap(find.text('Servo drive'));
      await tester.pumpAndSettle();
      expect(
        find.text('PO 4500187302'),
        findsOneWidget,
        reason: 'drawer header',
      );
      expect(
        find.text('Close details'),
        findsNothing,
      ); // tooltip text only, not visible
      await tester.tap(find.byTooltip('Close details'));
      await tester.pumpAndSettle();
      expect(find.text('PO 4500187302'), findsNothing);
    },
  );
}
