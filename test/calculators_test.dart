import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/models/order_item.dart';
import 'package:jokarz_engineering/models/bolt_spec.dart';
import 'package:jokarz_engineering/models/filament_profile.dart';
import 'package:jokarz_engineering/providers/tools_provider.dart';

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

    test('Fastener tap drill and clearance reference database', () {
      final m6 = BoltSpec.database.firstWhere((b) => b.size == 'M6 x 1.0');
      expect(m6.tapDrillMm, 5.0);
      expect(m6.clearanceCloseMm, 6.4);
      expect(m6.clearanceFreeMm, 6.6);
      expect(m6.hexKeySize, '5.0 mm');

      final quarter20 = BoltSpec.database.firstWhere((b) => b.size == '1/4"-20 UNC');
      expect(quarter20.tapDrillFraction, '#7 (0.2010")');
      expect(quarter20.hexKeySize, '3/16"');
    });
  });

  group('Workbench Calculators Test', () {
    test('Calculates 3D print costs accurately', () {
      final state = PrintEstimatorState(
        selectedFilament: FilamentProfile.defaultProfiles.first, // PLA ($18/kg)
        partWeightGrams: 100.0, // 0.1 kg -> $1.80
        printTimeHours: 5.0,
        printerPowerWatts: 150.0, // 0.15 kW * 5h = 0.75 kWh @ $0.14 = $0.105
        electricityCostPerKwh: 0.14,
        failureBufferPercent: 10.0, // 10%
        operatorHourlyRate: 25.0,
        operatorLaborMinutes: 12.0, // 0.2h * $25 = $5.00
        machineWearPerHour: 0.40, // 5h * $0.40 = $2.00
      );

      // Raw filament: 1.80
      expect(state.rawFilamentCost, closeTo(1.80, 0.01));
      // Power: 0.105
      expect(state.powerCost, closeTo(0.105, 0.01));
      // Machine wear: 2.00
      expect(state.machineWearCost, closeTo(2.00, 0.01));
      // Labor: 5.00
      expect(state.laborCost, closeTo(5.00, 0.01));

      // Subtotal: 1.80 + 0.105 + 2.00 + 5.00 = 8.905
      expect(state.subtotalCost, closeTo(8.905, 0.01));
      // Buffer: 0.8905
      expect(state.failureBufferCost, closeTo(0.8905, 0.01));
      // Net: ~9.80
      expect(state.totalNetCost, closeTo(9.795, 0.02));
    });

    test('Decodes 4-band 10k resistor correctly (Brown, Black, Orange)', () {
      const state = ResistorCodeState(
        mode: ResistorBandMode.fourBand,
        band1: 1, // Brown (1)
        band2: 0, // Black (0)
        multiplier: 3, // Orange (10^3 = 1000) -> 10,000 Ohm
        tolerancePercent: 5.0,
      );

      expect(state.resistanceOhms, 10000.0);
      expect(state.formattedResistance, '10.00 kΩ');
      expect(state.tolerancePercent, 5.0);
    });
  });
}
