import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/bolt_spec.dart';
import 'package:jokarz_engineering/models/bom_item.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/filament_profile.dart';
import 'package:jokarz_engineering/providers/tools_provider.dart';

void main() {
  group('Engineering Domain Models Test', () {
    test('BOMItem calculation and serialization', () {
      final item = BOMItem(
        name: 'M3x10 Socket Screw',
        unitCost: 0.15,
        quantity: 20,
        category: BOMCategory.fastener,
      );

      expect(item.totalCost, closeTo(3.00, 0.001));

      final json = item.toJson();
      final restored = BOMItem.fromJson(json);

      expect(restored.name, 'M3x10 Socket Screw');
      expect(restored.totalCost, closeTo(3.00, 0.001));
      expect(restored.category, BOMCategory.fastener);
    });

    test('Project BOM cost summation & completion ratio', () {
      final project = Project(
        title: 'CNC Spindle Mount',
        bom: [
          BOMItem(name: 'Part 1', unitCost: 10.0, quantity: 2, isPurchased: true),
          BOMItem(name: 'Part 2', unitCost: 5.0, quantity: 4, isPurchased: false),
        ],
      );

      expect(project.totalBOMCost, closeTo(40.0, 0.001));
      expect(project.purchasedItemCount, 1);
      expect(project.bomCompletionRatio, closeTo(0.5, 0.001));
    });

    test('Bolt database includes standard Metric and Imperial sizes', () {
      final bolts = BoltSpec.database;
      expect(bolts.isNotEmpty, true);

      final m3 = bolts.firstWhere((b) => b.size == 'M3 x 0.5');
      expect(m3.tapDrillMm, 2.5);
      expect(m3.standard, FastenerStandard.metric);

      final quarterTwenty = bolts.firstWhere((b) => b.size == '1/4"-20 UNC');
      expect(quarterTwenty.majorDiaMm, 6.35);
      expect(quarterTwenty.standard, FastenerStandard.imperial);
    });
  });

  group('Print Estimator Calculations', () {
    test('Calculates 3D print costs accurately', () {
      final state = PrintEstimatorState(
        selectedFilament: FilamentProfile.defaultProfiles.first, // PLA ($18/kg)
        partWeightGrams: 200.0,
        printTimeHours: 5.0,
        printerPowerWatts: 150.0,
        electricityCostPerKwh: 0.15,
        failureBufferPercent: 10.0,
        operatorHourlyRate: 30.0,
        operatorLaborMinutes: 10.0,
        machineWearPerHour: 0.50,
      );

      // Raw filament: (200 / 1000) * 18 = 3.60
      expect(state.rawFilamentCost, closeTo(3.60, 0.01));

      // Power: (150 * 5 / 1000) * 0.15 = 0.1125
      expect(state.powerCost, closeTo(0.1125, 0.001));

      // Wear: 5 * 0.50 = 2.50
      expect(state.machineWearCost, closeTo(2.50, 0.01));

      // Labor: (10 / 60) * 30 = 5.00
      expect(state.laborCost, closeTo(5.00, 0.01));

      // Subtotal: 3.60 + 0.1125 + 2.50 + 5.00 = 11.2125
      expect(state.subtotalCost, closeTo(11.2125, 0.01));

      // Total with 10% buffer: 11.2125 * 1.1 = 12.33375
      expect(state.totalNetCost, closeTo(12.33, 0.02));

      // Commercial 2x
      expect(state.suggestedPrice2x, closeTo(state.totalNetCost * 2, 0.01));
    });
  });

  group('Resistor Code Decoder', () {
    test('Decodes 4-band 10k resistor correctly (Brown, Black, Orange)', () {
      const state = ResistorCodeState(
        mode: ResistorBandMode.fourBand,
        band1: 1, // Brown
        band2: 0, // Black
        multiplier: 3, // 10^3 = 1000 -> 10,000 Ohm
        tolerancePercent: 5.0,
      );

      expect(state.resistanceOhms, 10000.0);
      expect(state.formattedResistance, '10.00 kΩ');
    });

    test('Decodes 4.7k resistor correctly (Yellow, Violet, Red)', () {
      const state = ResistorCodeState(
        mode: ResistorBandMode.fourBand,
        band1: 4, // Yellow
        band2: 7, // Violet
        multiplier: 2, // 10^2 = 100 -> 4,700 Ohm
        tolerancePercent: 1.0,
      );

      expect(state.resistanceOhms, 4700.0);
      expect(state.formattedResistance, '4.70 kΩ');
    });
  });
}
