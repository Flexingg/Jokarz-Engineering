class FilamentProfile {
  final String id;
  final String name;
  final String material; // PLA, PETG, ABS, TPU, ASA, PC, Nylon, Carbon Fiber
  final double densityGcm3;
  final double spoolWeightG;
  final double spoolCostUsd;
  final double diameterMm;
  final int nozzleTempC;
  final int bedTempC;
  final String colorHex;

  const FilamentProfile({
    required this.id,
    required this.name,
    required this.material,
    required this.densityGcm3,
    this.spoolWeightG = 1000.0,
    this.spoolCostUsd = 20.0,
    this.diameterMm = 1.75,
    this.nozzleTempC = 210,
    this.bedTempC = 60,
    this.colorHex = '00E5FF',
  });

  double get costPerGram => spoolCostUsd / spoolWeightG;

  static List<FilamentProfile> get defaultProfiles => [
        const FilamentProfile(
          id: 'pla_standard',
          name: 'Generic PLA (High Speed)',
          material: 'PLA',
          densityGcm3: 1.24,
          spoolWeightG: 1000,
          spoolCostUsd: 18.0,
          nozzleTempC: 215,
          bedTempC: 60,
          colorHex: '00E5FF',
        ),
        const FilamentProfile(
          id: 'petg_standard',
          name: 'Industrial Tough PETG',
          material: 'PETG',
          densityGcm3: 1.27,
          spoolWeightG: 1000,
          spoolCostUsd: 22.0,
          nozzleTempC: 240,
          bedTempC: 80,
          colorHex: '00E676',
        ),
        const FilamentProfile(
          id: 'abs_standard',
          name: 'ABS Structural (Enclosed)',
          material: 'ABS',
          densityGcm3: 1.04,
          spoolWeightG: 1000,
          spoolCostUsd: 20.0,
          nozzleTempC: 250,
          bedTempC: 100,
          colorHex: 'FFB300',
        ),
        const FilamentProfile(
          id: 'tpu_95a',
          name: 'TPU 95A Flexible',
          material: 'TPU',
          densityGcm3: 1.21,
          spoolWeightG: 1000,
          spoolCostUsd: 28.0,
          nozzleTempC: 225,
          bedTempC: 50,
          colorHex: '9D4EDD',
        ),
        const FilamentProfile(
          id: 'cf_petg',
          name: 'Carbon Fiber PETG (Rigid)',
          material: 'CF-PETG',
          densityGcm3: 1.32,
          spoolWeightG: 1000,
          spoolCostUsd: 38.0,
          nozzleTempC: 255,
          bedTempC: 85,
          colorHex: 'FF3D71',
        ),
        const FilamentProfile(
          id: 'asa_outdoor',
          name: 'ASA UV-Resistant Outdoor',
          material: 'ASA',
          densityGcm3: 1.07,
          spoolWeightG: 1000,
          spoolCostUsd: 26.0,
          nozzleTempC: 260,
          bedTempC: 105,
          colorHex: '0066FF',
        ),
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'material': material,
      'densityGcm3': densityGcm3,
      'spoolWeightG': spoolWeightG,
      'spoolCostUsd': spoolCostUsd,
      'diameterMm': diameterMm,
      'nozzleTempC': nozzleTempC,
      'bedTempC': bedTempC,
      'colorHex': colorHex,
    };
  }

  factory FilamentProfile.fromJson(Map<String, dynamic> json) {
    return FilamentProfile(
      id: json['id'] as String? ?? 'custom',
      name: json['name'] as String? ?? 'Custom Filament',
      material: json['material'] as String? ?? 'PLA',
      densityGcm3: (json['densityGcm3'] as num?)?.toDouble() ?? 1.24,
      spoolWeightG: (json['spoolWeightG'] as num?)?.toDouble() ?? 1000.0,
      spoolCostUsd: (json['spoolCostUsd'] as num?)?.toDouble() ?? 20.0,
      diameterMm: (json['diameterMm'] as num?)?.toDouble() ?? 1.75,
      nozzleTempC: (json['nozzleTempC'] as num?)?.toInt() ?? 210,
      bedTempC: (json['bedTempC'] as num?)?.toInt() ?? 60,
      colorHex: json['colorHex'] as String? ?? '00E5FF',
    );
  }
}
