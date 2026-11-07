import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

enum SealGlandType {
  staticAxial('Static Axial (Face Seal)', 0.24, 0.75, 1.25),
  staticRadial('Static Radial (Plug/Bore)', 0.18, 0.72, 1.30),
  dynamicRecip('Dynamic Reciprocating', 0.14, 0.68, 1.35);

  final String label;
  final double targetSqueeze; // target fraction
  final double targetFill;    // target fraction
  final double widthFactor;   // groove width as multiple of cross section
  const SealGlandType(this.label, this.targetSqueeze, this.targetFill, this.widthFactor);
}

class AS568Preset {
  final String series;
  final double csInch;
  final double csMm;
  const AS568Preset(this.series, this.csInch, this.csMm);
}

const List<AS568Preset> _as568Presets = [
  AS568Preset('000 Series (0.070" / 1.78 mm)', 0.070, 1.78),
  AS568Preset('100 Series (0.103" / 2.62 mm)', 0.103, 2.62),
  AS568Preset('200 Series (0.139" / 3.53 mm)', 0.139, 3.53),
  AS568Preset('300 Series (0.210" / 5.33 mm)', 0.210, 5.33),
  AS568Preset('400 Series (0.275" / 6.99 mm)', 0.275, 6.99),
];

class ORingCalculatorView extends StatefulWidget {
  const ORingCalculatorView({super.key});

  @override
  State<ORingCalculatorView> createState() => _ORingCalculatorViewState();
}

class _ORingCalculatorViewState extends State<ORingCalculatorView> {
  bool _isMetric = true;
  SealGlandType _glandType = SealGlandType.staticRadial;
  int _selectedPresetIdx = 1; // 100 series (2.62 mm)

  final _csCtrl = TextEditingController(text: '2.62');
  final _idCtrl = TextEditingController(text: '25.0');
  final _pressureCtrl = TextEditingController(text: '70'); // bar or psi
  final _grooveDepthCtrl = TextEditingController(text: '2.15');
  final _grooveWidthCtrl = TextEditingController(text: '3.40');
  final _gapCtrl = TextEditingController(text: '0.10');

  double _squeezePercent = 0;
  double _glandFillPercent = 0;
  bool _backupRingRecommended = false;

  @override
  void initState() {
    super.initState();
    _applyPreset(_as568Presets[_selectedPresetIdx]);
  }

  @override
  void dispose() {
    _csCtrl.dispose();
    _idCtrl.dispose();
    _pressureCtrl.dispose();
    _grooveDepthCtrl.dispose();
    _grooveWidthCtrl.dispose();
    _gapCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(AS568Preset p) {
    final cs = _isMetric ? p.csMm : p.csInch;
    _csCtrl.text = cs.toStringAsFixed(_isMetric ? 2 : 3);

    // Recommended default groove geometry based on gland type
    final depth = cs * (1.0 - _glandType.targetSqueeze);
    final width = cs * _glandType.widthFactor;
    final gap = _isMetric ? 0.10 : 0.004;

    _grooveDepthCtrl.text = depth.toStringAsFixed(_isMetric ? 2 : 3);
    _grooveWidthCtrl.text = width.toStringAsFixed(_isMetric ? 2 : 3);
    _gapCtrl.text = gap.toStringAsFixed(_isMetric ? 2 : 3);

    _recalculate();
  }

  void _recalculate() {
    final cs = double.tryParse(_csCtrl.text) ?? 2.62;
    final depth = double.tryParse(_grooveDepthCtrl.text) ?? 2.15;
    final width = double.tryParse(_grooveWidthCtrl.text) ?? 3.40;
    final pressure = double.tryParse(_pressureCtrl.text) ?? 0;

    if (cs <= 0 || depth <= 0 || width <= 0) return;

    final squeeze = ((cs - depth) / cs) * 100.0;
    final oRingArea = (math.pi / 4.0) * (cs * cs);
    final glandArea = depth * width;
    final fill = (oRingArea / glandArea) * 100.0;

    // Standard 70A durometer O-ring backup ring threshold: > 1500 psi (100 bar)
    final pressureInBar = _isMetric ? pressure : pressure * 0.0689476;
    final backup = pressureInBar > 100.0;

    setState(() {
      _squeezePercent = squeeze;
      _glandFillPercent = fill;
      _backupRingRecommended = backup;
    });
  }

  void _toggleUnits(bool metric) {
    if (_isMetric == metric) return;
    setState(() {
      _isMetric = metric;
      final mult = metric ? 25.4 : 1.0 / 25.4;
      final pressMult = metric ? (1.0 / 14.5038) : 14.5038;

      final cs = (double.tryParse(_csCtrl.text) ?? 2.62) * mult;
      final id = (double.tryParse(_idCtrl.text) ?? 25.0) * mult;
      final depth = (double.tryParse(_grooveDepthCtrl.text) ?? 2.15) * mult;
      final width = (double.tryParse(_grooveWidthCtrl.text) ?? 3.40) * mult;
      final gap = (double.tryParse(_gapCtrl.text) ?? 0.10) * mult;
      final press = (double.tryParse(_pressureCtrl.text) ?? 70) * pressMult;

      _csCtrl.text = cs.toStringAsFixed(metric ? 2 : 3);
      _idCtrl.text = id.toStringAsFixed(metric ? 2 : 3);
      _grooveDepthCtrl.text = depth.toStringAsFixed(metric ? 2 : 3);
      _grooveWidthCtrl.text = width.toStringAsFixed(metric ? 2 : 3);
      _gapCtrl.text = gap.toStringAsFixed(metric ? 2 : 3);
      _pressureCtrl.text = press.toStringAsFixed(0);
      _recalculate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final unit = _isMetric ? 'mm' : 'in';
    final pressUnit = _isMetric ? 'bar' : 'psi';

    // Status evaluation
    final bool squeezeOk = _squeezePercent >= 10.0 && _squeezePercent <= 32.0;
    final bool fillOk = _glandFillPercent >= 60.0 && _glandFillPercent <= 88.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Unit Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'O-Ring & Gland Solver',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AS568 & Metric groove sizing, squeeze % & gland fill',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Metric (mm)')),
                  ButtonSegment(value: false, label: Text('Imperial (in)')),
                ],
                selected: {_isMetric},
                onSelectionChanged: (s) => _toggleUnits(s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Presets & Gland Type Selection
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Gland Configuration & Standard O-Ring',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<SealGlandType>(
                  value: _glandType,
                  decoration: InputDecoration(
                    labelText: 'Application Gland Type',
                    isDense: true,
                    filled: true,
                    fillColor: colors.cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: SealGlandType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t.label, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _glandType = val;
                      _applyPreset(_as568Presets[_selectedPresetIdx]);
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedPresetIdx,
                  decoration: InputDecoration(
                    labelText: 'AS568 Standard Cross-Section',
                    isDense: true,
                    filled: true,
                    fillColor: colors.cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: List.generate(_as568Presets.length, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text(_as568Presets[i].series, style: const TextStyle(fontSize: 13)),
                    );
                  }),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedPresetIdx = val;
                      _applyPreset(_as568Presets[val]);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dimensions & Inputs
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Seal & Groove Dimensions ($unit)',
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
                        controller: _csCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'O-Ring Cross-Section (W)',
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
                        controller: _idCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'O-Ring Inside Dia (ID)',
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
                        controller: _grooveDepthCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Groove Depth (L)',
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
                        controller: _grooveWidthCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Groove Width (G)',
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
                        controller: _gapCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Clearance Gap (E)',
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
                          labelText: 'Max Operating Pressure',
                          suffixText: pressUnit,
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

          // Diagnostic Metrics & Visual Canvas
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3. Compression & Fill Diagnostics',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    if (_backupRingRecommended)
                      ExpressiveBadge(
                        label: '⚠️ BACKUP RING REQUIRED',
                        color: colors.coral,
                        fontSize: 10,
                      )
                    else
                      ExpressiveBadge(
                        label: 'Standard Single O-Ring',
                        color: colors.emerald,
                        fontSize: 10,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Squeeze Ratio',
                        value: '${_squeezePercent.toStringAsFixed(1)}%',
                        statusText: squeezeOk ? 'Target (15–30%)' : (_squeezePercent < 15 ? 'Too Loose (Leak Risk)' : 'Over-compressed'),
                        statusColor: squeezeOk ? colors.emerald : colors.coral,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: 'Gland Fill',
                        value: '${_glandFillPercent.toStringAsFixed(1)}%',
                        statusText: fillOk ? 'Optimal (65–85%)' : (_glandFillPercent > 90 ? 'Overflow / Jam' : 'Room to expand'),
                        statusColor: fillOk ? colors.emerald : (_glandFillPercent > 90 ? colors.coral : colors.amber),
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
                      painter: _GlandCrossSectionPainter(
                        squeezeRatio: _squeezePercent / 100.0,
                        fillRatio: _glandFillPercent / 100.0,
                        primaryColor: colors.primary,
                        accentColor: squeezeOk ? colors.emerald : colors.coral,
                        wireColor: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Schematic cross-section: Groove cavity with compressed elastomeric seal',
                    style: TextStyle(fontSize: 10, color: colors.textSecondary),
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

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String statusText;
  final Color statusColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.statusText,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
          ),
          const SizedBox(height: 2),
          Text(statusText, style: TextStyle(fontSize: 10, color: statusColor)),
        ],
      ),
    );
  }
}

class _GlandCrossSectionPainter extends CustomPainter {
  final double squeezeRatio;
  final double fillRatio;
  final Color primaryColor;
  final Color accentColor;
  final Color wireColor;

  const _GlandCrossSectionPainter({
    required this.squeezeRatio,
    required this.fillRatio,
    required this.primaryColor,
    required this.accentColor,
    required this.wireColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;

    final grooveW = size.width * 0.40;
    final grooveH = size.height * 0.50;

    // Draw metal gland boundary
    final metalPaint = Paint()
      ..color = wireColor.withAlpha(120)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final hatchPaint = Paint()
      ..color = wireColor.withAlpha(35)
      ..style = PaintingStyle.fill;

    final grooveRect = Rect.fromCenter(center: Offset(cx, cy), width: grooveW, height: grooveH);
    canvas.drawRect(grooveRect, hatchPaint);
    canvas.drawRect(grooveRect, metalPaint);

    // Draw top closing plate / rod surface
    final platePaint = Paint()
      ..color = primaryColor.withAlpha(160)
      ..strokeWidth = 3.0;
    canvas.drawLine(
      Offset(cx - grooveW * 0.8, grooveRect.top),
      Offset(cx + grooveW * 0.8, grooveRect.top),
      platePaint,
    );

    // Draw compressed O-ring (represented as an ellipse squished vertically and expanded horizontally)
    final compression = squeezeRatio.clamp(0.05, 0.45);
    final oRingH = (grooveH * (1.0 - compression * 0.5)).clamp(10.0, grooveH * 0.98);
    final oRingW = (grooveW * 0.65 * (1.0 + compression * 0.4)).clamp(15.0, grooveW * 0.95);

    final oRingPaint = Paint()
      ..color = accentColor.withAlpha(190)
      ..style = PaintingStyle.fill;

    final oRingBorder = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final oRingRect = Rect.fromCenter(center: Offset(cx, cy), width: oRingW, height: oRingH);
    canvas.drawOval(oRingRect, oRingPaint);
    canvas.drawOval(oRingRect, oRingBorder);
  }

  @override
  bool shouldRepaint(covariant _GlandCrossSectionPainter oldDelegate) {
    return oldDelegate.squeezeRatio != squeezeRatio ||
        oldDelegate.fillRatio != fillRatio ||
        oldDelegate.accentColor != accentColor;
  }
}
