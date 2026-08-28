import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/order_item.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';

void main() {
  group('OrderItem stores-tracking fields', () {
    test('defaults are off/empty', () {
      final o = OrderItem(description: 'Bearings');
      expect(o.addToStores, isFalse);
      expect(o.storeRequested, isFalse);
      expect(o.storeRequestNumber, isEmpty);
    });

    test('copyWith updates store fields', () {
      final o = OrderItem(description: 'Bearings');
      final u = o
          .copyWith(addToStores: true)
          .copyWith(storeRequested: true)
          .copyWith(storeRequestNumber: '80231');
      expect(u.addToStores, isTrue);
      expect(u.storeRequested, isTrue);
      expect(u.storeRequestNumber, '80231');
      // Original unchanged
      expect(o.addToStores, isFalse);
    });

    test('JSON round-trip preserves store fields', () {
      final o = OrderItem(
        description: 'Bearings',
        po: 'PO-100',
        addToStores: true,
        storeRequested: true,
        storeRequestNumber: '80231',
      );
      final restored = OrderItem.fromJson(o.toJson());
      expect(restored.description, 'Bearings');
      expect(restored.po, 'PO-100');
      expect(restored.addToStores, isTrue);
      expect(restored.storeRequested, isTrue);
      expect(restored.storeRequestNumber, '80231');
    });

    test('missing JSON keys fall back to defaults', () {
      final restored = OrderItem.fromJson({'id': 'x', 'description': 'Part'});
      expect(restored.addToStores, isFalse);
      expect(restored.storeRequested, isFalse);
      expect(restored.storeRequestNumber, isEmpty);
    });
  });

  test('StandaloneOrder stores fields JSON round-trip', () {
    final o = StandaloneOrder(
        description: 'Seals',
        addToStores: true,
        storeRequested: true,
        storeRequestNumber: 'SR-42');
    final r = StandaloneOrder.fromJson(o.toJson());
    expect(r.description, 'Seals');
    expect(r.addToStores, isTrue);
    expect(r.storeRequested, isTrue);
    expect(r.storeRequestNumber, 'SR-42');
  });

  test('StandaloneOrder missing stores keys fall back to defaults', () {
    final r = StandaloneOrder.fromJson({'id': 'x', 'description': 'Part'});
    expect(r.addToStores, isFalse);
    expect(r.storeRequestNumber, isEmpty);
  });
}
