import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

enum CylinderFluidType {
  pneumatic('Pneumatic (Compressed Air)', 6.2, 90.0),
  hydraulic('Hydraulic (High-Pressure Oil)', 140.0, 2000.0);

  final String label;
  final double defaultBar;
  final double defaultPsi;
  const CylinderFluidType(this.label, this.defaultBar, this.defaultPsi);
}

class CylinderCalculatorView extends StatefulWidget {
  const CylinderCalculatorView({super.key});

  @override
  State<CylinderCalculatorView> createState() => _CylinderCalculatorViewState();
}

class _CylinderCalculatorViewState extends State<CylinderCalculatorView> {
  bool _isMetric = true;
  CylinderFluidType _fluidType = CylinderFluidType.pneumatic;

  final _boreCtrl = TextEditingController(text: '50'); // mm or inch
  final _rodCtrl = TextEditingController(text: '20'); // mm or inch
  final _strokeCtrl = TextEditingController(text: '150'); // mm or inch
  final _pressureCtrl = TextEditingController(text: '6.2'); // bar or psi
  final _cpmCtrl = TextEditingController(text: '20'); // cycles per minute

  double _pushForceLbf = 0;
  double _pullForceLbf = 0;
  double _pushForceN = 0;
  double _pullForceN = 0;
  double _airScfm = 0; // standard cubic feet per minute (pneumatic)
  double _flowLpm = 0; // liters per minute free air / oil
  String _recommendedPort = '';

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _boreCtrl.dispose();
    _rodCtrl.dispose();
    _strokeCtrl.dispose();
    _pressureCtrl.dispose();
    _cpmCtrl.dispose();
    super.dispose();
  }

  void _onFluidTypeChanged(CylinderFluidType type) {
    setState(() {
      _fluidType = type;
      _pressureCtrl.text = _isMetric ? type.defaultBar.toString() : type.defaultPsi.toString();
      _recalculate();
    });
  }

  void _recalculate() {
    final bore = double.tryParse(_boreCtrl.text) ?? 50.0;
    final rod = double.tryParse(_rodCtrl.text) ?? 20.0;
    final stroke = double.tryParse(_strokeCtrl.text) ?? 150.0;
    final pressure = double.tryParse(_pressureCtrl.text) ?? 6.2;
    final cpm = double.tryParse(_cpmCtrl.text) ?? 20.0;

    if (bore <= 0 || stroke <= 0) return;

    // Convert everything to standard base for calculation: inches & psi
    final double boreIn = _isMetric ? bore / 25.4 : bore;
    final double rodIn = _isMetric ? rod / 25.4 : rod;
    final double strokeIn = _isMetric ? stroke / 25.4 : stroke;
    final double pressurePsi = _isMetric ? pressure * 14.5038 : pressure;

    final double boreAreaSqIn = (math.pi / 4.0) * math.pow(boreIn, 2);
    final double rodAreaSqIn = (math.pi / 4.0) * math.pow(rodIn, 2);
    final double pullAreaSqIn = math.max(0.0, boreAreaSqIn - rodAreaSqIn);

    // Forces
    final pushLbf = pressurePsi * boreAreaSqIn;
    final pullLbf = pressurePsi * pullAreaSqIn;
    final pushN = pushLbf * 4.44822;
    final pullN = pullLbf * 4.44822;

    // Volume per cycle in cubic inches
    final pushVolCuIn = boreAreaSqIn * strokeIn;
    final pullVolCuIn = pullAreaSqIn * strokeIn;
    final cycleVolCuIn = pushVolCuIn + pullVolCuIn;

    // Compressed Air consumption (SCFM)
    // Compression Ratio = (P + 14.7) / 14.7
    final compressionRatio = (pressurePsi + 14.7) / 14.7;
    final scfm = (cycleVolCuIn * cpm * compressionRatio) / 1728.0;
    final lpm = scfm * 28.3168;

    // Recommended tubing / port guideline based on CFM
    String port;
    if (_fluidType == CylinderFluidType.pneumatic) {
      if (scfm < 2.0) {
        port = '1/8" NPT (4mm OD tube)';
      } else if (scfm < 8.0) {
        port = '1/4" NPT (6mm or 8mm OD tube)';
      } else if (scfm < 25.0) {
        port = '3/8" NPT (10mm OD tube)';
      } else {
        port = '1/2" NPT (12mm or 16mm OD tube)';
      }
    } else {
      // Hydraulic oil ports
      if (lpm < 15.0) {
        port = '#4 SAE / 1/4" NPT';
      } else if (lpm < 45.0) {
        port = '#6 SAE / 3/8" NPT';
      } else {
        port = '#8 SAE / 1/2" NPT';
      }
    }

    setState(() {
      _pushForceLbf = pushLbf;
      _pullForceLbf = pullLbf;
      _pushForceN = pushN;
      _pullForceN = pullN;
      _airScfm = scfm;
      _flowLpm = lpm;
      _recommendedPort = port;
    });
  }

  void _toggleUnits(bool metric) {
    if (_isMetric == metric) return;
    setState(() {
      _isMetric = metric;
      final mult = metric ? 25.4 : 1.0 / 25.4;
      final pressMult = metric ? (1.0 / 14.5038) : 14.5038;

      final bore = (double.tryParse(_boreCtrl.text) ?? 50.0) * mult;
      final rod = (double.tryParse(_rodCtrl.text) ?? 20.0) * mult;
      final stroke = (double.tryParse(_strokeCtrl.text) ?? 150.0) * mult;
      final pressure = (double.tryParse(_pressureCtrl.text) ?? 6.2) * pressMult;

      _boreCtrl.text = bore.toStringAsFixed(metric ? 1 : 2);
      _rodCtrl.text = rod.toStringAsFixed(metric ? 1 : 2);
      _strokeCtrl.text = stroke.toStringAsFixed(metric ? 0 : 2);
      _pressureCtrl.text = pressure.toStringAsFixed(metric ? 1 : 0);

      _recalculate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final unit = _isMetric ? 'mm' : 'in';
    final pressUnit = _isMetric ? 'bar' : 'psi';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Units
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cylinder Force & Sizing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pneumatic & Hydraulic push/pull load, CFM flow & sizing',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Metric')),
                  ButtonSegment(value: false, label: Text('Imperial')),
                ],
                selected: {_isMetric},
                onSelectionChanged: (s) => _toggleUnits(s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fluid Selection
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Media Type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<CylinderFluidType>(
                  segments: CylinderFluidType.values.map((f) {
                    return ButtonSegment(
                      value: f,
                      label: Text(f == CylinderFluidType.pneumatic ? 'Air (Pneumatic)' : 'Oil (Hydraulic)'),
                      icon: Icon(f == CylinderFluidType.pneumatic ? Icons.air_rounded : Icons.water_drop_rounded),
                    );
                  }).toList(),
                  selected: {_fluidType},
                  onSelectionChanged: (s) => _onFluidTypeChanged(s.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dimensional Inputs
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Cylinder Dimensions & Operating Parameters',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _boreCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Bore Diameter',
                          suffixText: unit,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => _recalculate(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _rodCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Rod Diameter',
                          suffixText: unit,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => _recalculate(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _strokeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Stroke Length',
                          suffixText: unit,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => _recalculate(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pressureCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Line Pressure',
                          suffixText: pressUnit,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => _recalculate(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cpmCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Cycle Rate (Cylinders strokes per minute)',
                    suffixText: 'CPM',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => _recalculate(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Output Forces & Flow Results
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3. Output Force & Flow Demands',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    ExpressiveBadge(
                      label: 'Port: $_recommendedPort',
                      color: colors.primary,
                      fontSize: 10,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ForceCard(
                        direction: 'Extension (Push)',
                        forcePrimary: _isMetric
                            ? '${(_pushForceN / 1000).toStringAsFixed(2)} kN'
                            : '${_pushForceLbf.toStringAsFixed(0)} lbf',
                        forceSecondary: _isMetric
                            ? '${_pushForceLbf.toStringAsFixed(0)} lbf'
                            : '${(_pushForceN / 1000).toStringAsFixed(2)} kN',
                        color: colors.emerald,
                        icon: Icons.arrow_forward_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ForceCard(
                        direction: 'Retraction (Pull)',
                        forcePrimary: _isMetric
                            ? '${(_pullForceN / 1000).toStringAsFixed(2)} kN'
                            : '${_pullForceLbf.toStringAsFixed(0)} lbf',
                        forceSecondary: _isMetric
                            ? '${_pullForceLbf.toStringAsFixed(0)} lbf'
                            : '${(_pullForceN / 1000).toStringAsFixed(2)} kN',
                        color: colors.amber,
                        icon: Icons.arrow_back_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.cardBackground.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border.withAlpha(70)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            _fluidType == CylinderFluidType.pneumatic ? 'Air Demand (SCFM)' : 'Fluid Flow (GPM)',
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _fluidType == CylinderFluidType.pneumatic
                                ? '${_airScfm.toStringAsFixed(2)} SCFM'
                                : '${(_flowLpm * 0.264172).toStringAsFixed(2)} GPM',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 32, color: colors.border),
                      Column(
                        children: [
                          Text(
                            'Flow in L/min',
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_flowLpm.toStringAsFixed(1)} L/min',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForceCard extends StatelessWidget {
  final String direction;
  final String forcePrimary;
  final String forceSecondary;
  final Color color;
  final IconData icon;

  const _ForceCard({
    required this.direction,
    required this.forcePrimary,
    required this.forceSecondary,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                direction,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            forcePrimary,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            '($forceSecondary)',
            style: TextStyle(fontSize: 11, color: color.withAlpha(180)),
          ),
        ],
      ),
    );
  }
}
