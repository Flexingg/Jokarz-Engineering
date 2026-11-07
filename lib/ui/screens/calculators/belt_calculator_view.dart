import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

enum BeltFamily {
  timing('Synchronous Timing Belt', true),
  vBelt('V-Belt (Friction Drive)', false);

  final String label;
  final bool isToothed;
  const BeltFamily(this.label, this.isToothed);
}

class BeltProfilePreset {
  final String name;
  final double pitchMm; // 0 for V-belts
  final double defaultDia1;
  final double defaultDia2;
  const BeltProfilePreset(this.name, this.pitchMm, this.defaultDia1, this.defaultDia2);
}

const List<BeltProfilePreset> _timingPresets = [
  BeltProfilePreset('HTD 5M (5.0 mm pitch)', 5.0, 50.0, 100.0),
  BeltProfilePreset('HTD 8M (8.0 mm pitch)', 8.0, 80.0, 160.0),
  BeltProfilePreset('HTD 14M (14.0 mm pitch)', 14.0, 140.0, 280.0),
  BeltProfilePreset('GT2 (2.0 mm pitch)', 2.0, 20.0, 40.0),
  BeltProfilePreset('GT3 (3.0 mm pitch)', 3.0, 30.0, 60.0),
  BeltProfilePreset('T5 (5.0 mm metric)', 5.0, 50.0, 100.0),
  BeltProfilePreset('T10 (10.0 mm metric)', 10.0, 100.0, 200.0),
];

const List<BeltProfilePreset> _vBeltPresets = [
  BeltProfilePreset('Classical A / 4L (1/2" top width)', 0.0, 75.0, 150.0),
  BeltProfilePreset('Classical B / 5L (21/32" top width)', 0.0, 125.0, 250.0),
  BeltProfilePreset('Classical C (7/8" top width)', 0.0, 200.0, 400.0),
  BeltProfilePreset('Narrow 3V (3/8" top width)', 0.0, 80.0, 160.0),
  BeltProfilePreset('Narrow 5V (5/8" top width)', 0.0, 160.0, 320.0),
];

class BeltCalculatorView extends StatefulWidget {
  const BeltCalculatorView({super.key});

  @override
  State<BeltCalculatorView> createState() => _BeltCalculatorViewState();
}

class _BeltCalculatorViewState extends State<BeltCalculatorView> {
  BeltFamily _family = BeltFamily.timing;
  int _presetIdx = 1; // HTD 8M

  final _d1Ctrl = TextEditingController(text: '80.0'); // Driver Pitch Dia (mm)
  final _d2Ctrl = TextEditingController(text: '160.0'); // Driven Pitch Dia (mm)
  final _targetCenterCtrl = TextEditingController(text: '400.0'); // Desired Center (mm)
  final _rpmCtrl = TextEditingController(text: '1750.0');

  double _ratio = 2.0;
  double _outputRpm = 875.0;
  double _pitchLength = 0;
  int _beltTeeth = 0;
  double _adjustedCenter = 0;
  double _wrapAngleDeg = 180.0;

  @override
  void initState() {
    super.initState();
    _applyPreset(_timingPresets[_presetIdx]);
  }

  @override
  void dispose() {
    _d1Ctrl.dispose();
    _d2Ctrl.dispose();
    _targetCenterCtrl.dispose();
    _rpmCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(BeltProfilePreset p) {
    _d1Ctrl.text = p.defaultDia1.toStringAsFixed(1);
    _d2Ctrl.text = p.defaultDia2.toStringAsFixed(1);
    _recalculate();
  }

  void _recalculate() {
    final d1 = double.tryParse(_d1Ctrl.text) ?? 80.0;
    final d2 = double.tryParse(_d2Ctrl.text) ?? 160.0;
    final cTarget = double.tryParse(_targetCenterCtrl.text) ?? 400.0;
    final rpmIn = double.tryParse(_rpmCtrl.text) ?? 1750.0;

    if (d1 <= 0 || d2 <= 0 || cTarget <= 0) return;

    final D = math.max(d1, d2);
    final d = math.min(d1, d2);

    final ratio = d2 / d1;
    final rpmOut = ratio != 0 ? (rpmIn / ratio) : 0.0;

    // Belt length approx formula: L = 2C + pi/2 * (D+d) + (D-d)^2 / (4C)
    final approxLength = 2.0 * cTarget + (math.pi / 2.0) * (D + d) + (math.pow(D - d, 2) / (4.0 * cTarget));

    double finalLength = approxLength;
    int teeth = 0;

    final preset = _family == BeltFamily.timing ? _timingPresets[_presetIdx] : _vBeltPresets[_presetIdx];
    if (_family == BeltFamily.timing && preset.pitchMm > 0) {
      // Snap to nearest integer number of teeth
      teeth = (approxLength / preset.pitchMm).round();
      finalLength = teeth * preset.pitchMm;
    }

    // Solve exact center distance from belt length:
    // 4C^2 - 2C * [L - pi/2 * (D+d)] + (D-d)^2 = 0
    final b = finalLength - (math.pi / 2.0) * (D + d);
    final disc = math.pow(b, 2) - 4.0 * (math.pow(D - d, 2) / 2.0); // simplified quadratic
    double adjCenter = cTarget;
    if (disc >= 0) {
      adjCenter = (b + math.sqrt(disc)) / 4.0;
    }

    // Wrap angle on small pulley: 180 - 2 * arcsin((D-d) / (2C))
    final sinVal = ((D - d) / (2.0 * adjCenter)).clamp(-1.0, 1.0);
    final wrap = 180.0 - (2.0 * (math.asin(sinVal) * 180.0 / math.pi));

    setState(() {
      _ratio = ratio;
      _outputRpm = rpmOut;
      _pitchLength = finalLength;
      _beltTeeth = teeth;
      _adjustedCenter = adjCenter;
      _wrapAngleDeg = wrap;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final isToothed = _family == BeltFamily.timing;
    final wrapOk = _wrapAngleDeg >= 120.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belt Drive & Pulley Center Solver',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Timing belt pitch lengths, V-belts, wrap angle & ratios',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
              SegmentedButton<BeltFamily>(
                segments: const [
                  ButtonSegment(value: BeltFamily.timing, label: Text('Timing')),
                  ButtonSegment(value: BeltFamily.vBelt, label: Text('V-Belt')),
                ],
                selected: {_family},
                onSelectionChanged: (s) {
                  setState(() {
                    _family = s.first;
                    _presetIdx = 0;
                    _applyPreset(_family == BeltFamily.timing ? _timingPresets[0] : _vBeltPresets[0]);
                  });
                },
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Profile Selection
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Standard Profile Selection',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _presetIdx,
                  decoration: InputDecoration(
                    labelText: isToothed ? 'Timing Belt Pitch' : 'V-Belt Cross-Section',
                    isDense: true,
                    filled: true,
                    fillColor: colors.cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: List.generate(
                    isToothed ? _timingPresets.length : _vBeltPresets.length,
                    (i) {
                      final item = isToothed ? _timingPresets[i] : _vBeltPresets[i];
                      return DropdownMenuItem(value: i, child: Text(item.name, style: const TextStyle(fontSize: 13)));
                    },
                  ),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _presetIdx = val;
                      _applyPreset(isToothed ? _timingPresets[val] : _vBeltPresets[val]);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pulley & Center Parameters
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Pulleys & Center Distance (mm)',
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
                        controller: _d1Ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Driver Pulley Dia (D1)',
                          suffixText: 'mm',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => _recalculate(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _d2Ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Driven Pulley Dia (D2)',
                          suffixText: 'mm',
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
                        controller: _targetCenterCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Desired Center Distance',
                          suffixText: 'mm',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => _recalculate(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _rpmCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Input Shaft Speed',
                          suffixText: 'RPM',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => _recalculate(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Results Card & Schematic Canvas
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3. Center Distance & Wrap Diagnostics',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    ExpressiveBadge(
                      label: wrapOk ? 'Wrap: ${_wrapAngleDeg.toStringAsFixed(1)}° (OK)' : '⚠️ LOW WRAP (${_wrapAngleDeg.toStringAsFixed(1)}°)',
                      color: wrapOk ? colors.emerald : colors.coral,
                      fontSize: 10,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.cardBackground.withAlpha(120),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border.withAlpha(70)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pitch Belt Length', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              '${_pitchLength.toStringAsFixed(1)} mm',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.primary),
                            ),
                            if (isToothed && _beltTeeth > 0)
                              Text('$_beltTeeth teeth standard', style: TextStyle(fontSize: 11, color: colors.emerald)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.cardBackground.withAlpha(120),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border.withAlpha(70)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Actual Center Distance', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              '${_adjustedCenter.toStringAsFixed(1)} mm',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                            Text(
                              'Ratio ${_ratio.toStringAsFixed(2)}:1 • ${_outputRpm.toStringAsFixed(0)} RPM',
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.cardBackground.withAlpha(120),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border.withAlpha(70)),
                    ),
                    child: CustomPaint(
                      painter: _BeltSchematicPainter(
                        d1: double.tryParse(_d1Ctrl.text) ?? 80.0,
                        d2: double.tryParse(_d2Ctrl.text) ?? 160.0,
                        centerDistance: _adjustedCenter,
                        primaryColor: colors.primary,
                        accentColor: wrapOk ? colors.emerald : colors.coral,
                        wireColor: colors.textSecondary,
                      ),
                    ),
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

class _BeltSchematicPainter extends CustomPainter {
  final double d1;
  final double d2;
  final double centerDistance;
  final Color primaryColor;
  final Color accentColor;
  final Color wireColor;

  const _BeltSchematicPainter({
    required this.d1,
    required this.d2,
    required this.centerDistance,
    required this.primaryColor,
    required this.accentColor,
    required this.wireColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxDia = math.max(d1, d2);
    final span = centerDistance + maxDia;
    if (span <= 0) return;

    final scale = (size.width * 0.70) / span;

    final r1 = (d1 / 2.0) * scale;
    final r2 = (d2 / 2.0) * scale;
    final cScaled = centerDistance * scale;

    final cy = size.height / 2.0;
    final startX = (size.width - (cScaled + r1 + r2)) / 2.0 + r1;

    final p1 = Offset(startX, cy);
    final p2 = Offset(startX + cScaled, cy);

    final pulleyPaint = Paint()
      ..color = primaryColor.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = primaryColor.withAlpha(30)
      ..style = PaintingStyle.fill;

    // Draw pulleys
    canvas.drawCircle(p1, r1, fillPaint);
    canvas.drawCircle(p1, r1, pulleyPaint);
    canvas.drawCircle(p2, r2, fillPaint);
    canvas.drawCircle(p2, r2, pulleyPaint);

    // Center hubs
    canvas.drawCircle(p1, 3, Paint()..color = wireColor);
    canvas.drawCircle(p2, 3, Paint()..color = wireColor);

    // Tangent belt lines
    final beltPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final angle = math.asin(((r2 - r1).abs() / cScaled).clamp(-1.0, 1.0));
    final perpAngle = math.pi / 2.0 - angle;

    final t1Top = Offset(p1.dx - r1 * math.sin(perpAngle), p1.dy - r1 * math.cos(perpAngle));
    final t2Top = Offset(p2.dx - r2 * math.sin(perpAngle), p2.dy - r2 * math.cos(perpAngle));
    final t1Bot = Offset(p1.dx - r1 * math.sin(perpAngle), p1.dy + r1 * math.cos(perpAngle));
    final t2Bot = Offset(p2.dx - r2 * math.sin(perpAngle), p2.dy + r2 * math.cos(perpAngle));

    canvas.drawLine(t1Top, t2Top, beltPaint);
    canvas.drawLine(t1Bot, t2Bot, beltPaint);

    // Centerline dimension
    final dimPaint = Paint()
      ..color = wireColor.withAlpha(120)
      ..strokeWidth = 1.0;
    canvas.drawLine(p1, p2, dimPaint);
  }

  @override
  bool shouldRepaint(covariant _BeltSchematicPainter oldDelegate) {
    return oldDelegate.d1 != d1 ||
        oldDelegate.d2 != d2 ||
        oldDelegate.centerDistance != centerDistance ||
        oldDelegate.accentColor != accentColor;
  }
}
