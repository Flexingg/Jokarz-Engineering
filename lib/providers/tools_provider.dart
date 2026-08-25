import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/filament_profile.dart';
import '../models/bolt_spec.dart';

// --- 3D Print Cost Estimator State & Provider ---
class PrintEstimatorState {
  final FilamentProfile selectedFilament;
  final double partWeightGrams;
  final double printTimeHours;
  final double printerPowerWatts;
  final double electricityCostPerKwh;
  final double failureBufferPercent;
  final double operatorHourlyRate;
  final double operatorLaborMinutes;
  final double machineWearPerHour;

  PrintEstimatorState({
    FilamentProfile? selectedFilament,
    this.partWeightGrams = 125.0,
    this.printTimeHours = 4.5,
    this.printerPowerWatts = 150.0,
    this.electricityCostPerKwh = 0.15,
    this.failureBufferPercent = 10.0,
    this.operatorHourlyRate = 25.0,
    this.operatorLaborMinutes = 15.0,
    this.machineWearPerHour = 0.40,
  }) : selectedFilament =
            selectedFilament ?? FilamentProfile.defaultProfiles.first;

  double get rawFilamentCost =>
      (partWeightGrams / selectedFilament.spoolWeightG) *
      selectedFilament.spoolCostUsd;

  double get powerCost =>
      (printerPowerWatts * printTimeHours / 1000.0) * electricityCostPerKwh;

  double get machineWearCost => printTimeHours * machineWearPerHour;

  double get laborCost => (operatorLaborMinutes / 60.0) * operatorHourlyRate;

  double get subtotalCost =>
      rawFilamentCost + powerCost + machineWearCost + laborCost;

  double get failureBufferCost => subtotalCost * (failureBufferPercent / 100.0);

  double get totalNetCost => subtotalCost + failureBufferCost;

  double get suggestedPrice2x => totalNetCost * 2.0;
  double get suggestedPrice3x => totalNetCost * 3.0;

  PrintEstimatorState copyWith({
    FilamentProfile? selectedFilament,
    double? partWeightGrams,
    double? printTimeHours,
    double? printerPowerWatts,
    double? electricityCostPerKwh,
    double? failureBufferPercent,
    double? operatorHourlyRate,
    double? operatorLaborMinutes,
    double? machineWearPerHour,
  }) {
    return PrintEstimatorState(
      selectedFilament: selectedFilament ?? this.selectedFilament,
      partWeightGrams: partWeightGrams ?? this.partWeightGrams,
      printTimeHours: printTimeHours ?? this.printTimeHours,
      printerPowerWatts: printerPowerWatts ?? this.printerPowerWatts,
      electricityCostPerKwh:
          electricityCostPerKwh ?? this.electricityCostPerKwh,
      failureBufferPercent: failureBufferPercent ?? this.failureBufferPercent,
      operatorHourlyRate: operatorHourlyRate ?? this.operatorHourlyRate,
      operatorLaborMinutes:
          operatorLaborMinutes ?? this.operatorLaborMinutes,
      machineWearPerHour: machineWearPerHour ?? this.machineWearPerHour,
    );
  }
}

class PrintEstimatorNotifier extends StateNotifier<PrintEstimatorState> {
  PrintEstimatorNotifier() : super(PrintEstimatorState());

  void setFilament(FilamentProfile profile) {
    state = state.copyWith(selectedFilament: profile);
  }

  void updateParams({
    double? weight,
    double? hours,
    double? watts,
    double? kwhCost,
    double? failureBuffer,
    double? laborRate,
    double? laborMins,
    double? wearRate,
  }) {
    state = state.copyWith(
      partWeightGrams: weight,
      printTimeHours: hours,
      printerPowerWatts: watts,
      electricityCostPerKwh: kwhCost,
      failureBufferPercent: failureBuffer,
      operatorHourlyRate: laborRate,
      operatorLaborMinutes: laborMins,
      machineWearPerHour: wearRate,
    );
  }
}

final printEstimatorProvider =
    StateNotifierProvider<PrintEstimatorNotifier, PrintEstimatorState>((ref) {
  return PrintEstimatorNotifier();
});

// --- Fasteners Filter Provider ---
final fastenerSearchProvider = StateProvider<String>((ref) => '');
final fastenerStandardProvider = StateProvider<FastenerStandard?>((ref) => null);

final filteredFastenersProvider = Provider<List<BoltSpec>>((ref) {
  final search = ref.watch(fastenerSearchProvider).toLowerCase();
  final standard = ref.watch(fastenerStandardProvider);

  return BoltSpec.database.where((b) {
    final matchesSearch = search.isEmpty ||
        b.size.toLowerCase().contains(search) ||
        b.pitchOrTpi.toLowerCase().contains(search) ||
        b.tapDrillFraction.toLowerCase().contains(search);
    final matchesStandard = standard == null || b.standard == standard;
    return matchesSearch && matchesStandard;
  }).toList();
});

// --- Resistor Color Code Calculator State ---
enum ResistorBandMode { fourBand, fiveBand }

class ResistorCodeState {
  final ResistorBandMode mode;
  final int band1; // 0-9
  final int band2; // 0-9
  final int band3; // 0-9 (for 5 band)
  final int multiplier; // power of 10
  final double tolerancePercent;

  const ResistorCodeState({
    this.mode = ResistorBandMode.fourBand,
    this.band1 = 1, // Brown
    this.band2 = 0, // Black
    this.band3 = 0, // Black
    this.multiplier = 2, // 10^2 = 100 -> 1000 Ohm (1k)
    this.tolerancePercent = 5.0, // Gold 5%
  });

  double get resistanceOhms {
    if (mode == ResistorBandMode.fourBand) {
      final base = (band1 * 10) + band2;
      return base * math.pow(10, multiplier).toDouble();
    } else {
      final base = (band1 * 100) + (band2 * 10) + band3;
      return base * math.pow(10, multiplier).toDouble();
    }
  }

  String get formattedResistance {
    final r = resistanceOhms;
    if (r >= 1000000) {
      return '${(r / 1000000).toStringAsFixed(2)} MΩ';
    } else if (r >= 1000) {
      return '${(r / 1000).toStringAsFixed(2)} kΩ';
    } else {
      return '${r.toStringAsFixed(1)} Ω';
    }
  }

  ResistorCodeState copyWith({
    ResistorBandMode? mode,
    int? band1,
    int? band2,
    int? band3,
    int? multiplier,
    double? tolerancePercent,
  }) {
    return ResistorCodeState(
      mode: mode ?? this.mode,
      band1: band1 ?? this.band1,
      band2: band2 ?? this.band2,
      band3: band3 ?? this.band3,
      multiplier: multiplier ?? this.multiplier,
      tolerancePercent: tolerancePercent ?? this.tolerancePercent,
    );
  }
}

class ResistorNotifier extends StateNotifier<ResistorCodeState> {
  ResistorNotifier() : super(const ResistorCodeState());

  void setMode(ResistorBandMode mode) => state = state.copyWith(mode: mode);
  void setBand1(int val) => state = state.copyWith(band1: val);
  void setBand2(int val) => state = state.copyWith(band2: val);
  void setBand3(int val) => state = state.copyWith(band3: val);
  void setMultiplier(int val) => state = state.copyWith(multiplier: val);
  void setTolerance(double val) => state = state.copyWith(tolerancePercent: val);
}

final resistorProvider =
    StateNotifierProvider<ResistorNotifier, ResistorCodeState>((ref) {
  return ResistorNotifier();
});
