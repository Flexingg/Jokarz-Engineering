import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/inbox_item.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/models/project_template.dart';
import 'package:jokarz_engineering/models/machine_asset.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/order_item.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/downtime_event.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';

void main() {
  group('Feature 1: Quick-Capture Inbox Items', () {
    test('InboxItem serialization and defaults round-trip', () {
      final item = InboxItem(
        text: 'Check Line 3 conveyor bearing',
      );
      expect(item.id, isNotEmpty);
      expect(item.isProcessed, isFalse);

      final json = item.toJson();
      final restored = InboxItem.fromJson(json);

      expect(restored.id, equals(item.id));
      expect(restored.text, equals('Check Line 3 conveyor bearing'));
      expect(restored.isProcessed, isFalse);
    });

    test('InboxItem copyWith toggles processed state', () {
      final item = InboxItem(text: 'Order spare valve');
      final processed = item.copyWith(isProcessed: true);

      expect(processed.isProcessed, isTrue);
      expect(processed.text, equals('Order spare valve'));
    });
  });

  group('Feature 2: Disk-Backed Snooze Logic', () {
    test('queuedProjects filters out projects snoozed for today', () {
      final p1 = Project(id: 'p1', title: 'Project 1', priority: 1);
      final p2 = Project(id: 'p2', title: 'Project 2', priority: 2);

      final todayStr = EngineeringState.todayString;

      final state = EngineeringState(
        projects: [p1, p2],
        snoozedProjects: {'p1': todayStr},
      );

      final queue = state.queuedProjects;
      expect(queue.length, equals(1));
      expect(queue.first.id, equals('p2'));
    });

    test('queuedProjects includes project snoozed on an expired date', () {
      final p1 = Project(id: 'p1', title: 'Project 1', priority: 1);

      final state = EngineeringState(
        projects: [p1],
        snoozedProjects: {'p1': '2020-01-01'},
      );

      final queue = state.queuedProjects;
      expect(queue.length, equals(1));
      expect(queue.first.id, equals('p1'));
    });
  });

  group('Feature 3: Vendors & Supplier Directory', () {
    test('Vendor serialization round-trip', () {
      final v = Vendor(
        name: 'McMaster-Carr',
        contactPerson: 'Sarah Connor',
        email: 'orders@mcmaster.com',
        phone: '1-800-555-0199',
        accountNumber: 'ACC-9876',
        notes: 'Next-day delivery available',
      );

      final json = v.toJson();
      final restored = Vendor.fromJson(json);

      expect(restored.name, equals('McMaster-Carr'));
      expect(restored.contactPerson, equals('Sarah Connor'));
      expect(restored.accountNumber, equals('ACC-9876'));
    });

    test('OrderItem & StandaloneOrder store vendor and tracking data', () {
      final order = OrderItem(
        description: 'Pillow Block Bearing 1.5"',
        price: 84.50,
        vendorId: 'v1',
        vendorName: 'McMaster-Carr',
        vendorQuoteNumber: 'Q-2026-11',
        trackingUrl: 'https://ups.com/track?123',
      );

      final json = order.toJson();
      final restored = OrderItem.fromJson(json);

      expect(restored.vendorName, equals('McMaster-Carr'));
      expect(restored.vendorQuoteNumber, equals('Q-2026-11'));
      expect(restored.trackingUrl, equals('https://ups.com/track?123'));

      final standalone = StandaloneOrder(
        description: 'Pneumatic Cylinder',
        price: 210.0,
        vendorId: 'v2',
        vendorName: 'SMC',
        vendorQuoteNumber: 'SMC-445',
        trackingUrl: 'https://fedex.com/track/445',
      );

      final sJson = standalone.toJson();
      final sRestored = StandaloneOrder.fromJson(sJson);

      expect(sRestored.vendorName, equals('SMC'));
      expect(sRestored.trackingUrl, equals('https://fedex.com/track/445'));
    });
  });

  group('Feature 5: Plant Machine Asset Hub', () {
    test('MachineAsset aggregates active projects, open orders, and downtimes', () {
      final p1 = Project(
        id: 'p1',
        title: 'Line 2 Motor Rebuild',
        machine: 'Line 2 / Filler',
        subAssembly: 'Drive',
        category: ProjectCategory.maintenance,
        orders: [
          OrderItem(description: 'Coupling', price: 50.0, delivered: false),
        ],

      );

      final downtime = DowntimeEvent(
        machine: 'Line 2',
        title: 'Belt Snap',
        date: DateTime.now(),
      );

      final state = EngineeringState(
        projects: [p1],
        downtimes: [downtime],
      );

      final assets = state.machineAssets;
      final line2Asset = assets.firstWhere((a) => a.name == 'Line 2');

      expect(line2Asset.activeProjects.length, equals(1));
      expect(line2Asset.totalOpenOrderSpend, equals(50.0));
      expect(line2Asset.downtimes.length, equals(1));
      expect(line2Asset.status, equals(MachineStatus.breakdown));
    });
  });

  group('Feature 6: Reusable Project & PM Templates', () {
    test('Built-in system templates are available and populated', () {
      final templates = ProjectTemplate.systemTemplates;
      expect(templates, isNotEmpty);
      expect(templates.length, equals(6));

      final inHouse =
          templates.firstWhere((t) => t.name.contains('In House Design'));
      expect(inHouse.tasks.map((t) => t.description),
          containsAll(['Fabricate', 'Install', 'Validate']));

      final partsRequest =
          templates.firstWhere((t) => t.name.contains('Parts Request'));
      expect(partsRequest.tasks.length, equals(3));

      final largeCapital =
          templates.firstWhere((t) => t.name.contains('Large Capital'));
      expect(largeCapital.tasks.length, equals(11));
      expect(largeCapital.tasks.map((t) => t.description),
          contains('Make PPMA docs'));
    });

    test('Custom template serialization round-trip', () {
      final custom = ProjectTemplate(
        name: 'Custom Line Sanitization',
        description: 'Weekly CIP sanitization steps',
        category: ProjectCategory.maintenance,
        tasks: const [
          TaskTemplate(description: 'Flush line with caustic', offsetDays: 0),
          TaskTemplate(description: 'Acid rinse & ATP swab testing', offsetDays: 1),
        ],
        suggestedOrders: const [
          OrderTemplate(description: 'ATP Test Swabs box of 100', estimatedPrice: 150.0),
        ],
      );

      final json = custom.toJson();
      final restored = ProjectTemplate.fromJson(json);

      expect(restored.name, equals('Custom Line Sanitization'));
      expect(restored.tasks.length, equals(2));
      expect(restored.suggestedOrders.length, equals(1));
    });
  });
}
