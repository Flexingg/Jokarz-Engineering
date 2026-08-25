import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/models/order_item.dart';
import 'package:jokarz_engineering/models/bolt_spec.dart';
import 'package:jokarz_engineering/ui/screens/calculators/heat_shrink_calculator_view.dart';

void main() {
  group('Manufacturing Domain Models Test', () {
    test('TaskItem serialization and copyWith', () {
      final task = TaskItem(
        description: 'Machine starwheel wear plates',
        scheduledDate: DateTime(2026, 8, 26),
        pendingReason: 'Pending mill downtime',
        isCompleted: false,
      );

      final json = task.toJson();
      final reconstructed = TaskItem.fromJson(json);

      expect(reconstructed.description, 'Machine starwheel wear plates');
      expect(reconstructed.pendingReason, 'Pending mill downtime');
      expect(reconstructed.isCompleted, false);
      expect(reconstructed.scheduledDate, DateTime(2026, 8, 26));

      final completed = reconstructed.copyWith(isCompleted: true);
      expect(completed.isCompleted, true);
    });

    test('OrderItem calculation and serialization', () {
      final order = OrderItem(
        pr: 'PR-48901',
        po: 'PO-9921004',
        description: 'UHMW 1/2" Sheet',
        price: 184.50,
        eta: DateTime(2026, 8, 28),
        delivered: false,
      );

      final json = order.toJson();
      final reconstructed = OrderItem.fromJson(json);

      expect(reconstructed.pr, 'PR-48901');
      expect(reconstructed.po, 'PO-9921004');
      expect(reconstructed.price, 184.50);
      expect(reconstructed.delivered, false);
    });

    test('Project manufacturing fields and next pending task logic', () {
      final t1 = TaskItem(
        id: 't-1',
        description: 'First task (done)',
        isCompleted: true,
      );
      final t2 = TaskItem(
        id: 't-2',
        description: 'Second task (pending parts)',
        pendingReason: 'Pending parts from McMaster',
        isCompleted: false,
      );
      final t3 = TaskItem(
        id: 't-3',
        description: 'Third task',
        isCompleted: false,
      );

      final project = Project(
        title: 'Line 1 Filler Rebuild',
        category: ProjectCategory.maintenance,
        phase: ProjectPhases.installation,
        machine: 'Line 1 Filler',
        subAssembly: 'Infeed Starwheel',
        cost: 2500.0,
        tasks: [t1, t2, t3],
        orders: [
          OrderItem(price: 500.0, delivered: true),
          OrderItem(price: 350.0, delivered: false),
        ],
      );

      expect(project.title, 'Line 1 Filler Rebuild');
      expect(project.category, ProjectCategory.maintenance);
      expect(project.phase, 'Installation');
      expect(project.machine, 'Line 1 Filler');
      expect(project.subAssembly, 'Infeed Starwheel');
      expect(project.cost, 2500.0);
      expect(project.totalOrdersCost, 850.0);
      expect(project.undeliveredOrdersCount, 1);
      expect(project.completedTasksCount, 1);

      // Next pending task auto-detects incomplete task with pending reason
      expect(project.nextPendingTask?.id, 't-2');
      expect(project.nextPendingTask?.pendingReason, 'Pending parts from McMaster');
    });
  });

  group('Mechanical Calculators & Fastener Reference Test', () {
    test('Fastener tap drill and clearance reference database consistency', () {
      // Metric tests
      final m6 = BoltSpec.database.firstWhere((b) => b.size == 'M6 x 1.0');
      expect(m6.tapDrillMm, 5.0);
      expect(m6.clearanceCloseMm, 6.4);
      expect(m6.clearanceFreeMm, 6.6);
      expect(m6.hexKeySize, '5.0 mm');
      expect(m6.gradeMid.dryNm, 15.0); // 10.9 dry torque in N-m

      final m50 = BoltSpec.database.firstWhere((b) => b.size == 'M50 x 5.0');
      expect(m50.tapDrillMm, 45.0);
      expect(m50.clearanceCloseMm, 51.0);
      expect(m50.hexKeySize, '36.0 mm');

      // Imperial tests
      final quarter20 = BoltSpec.database.firstWhere((b) => b.size == '1/4"-20 UNC');
      expect(quarter20.tapDrillFraction, '#7 (0.2010")');
      expect(quarter20.hexKeySize, '3/16"');
      expect(quarter20.gradeMid.dryFtLbs, closeTo(8.85, 0.1)); // Grade 5 dry torque

      final twoInch = BoltSpec.database.firstWhere((b) => b.size == '2"-4.5 UNC');
      expect(twoInch.tapDrillFraction, '1-25/32" (1.7812")');
      expect(twoInch.hexKeySize, '1-1/2"');
    });

    test('Heat Tint Tempering Scale and Thermal Expansion Verification', () {
      // Test Heat Tint Scale
      final roomTempTint = HeatTintInfo.getForTemp(20);
      expect(roomTempTint.name.contains('Unoxidized'), true);

      final strawTint = HeatTintInfo.getForTemp(240);
      expect(strawTint.name.contains('Straw'), true);

      final blueTint = HeatTintInfo.getForTemp(305);
      expect(blueTint.name.contains('Cobalt Blue'), true);

      final dullGreyTint = HeatTintInfo.getForTemp(450);
      expect(dullGreyTint.name.contains('Dull Grey'), true);

      // Test Thermal Expansion calculation: ΔD = D0 * α * ΔT
      // 50mm carbon steel (α = 11.7 x 10^-6 / °C) heated by 180°C (from 20°C to 200°C)
      const d0 = 50.0;
      const alpha = 11.7e-6;
      const deltaT = 180.0;
      final deltaD = d0 * alpha * deltaT; // 50 * 11.7e-6 * 180 = 0.1053 mm
      expect(deltaD, closeTo(0.1053, 0.001));

      // With 50.050mm shaft (0.050mm interference), hot clearance is 50.1053 - 50.050 = +0.0553 mm slip fit
      final hotClearance = (d0 + deltaD) - 50.050;
      expect(hotClearance, closeTo(0.0553, 0.001));
      expect(hotClearance > 0, true);
    });
  });
}
