import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

class TorqueCalculatorView extends StatefulWidget {
  const TorqueCalculatorView({super.key});

  @override
  State<TorqueCalculatorView> createState() => _TorqueCalculatorViewState();
}

class _TorqueCalculatorViewState extends State<TorqueCalculatorView> {
  bool _isMetric = true;
  final _diaCtrl = TextEditingController(text: '12'); // mm or inches
  final _pitchCtrl = TextEditingController(text: '1.75'); // mm pitch or TPI
  final _proofStressCtrl = TextEditingController(text: '600'); // MPa or psi
  final _kFactorCtrl = TextEditingController(text: '0.20');
  double _clampPercent = 75.0; // 75% of proof load

  String _selectedGradePreset = 'Metric 8.8 (600 MPa)';
  String _selectedLubePreset = 'Dry / Zinc Plated (K = 0.20)';

  double _tensileArea = 0; // mm² or in²
  double _clampForce = 0; // kN or lbf
  double _torqueNm = 0;
  double _torqueFtLbs = 0;
  double _torqueInLbs = 0;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _diaCtrl.dispose();
    _pitchCtrl.dispose();
    _proofStressCtrl.dispose();
    _kFactorCtrl.dispose();
    super.dispose();
  }

  void _onGradePreset(String preset) {
    setState(() {
      _selectedGradePreset = preset;
      if (preset.contains('Metric 8.8')) {
        _isMetric = true;
        _proofStressCtrl.text = '600';
      } else if (preset.contains('Metric 10.9')) {
        _isMetric = true;
        _proofStressCtrl.text = '830';
      } else if (preset.contains('Metric 12.9')) {
        _isMetric = true;
        _proofStressCtrl.text = '970';
      } else if (preset.contains('SAE Grade 2')) {
        _isMetric = false;
        _proofStressCtrl.text = '55000';
      } else if (preset.contains('SAE Grade 5')) {
        _isMetric = false;
        _proofStressCtrl.text = '85000';
      } else if (preset.contains('SAE Grade 8')) {
        _isMetric = false;
        _proofStressCtrl.text = '120000';
      } else if (preset.contains('Stainless 304/316')) {
        if (_isMetric) {
          _proofStressCtrl.text = '450';
        } else {
          _proofStressCtrl.text = '65000';
        }
      }
      _recalculate();
    });
  }

  void _onLubePreset(String preset) {
    setState(() {
      _selectedLubePreset = preset;
      if (preset.contains('Dry / Zinc')) {
        _kFactorCtrl.text = '0.20';
      } else if (preset.contains('Lightly Oiled')) {
        _kFactorCtrl.text = '0.15';
      } else if (preset.contains('Anti-Seize / Moly')) {
        _kFactorCtrl.text = '0.12';
      } else if (preset.contains('PTFE / Loctite')) {
        _kFactorCtrl.text = '0.10';
      }
      _recalculate();
    });
  }

  void _recalculate() {
    final d = double.tryParse(_diaCtrl.text.trim()) ?? 0;
    final p = double.tryParse(_pitchCtrl.text.trim()) ?? 0;
    final proof = double.tryParse(_proofStressCtrl.text.trim()) ?? 0;
    final k = double.tryParse(_kFactorCtrl.text.trim()) ?? 0.20;

    if (d <= 0 || proof <= 0) return;

    setState(() {
      if (_isMetric) {
        // Metric: d (mm), pitch (mm), proof (MPa = N/mm²)
        // Tensile Stress Area At = 0.7854 * (d - 0.9382 * p)²
        _tensileArea = 0.7854 * math.pow(d - (0.9382 * (p > 0 ? p : 1.5)), 2);
        final proofForceN = _tensileArea * proof;
        final clampForceN = proofForceN * (_clampPercent / 100.0);
        _clampForce = clampForceN / 1000.0; // in kN

        // Torque T = K * D * F (N-m)
        _torqueNm = (k * (d / 1000.0) * clampForceN);
        _torqueFtLbs = _torqueNm * 0.737562;
        _torqueInLbs = _torqueFtLbs * 12.0;
      } else {
        // Imperial: d (inches), pitch = TPI, proof (psi)
        // Tensile Stress Area At = 0.7854 * (d - 0.9743 / n)²
        final tpi = p > 0 ? p : 13;
        _tensileArea = 0.7854 * math.pow(d - (0.9743 / tpi), 2);
        final proofForceLbf = _tensileArea * proof;
        _clampForce = proofForceLbf * (_clampPercent / 100.0); // in lbf

        // Torque T = K * D * F (in-lbs)
        _torqueInLbs = k * d * _clampForce;
        _torqueFtLbs = _torqueInLbs / 12.0;
        _torqueNm = _torqueFtLbs * 1.355818;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ExpressiveCard(
            child: Row(
              children: [
                const Icon(Icons.fitness_center_rounded, color: AppTheme.accentEmerald, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bolt Torque & Clamp Load Solver',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Calculates required torque T = K·D·F, tensile stress area, and clamping pre-load.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Standard Toggle (Metric vs Imperial)
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Metric (ISO mm / MPa)')),
              ButtonSegment(value: false, label: Text('Imperial (SAE in / psi)')),
            ],
            selected: {_isMetric},
            onSelectionChanged: (val) {
              setState(() {
                _isMetric = val.first;
                if (_isMetric) {
                  _diaCtrl.text = '12';
                  _pitchCtrl.text = '1.75';
                  _proofStressCtrl.text = '600';
                  _selectedGradePreset = 'Metric 8.8 (600 MPa)';
                } else {
                  _diaCtrl.text = '0.500';
                  _pitchCtrl.text = '13';
                  _proofStressCtrl.text = '85000';
                  _selectedGradePreset = 'SAE Grade 5 (85,000 psi)';
                }
                _recalculate();
              });
            },
          ),
          const SizedBox(height: 16),

          // Fastener Preset Dropdown
          DropdownButtonFormField<String>(
            value: _selectedGradePreset,
            decoration: const InputDecoration(
              labelText: 'Fastener Material / Grade Preset',
              prefixIcon: Icon(Icons.shield_outlined),
            ),
            items: [
              if (_isMetric) ...[
                const DropdownMenuItem(value: 'Metric 8.8 (600 MPa)', child: Text('Metric Class 8.8 (Standard Steel - 600 MPa)')),
                const DropdownMenuItem(value: 'Metric 10.9 (830 MPa)', child: Text('Metric Class 10.9 (High Tensile - 830 MPa)')),
                const DropdownMenuItem(value: 'Metric 12.9 (970 MPa)', child: Text('Metric Class 12.9 (Alloy Socket Cap - 970 MPa)')),
                const DropdownMenuItem(value: 'Stainless 304/316 (450 MPa)', child: Text('Stainless A2-70 / 304/316 (450 MPa)')),
              ] else ...[
                const DropdownMenuItem(value: 'SAE Grade 2 (55,000 psi)', child: Text('SAE Grade 2 (Low Carbon - 55,000 psi)')),
                const DropdownMenuItem(value: 'SAE Grade 5 (85,000 psi)', child: Text('SAE Grade 5 (Medium Carbon - 85,000 psi)')),
                const DropdownMenuItem(value: 'SAE Grade 8 (120,000 psi)', child: Text('SAE Grade 8 (Alloy Steel - 120,000 psi)')),
                const DropdownMenuItem(value: 'Stainless 304/316 (65,000 psi)', child: Text('Stainless 304/316 (18-8) (65,000 psi)')),
              ],
            ],
            onChanged: (val) {
              if (val != null) _onGradePreset(val);
            },
          ),
          const SizedBox(height: 12),

          // Lubrication / Friction Preset
          DropdownButtonFormField<String>(
            value: _selectedLubePreset,
            decoration: const InputDecoration(
              labelText: 'Surface & Lubrication Condition (Nut Factor K)',
              prefixIcon: Icon(Icons.opacity_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'Dry / Zinc Plated (K = 0.20)', child: Text('Dry Plain / Zinc Plated (K = 0.20)')),
              DropdownMenuItem(value: 'Lightly Oiled (K = 0.15)', child: Text('Light Machine Oil (K = 0.15)')),
              DropdownMenuItem(value: 'Anti-Seize / Moly (K = 0.12)', child: Text('Anti-Seize / Moly Paste (K = 0.12)')),
              DropdownMenuItem(value: 'PTFE / Loctite (K = 0.10)', child: Text('PTFE / Threadlocker Loctite (K = 0.10)')),
            ],
            onChanged: (val) {
              if (val != null) _onLubePreset(val);
            },
          ),
          const SizedBox(height: 16),

          // Custom Input Numbers
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _diaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _isMetric ? 'Major Dia D (mm)' : 'Major Dia D (in)',
                    hintText: _isMetric ? '12' : '0.500',
                  ),
                  onChanged: (_) => _recalculate(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _pitchCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _isMetric ? 'Pitch (mm)' : 'TPI (Threads/in)',
                    hintText: _isMetric ? '1.75' : '13',
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
                child: TextFormField(
                  controller: _proofStressCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _isMetric ? 'Proof Strength (MPa)' : 'Proof Strength (psi)',
                  ),
                  onChanged: (_) => _recalculate(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _kFactorCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Nut Factor K',
                    hintText: '0.20',
                  ),
                  onChanged: (_) => _recalculate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Clamp Preload % Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Clamp Pre-load % of Proof Load:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('${_clampPercent.toInt()}% (Recommended 75%)', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCyan)),
            ],
          ),
          Slider(
            value: _clampPercent,
            min: 50.0,
            max: 90.0,
            divisions: 8,
            label: '${_clampPercent.toInt()}%',
            activeColor: AppTheme.primaryCyan,
            onChanged: (val) {
              setState(() {
                _clampPercent = val;
                _recalculate();
              });
            },
          ),
          const SizedBox(height: 16),

          // Calculated Results Card
          ExpressiveCard(
            isGlowing: true,
            glowColor: AppTheme.primaryCyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RECOMMENDED TIGHTENING TORQUE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
                    ),
                    ExpressiveBadge(label: 'Target Spec', color: AppTheme.accentEmerald, fontSize: 10),
                  ],
                ),
                const SizedBox(height: 12),

                // Big Torque Number
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          _torqueFtLbs.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppTheme.primaryCyan),
                        ),
                        const Text('ft-lbs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    Container(height: 40, width: 1, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    Column(
                      children: [
                        Text(
                          _torqueNm.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppTheme.accentAmber),
                        ),
                        const Text('N·m', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    Container(height: 40, width: 1, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    Column(
                      children: [
                        Text(
                          _torqueInLbs.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                        const Text('in-lbs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Bolt Stress & Clamping Force Breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tensile Stress Area (At): ${_tensileArea.toStringAsFixed(_isMetric ? 2 : 4)} ${_isMetric ? "mm²" : "in²"}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Clamp Preload: ${_clampForce.toStringAsFixed(1)} ${_isMetric ? "kN" : "lbf"}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accentEmerald),
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
