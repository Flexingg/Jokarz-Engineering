import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

enum GearboxType {
  helicalInline('Helical Inline (95% eff)', 0.95),
  planetary('Planetary Inline (97% eff)', 0.97),
  rightAngleHelical('Right-Angle Bevel/Helical (92% eff)', 0.92),
  wormSingle('Worm Gear (72% eff)', 0.72),
  directDrive('Direct Drive (100% eff)', 1.00);

  final String label;
  final double efficiency;
  const GearboxType(this.label, this.efficiency);
}

class MotorDrivetrainView extends StatefulWidget {
  const MotorDrivetrainView({super.key});

  @override
  State<MotorDrivetrainView> createState() => _MotorDrivetrainViewState();
}

class _MotorDrivetrainViewState extends State<MotorDrivetrainView> {
  bool _isHp = true; // HP vs kW
  GearboxType _gearbox = GearboxType.helicalInline;

  final _powerCtrl = TextEditingController(text: '5.0'); // 5 HP
  final _baseRpmCtrl = TextEditingController(text: '1750'); // 4-pole 60Hz
  final _ratioCtrl = TextEditingController(text: '20.0'); // 20:1
  double _vfdHz = 60.0; // VFD output frequency (Hz)
  final double _baseHz = 60.0;

  double _motorBaseTorqueFtLbs = 0;
  double _motorBaseTorqueNm = 0;
  double _outputRpm = 0;
  double _outputTorqueFtLbs = 0;
  double _outputTorqueNm = 0;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _powerCtrl.dispose();
    _baseRpmCtrl.dispose();
    _ratioCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final power = double.tryParse(_powerCtrl.text) ?? 5.0;
    final baseRpm = double.tryParse(_baseRpmCtrl.text) ?? 1750.0;
    final ratio = double.tryParse(_ratioCtrl.text) ?? 20.0;

    if (power <= 0 || baseRpm <= 0 || ratio <= 0) return;

    final double hp = _isHp ? power : power * 1.34102;
    final double kw = _isHp ? power * 0.7457 : power;

    // Motor Base Torque: T (ft-lbs) = (HP * 5252) / RPM
    final baseTorqueFtLbs = (hp * 5252.0) / baseRpm;
    // Motor Base Torque: T (N-m) = (kW * 9550) / RPM
    final baseTorqueNm = (kw * 9550.0) / baseRpm;

    // VFD operating point
    // Below base Hz: Constant torque (factor = 1.0)
    // Above base Hz: Field weakening (factor = baseHz / currentHz)
    double torqueFactor = 1.0;
    if (_vfdHz > _baseHz) {
      torqueFactor = _baseHz / _vfdHz;
    }

    final motorOperatingRpm = baseRpm * (_vfdHz / _baseHz);
    final outRpm = motorOperatingRpm / ratio;

    final outTorqueFtLbs = baseTorqueFtLbs * ratio * _gearbox.efficiency * torqueFactor;
    final outTorqueNm = baseTorqueNm * ratio * _gearbox.efficiency * torqueFactor;

    setState(() {
      _motorBaseTorqueFtLbs = baseTorqueFtLbs;
      _motorBaseTorqueNm = baseTorqueNm;
      _outputRpm = outRpm;
      _outputTorqueFtLbs = outTorqueFtLbs;
      _outputTorqueNm = outTorqueNm;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final powerUnit = _isHp ? 'HP' : 'kW';
    final isLowHz = _vfdHz < 20.0;
    final isFieldWeakening = _vfdHz > 60.0;

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
                    'Motor, Gearbox & VFD Sizing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Torque, reduction ratio, mechanical efficiency & VFD speed curve',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('HP (US)')),
                  ButtonSegment(value: false, label: Text('kW (Metric)')),
                ],
                selected: {_isHp},
                onSelectionChanged: (s) {
                  setState(() {
                    _isHp = s.first;
                    final p = double.tryParse(_powerCtrl.text) ?? 5.0;
                    _powerCtrl.text = (_isHp ? p * 1.341 : p * 0.746).toStringAsFixed(1);
                    _recalculate();
                  });
                },
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Motor & Gearbox Inputs
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Motor Plate & Gearbox Specification',
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
                        controller: _powerCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Motor Rating',
                          suffixText: powerUnit,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => _recalculate(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _baseRpmCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Base Speed (60Hz)',
                          suffixText: 'RPM',
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
                      flex: 2,
                      child: DropdownButtonFormField<GearboxType>(
                        value: _gearbox,
                        decoration: InputDecoration(
                          labelText: 'Gearbox Reducer Style',
                          isDense: true,
                          filled: true,
                          fillColor: colors.cardBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: GearboxType.values.map((g) {
                          return DropdownMenuItem(value: g, child: Text(g.label, style: const TextStyle(fontSize: 12)));
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            _gearbox = val;
                            _recalculate();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _ratioCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Ratio (:1)',
                          suffixText: ':1',
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

          // VFD Frequency Slider Card
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '2. VFD Inverter Speed Control',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    if (isLowHz)
                      ExpressiveBadge(
                        label: '⚠️ LOW SPEED: FAN OVERHEAT RISK',
                        color: colors.coral,
                        fontSize: 10,
                      )
                    else if (isFieldWeakening)
                      ExpressiveBadge(
                        label: 'FIELD WEAKENING (TORQUE DROPOFF)',
                        color: colors.amber,
                        fontSize: 10,
                      )
                    else
                      ExpressiveBadge(
                        label: 'Constant Torque Zone',
                        color: colors.emerald,
                        fontSize: 10,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${_vfdHz.toStringAsFixed(1)} Hz',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${((_vfdHz / _baseHz) * 100).toStringAsFixed(0)}% base speed)',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _vfdHz = 60.0;
                          _recalculate();
                        });
                      },
                      child: const Text('Reset to 60 Hz', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                Slider(
                  value: _vfdHz,
                  min: 10.0,
                  max: 90.0,
                  divisions: 80,
                  activeColor: isLowHz ? colors.coral : (isFieldWeakening ? colors.amber : colors.primary),
                  onChanged: (val) {
                    setState(() {
                      _vfdHz = val;
                      _recalculate();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Output Performance Metrics
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3. Final Shaft Output Delivery',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.emerald.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.emerald.withAlpha(90)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Output Shaft Torque', style: TextStyle(fontSize: 11, color: colors.emerald)),
                            const SizedBox(height: 4),
                            Text(
                              '${_outputTorqueFtLbs.toStringAsFixed(0)} ft·lbs',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.emerald),
                            ),
                            Text(
                              '${_outputTorqueNm.toStringAsFixed(0)} N·m (${(_outputTorqueFtLbs * 12).toStringAsFixed(0)} in·lbs)',
                              style: TextStyle(fontSize: 11, color: colors.emerald.withAlpha(180)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.primary.withAlpha(90)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Final Output Speed', style: TextStyle(fontSize: 11, color: colors.primary)),
                            const SizedBox(height: 4),
                            Text(
                              '${_outputRpm.toStringAsFixed(1)} RPM',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.primary),
                            ),
                            Text(
                              'Motor: ${_isHp ? "${_motorBaseTorqueFtLbs.toStringAsFixed(1)} ft·lbs" : "${_motorBaseTorqueNm.toStringAsFixed(1)} N·m"} raw',
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
