import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/order_item.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/ui/screens/vendors_screen.dart';

import '../helpers/memory_storage.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  double width = 1400,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final rexel = Vendor(id: 'v1', name: 'Rexel', contactPerson: 'Dana');
  final grainger = Vendor(id: 'v2', name: 'Grainger');
  final storage = MemoryStorage(
    vendors: [rexel, grainger],
    projects: [
      Project(
        id: 'p1',
        title: 'Palletizer retrofit',
        orders: [
          OrderItem(
            id: 'o1',
            description: 'Servo drive',
            po: '4500187302',
            price: 3180,
            vendorId: 'v1',
          ),
          OrderItem(
            id: 'o2',
            description: 'HMI panel',
            po: '4500187468',
            price: 2240,
            vendorName: 'rexel',
            delivered: true,
          ),
          OrderItem(
            id: 'o3',
            description: 'Guard switch',
            price: 268.4,
            vendorId: 'v2',
          ),
        ],
      ),
    ],
    orders: [
      StandaloneOrder(
        id: 's1',
        description: 'Contactor kit',
        price: 80,
        vendorId: 'v1',
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: VendorsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'wide: the detail pane lists a vendor\'s orders (by id, or by name) and totals them',
    (tester) async {
      await _pump(tester);
      // First vendor is selected by default: Rexel has 3 orders (2 by id/name in a project + 1 standalone).
      expect(find.text('Orders from this vendor'), findsOneWidget);
      expect(find.text('Servo drive'), findsOneWidget);
      expect(find.text('HMI panel'), findsOneWidget);
      expect(find.text('Contactor kit'), findsOneWidget);
      expect(
        find.text('Guard switch'),
        findsNothing,
        reason: 'belongs to Grainger',
      );
      expect(
        find.text('\$5,500.00'),
        findsOneWidget,
        reason: '3180 + 2240 + 80',
      );
    },
  );

  testWidgets('selecting another vendor swaps the detail pane', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Grainger').first);
    await tester.pumpAndSettle();
    expect(find.text('Guard switch'), findsOneWidget);
    expect(find.text('Servo drive'), findsNothing);
  });

  testWidgets('narrow: no detail pane', (tester) async {
    await _pump(tester, width: 500);
    expect(find.text('Orders from this vendor'), findsNothing);
  });

  testWidgets(
    'right-click on a vendor card offers Edit and Delete; Delete removes it',
    (tester) async {
      final c = await _pump(tester);
      final card = find.text('Grainger').first;
      final g = await tester.startGesture(
        tester.getCenter(card),
        buttons: kSecondaryButton,
      );
      await g.up();
      await tester.pumpAndSettle();
      expect(find.text('Edit...'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(c.read(projectProvider).vendors.map((v) => v.id), ['v1']);
    },
  );
}
