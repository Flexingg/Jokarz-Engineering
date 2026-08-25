import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/tools_provider.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

class ElectronicsView extends ConsumerStatefulWidget {
  const ElectronicsView({super.key});

  @override
  ConsumerState<ElectronicsView> createState() => _ElectronicsViewState();
}

class _ElectronicsViewState extends ConsumerState<ElectronicsView> {
  // Ohm's Law state
  final TextEditingController _vCtrl = TextEditingController(text: '12.0');
  final TextEditingController _iCtrl = TextEditingController(text: '0.5');
  final TextEditingController _rCtrl = TextEditingController(text: '24.0');
  final TextEditingController _pCtrl = TextEditingController(text: '6.0');

  // LED Resistor state
  final TextEditingController _ledVsCtrl = TextEditingController(text: '5.0');
  final TextEditingController _ledVfCtrl = TextEditingController(text: '2.1'); // Red/Green LED
  final TextEditingController _ledIfCtrl = TextEditingController(text: '20.0'); // 20 mA

  // Wire Gauge state
  int _selectedAwg = 18;
  double _wireCurrent = 5.0;
  double _wireLengthMeters = 3.0;

  static const List<Map<String, dynamic>> _resistorColors = [
    {'name': 'Black', 'val': 0, 'color': Color(0xFF000000), 'mult': 1},
    {'name': 'Brown', 'val': 1, 'color': Color(0xFF8B4513), 'mult': 10},
    {'name': 'Red', 'val': 2, 'color': Color(0xFFFF0000), 'mult': 100},
    {'name': 'Orange', 'val': 3, 'color': Color(0xFFFF7F00), 'mult': 1000},
    {'name': 'Yellow', 'val': 4, 'color': Color(0xFFFFFF00), 'mult': 10000},
    {'name': 'Green', 'val': 5, 'color': Color(0xFF00FF00), 'mult': 100000},
    {'name': 'Blue', 'val': 6, 'color': Color(0xFF0000FF), 'mult': 1000000},
    {'name': 'Violet', 'val': 7, 'color': Color(0xFF8A2BE2), 'mult': 10000000},
    {'name': 'Grey', 'val': 8, 'color': Color(0xFF808080), 'mult': 100000000},
    {'name': 'White', 'val': 9, 'color': Color(0xFFFFFFFF), 'mult': 1000000000},
  ];

  static const Map<int, double> _awgResistancePerMeter = {
    10: 0.003277,
    12: 0.005211,
    14: 0.008286,
    16: 0.01317,
    18: 0.02095,
    20: 0.03331,
    22: 0.05296,
    24: 0.08422,
    26: 0.1339,
    28: 0.2129,
    30: 0.3386,
  };

  void _calcOhmFromVandI() {
    final v = double.tryParse(_vCtrl.text) ?? 0.0;
    final i = double.tryParse(_iCtrl.text) ?? 0.0;
    if (i > 0) {
      final r = v / i;
      final p = v * i;
      _rCtrl.text = r.toStringAsFixed(2);
      _pCtrl.text = p.toStringAsFixed(2);
      setState(() {});
    }
  }

  void _calcOhmFromVandR() {
    final v = double.tryParse(_vCtrl.text) ?? 0.0;
    final r = double.tryParse(_rCtrl.text) ?? 0.0;
    if (r > 0) {
      final i = v / r;
      final p = (v * v) / r;
      _iCtrl.text = i.toStringAsFixed(3);
      _pCtrl.text = p.toStringAsFixed(2);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final resistor = ref.watch(resistorProvider);
    final resNotifier = ref.read(resistorProvider.notifier);

    // LED calculation
    final vs = double.tryParse(_ledVsCtrl.text) ?? 5.0;
    final vf = double.tryParse(_ledVfCtrl.text) ?? 2.0;
    final ifMa = double.tryParse(_ledIfCtrl.text) ?? 20.0;
    final ifAmps = ifMa / 1000.0;
    final ledResistorOhms = ifAmps > 0 && vs > vf ? (vs - vf) / ifAmps : 0.0;
    final ledResistorPowerW = ifAmps * (vs - vf);

    // Wire drop calculation
    final ohmsPerM = _awgResistancePerMeter[_selectedAwg] ?? 0.02095;
    final totalWireResistance = ohmsPerM * _wireLengthMeters * 2; // out & return
    final wireVoltageDrop = _wireCurrent * totalWireResistance;
    final wirePowerLoss = _wireCurrent * _wireCurrent * totalWireResistance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Resistor Color Code Section
          const Text(
            'Resistor Color Band Decoder',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ExpressiveCard(
            isGlowing: true,
            glowColor: AppTheme.accentEmerald,
            child: Column(
              children: [
                // Resistance Output Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CALCULATED RESISTANCE', style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: Colors.grey)),
                        Text(
                          resistor.formattedResistance,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.accentEmerald),
                        ),
                      ],
                    ),
                    ExpressiveBadge(
                      label: '±${resistor.tolerancePercent}% Tolerance',
                      color: AppTheme.accentAmber,
                      fontSize: 12,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Visual Resistor Body Graphic
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2B48C), // Ceramic resistor tan
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black26, width: 2),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 24),
                      // Band 1
                      _buildVisualBand(_resistorColors[resistor.band1]['color'] as Color),
                      const Spacer(),
                      // Band 2
                      _buildVisualBand(_resistorColors[resistor.band2]['color'] as Color),
                      const Spacer(),
                      if (resistor.mode == ResistorBandMode.fiveBand) ...[
                        _buildVisualBand(_resistorColors[resistor.band3]['color'] as Color),
                        const Spacer(),
                      ],
                      // Multiplier Band
                      _buildVisualBand(_resistorColors[resistor.multiplier]['color'] as Color),
                      const Spacer(),
                      // Tolerance Gold/Silver
                      _buildVisualBand(resistor.tolerancePercent == 5.0 ? const Color(0xFFFFD700) : const Color(0xFFC0C0C0)),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Band Selectors
                Row(
                  children: [
                    Expanded(
                      child: _buildBandPicker(
                        '1st Band',
                        resistor.band1,
                        (v) => resNotifier.setBand1(v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBandPicker(
                        '2nd Band',
                        resistor.band2,
                        (v) => resNotifier.setBand2(v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBandPicker(
                        'Multiplier',
                        resistor.multiplier,
                        (v) => resNotifier.setMultiplier(v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 2. Ohm's Law & Power
          const Text(
            "Ohm's Law & DC Power Calculator",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ExpressiveCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _vCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Voltage (V)', suffixText: 'V'),
                        onChanged: (_) => _calcOhmFromVandI(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _iCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Current (I)', suffixText: 'A'),
                        onChanged: (_) => _calcOhmFromVandI(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Resistance (R)', suffixText: 'Ω'),
                        onChanged: (_) => _calcOhmFromVandR(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Power (P = V×I)', suffixText: 'Watts'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 3. LED Series Resistor
          const Text(
            'LED Current Limiting Resistor',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ledVsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Supply Voltage (Vs)', suffixText: 'V'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _ledVfCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'LED Forward (Vf)', suffixText: 'V'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _ledIfCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Target Current (If)', suffixText: 'mA'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('REQUIRED RESISTOR', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          '${ledResistorOhms.toStringAsFixed(1)} Ω',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryCyan),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('DISSIPATED POWER', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          '${(ledResistorPowerW * 1000).toStringAsFixed(1)} mW (${ledResistorPowerW > 0.25 ? "Use 1/2W" : "Use 1/4W"})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentAmber),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 4. AWG Wire Gauge Voltage Drop
          const Text(
            'AWG Wire Gauge & Voltage Drop Calculator',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedAwg,
                        decoration: const InputDecoration(labelText: 'Wire Size (AWG)'),
                        items: _awgResistancePerMeter.keys
                            .map((awg) => DropdownMenuItem(value: awg, child: Text('$awg AWG')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedAwg = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Current Load (Amps)', suffixText: 'A'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) {
                          setState(() {
                            _wireCurrent = double.tryParse(v) ?? 5.0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Run Length (Meters)', suffixText: 'm'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) {
                          setState(() {
                            _wireLengthMeters = double.tryParse(v) ?? 3.0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildParamTile('Loop Resistance', '${totalWireResistance.toStringAsFixed(3)} Ω', AppTheme.primaryCyan),
                    _buildParamTile('Voltage Drop', '${wireVoltageDrop.toStringAsFixed(2)} V', AppTheme.accentCoral),
                    _buildParamTile('Cable Power Loss', '${wirePowerLoss.toStringAsFixed(2)} W', AppTheme.accentAmber),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualBand(Color color) {
    return Container(
      width: 14,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black26, width: 0.5),
      ),
    );
  }

  Widget _buildBandPicker(String title, int selectedVal, ValueChanged<int> onChanged) {
    return DropdownButtonFormField<int>(
      value: selectedVal,
      decoration: InputDecoration(labelText: title, isDense: true),
      items: _resistorColors
          .map(
            (c) => DropdownMenuItem<int>(
              value: c['val'] as int,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: c['color'] as Color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(c['name'] as String, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildParamTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
