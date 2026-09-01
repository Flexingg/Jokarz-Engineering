import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

class MaterialThermalProfile {
  final String name;
  final double alphaPerCelsius; // Thermal expansion coefficient (x 10^-6 / °C)
  final String description;

  const MaterialThermalProfile({
    required this.name,
    required this.alphaPerCelsius,
    required this.description,
  });

  static const List<MaterialThermalProfile> standardMaterials = [
    MaterialThermalProfile(
      name: 'Carbon Steel / Alloy Steel (1018/4140)',
      alphaPerCelsius: 11.7, // 11.7 x 10^-6 / °C
      description: 'Standard machine shafts, gears, sprockets',
    ),
    MaterialThermalProfile(
      name: 'Stainless Steel 304 / 316',
      alphaPerCelsius: 16.0,
      description: 'Food grade, chemical shafts and collars',
    ),
    MaterialThermalProfile(
      name: 'Aluminum 6061-T6 / 7075',
      alphaPerCelsius: 23.1,
      description: 'High expansion lightweight hubs & pulleys',
    ),
    MaterialThermalProfile(
      name: 'Bearing Steel (52100 Chrome Steel)',
      alphaPerCelsius: 11.9,
      description: 'SKF/Timken/NTN ball and roller bearings',
    ),
    MaterialThermalProfile(
      name: 'Bronze / Brass (SAE 660 / C360)',
      alphaPerCelsius: 18.0,
      description: 'Bushings, worm gears, sleeves',
    ),
    MaterialThermalProfile(
      name: 'Cast Iron (Class 30/40 Gray/Ductile)',
      alphaPerCelsius: 10.5,
      description: 'Heavy sheaves, machine frames, flywheels',
    ),
  ];
}

class HeatTintInfo {
  final double minCelsius;
  final double maxCelsius;
  final String name;
  final Color swatchColor;
  final String description;

  const HeatTintInfo({
    required this.minCelsius,
    required this.maxCelsius,
    required this.name,
    required this.swatchColor,
    required this.description,
  });

  static const List<HeatTintInfo> steelScale = [
    HeatTintInfo(
      minCelsius: 0,
      maxCelsius: 215,
      name: 'Unoxidized Metallic (No Color Change)',
      swatchColor: Color(0xFFC0C0C0),
      description: 'Safe for bearings (Bearing manufacturers max 120°C / 250°F)',
    ),
    HeatTintInfo(
      minCelsius: 215,
      maxCelsius: 235,
      name: 'Faint / Pale Straw (220°C / 430°F)',
      swatchColor: Color(0xFFE8D499),
      description: 'Very light golden oxide. Hard cutting tools temper zone.',
    ),
    HeatTintInfo(
      minCelsius: 235,
      maxCelsius: 255,
      name: 'Medium Straw / Yellow Gold (245°C / 470°F)',
      swatchColor: Color(0xFFDAAC42),
      description: 'Clear golden yellow tint. Punches and dies.',
    ),
    HeatTintInfo(
      minCelsius: 255,
      maxCelsius: 275,
      name: 'Brown / Bronze (265°C / 510°F)',
      swatchColor: Color(0xFFA86638),
      description: 'Rich bronze color. Shear blades and taps.',
    ),
    HeatTintInfo(
      minCelsius: 275,
      maxCelsius: 295,
      name: 'Purple / Violet (285°C / 545°F)',
      swatchColor: Color(0xFF7E387C),
      description: 'Distinct violet purple. Cold chisels, high shock.',
    ),
    HeatTintInfo(
      minCelsius: 295,
      maxCelsius: 315,
      name: 'Bright Cobalt Blue (305°C / 580°F)',
      swatchColor: Color(0xFF2A52BE),
      description: 'Vivid bright blue oxide. Screwdrivers and gears.',
    ),
    HeatTintInfo(
      minCelsius: 315,
      maxCelsius: 360,
      name: 'Dark Navy Blue (330°C / 625°F)',
      swatchColor: Color(0xFF1B2A4A),
      description: 'Deep navy oxide. Springs and heavy impact tooling.',
    ),
    HeatTintInfo(
      minCelsius: 360,
      maxCelsius: 500,
      name: 'Dull Grey Oxide (400°C+ / 750°F+)',
      swatchColor: Color(0xFF555555),
      description: 'Heavy grey scale. Significant loss of hardened temper.',
    ),
    HeatTintInfo(
      minCelsius: 500,
      maxCelsius: 900,
      name: 'Incipient Red Glow (550°C+ / 1020°F+)',
      swatchColor: Color(0xFFB22222),
      description: 'Dull to bright red heat. Annealing range (loss of hardness).',
    ),
  ];

  static HeatTintInfo getForTemp(double celsius) {
    for (final tint in steelScale) {
      if (celsius >= tint.minCelsius && celsius <= tint.maxCelsius) {
        return tint;
      }
    }
    return steelScale.last;
  }
}

class HeatShrinkCalculatorView extends StatefulWidget {
  const HeatShrinkCalculatorView({super.key});

  @override
  State<HeatShrinkCalculatorView> createState() =>
      _HeatShrinkCalculatorViewState();
}

class _HeatShrinkCalculatorViewState extends State<HeatShrinkCalculatorView> {
  bool _isMetric = true; // true = mm & °C, false = inches & °F

  MaterialThermalProfile _hubMaterial =
      MaterialThermalProfile.standardMaterials[0]; // Steel

  final _shaftOdCtrl = TextEditingController(text: '50.050'); // 50.050 mm
  final _hubIdCtrl = TextEditingController(text: '50.000'); // 50.000 mm
  final _startTempCtrl = TextEditingController(text: '20'); // 20°C / 68°F
  final _heatedTempCtrl = TextEditingController(text: '200'); // 200°C / 392°F

  double _interference = 0.0;
  double _thermalExpansion = 0.0;
  double _hotInstallationClearance = 0.0;
  HeatTintInfo _currentTint = HeatTintInfo.steelScale[0];

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _shaftOdCtrl.dispose();
    _hubIdCtrl.dispose();
    _startTempCtrl.dispose();
    _heatedTempCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final shaftOd = double.tryParse(_shaftOdCtrl.text.trim()) ?? 0;
    final hubId = double.tryParse(_hubIdCtrl.text.trim()) ?? 0;
    final startT = double.tryParse(_startTempCtrl.text.trim()) ?? 20;
    final heatedT = double.tryParse(_heatedTempCtrl.text.trim()) ?? 200;

    if (shaftOd <= 0 || hubId <= 0) return;

    setState(() {
      // Interference at room temp (Shaft OD - Hub ID)
      _interference = shaftOd - hubId;

      double deltaTCelsius = 0;
      double tempInCelsiusForTint = 0;

      if (_isMetric) {
        deltaTCelsius = heatedT - startT;
        tempInCelsiusForTint = heatedT;
        // Thermal Expansion: ΔD = D0 * α * ΔT
        _thermalExpansion =
            hubId * (_hubMaterial.alphaPerCelsius * 1e-6) * deltaTCelsius;
      } else {
        // Imperial (°F): ΔT_C = (heatedT - startT) * 5/9
        deltaTCelsius = (heatedT - startT) * (5.0 / 9.0);
        tempInCelsiusForTint = (heatedT - 32.0) * (5.0 / 9.0);
        _thermalExpansion =
            hubId * (_hubMaterial.alphaPerCelsius * 1e-6) * deltaTCelsius;
      }

      // Hot Installation Clearance = Hub Heated Bore - Cold Shaft OD
      final hotHubBore = hubId + _thermalExpansion;
      _hotInstallationClearance = hotHubBore - shaftOd;

      _currentTint = HeatTintInfo.getForTemp(tempInCelsiusForTint);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dimUnit = _isMetric ? 'mm' : 'in';
    final tempUnit = _isMetric ? '°C' : '°F';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ExpressiveCard(
            child: Row(
              children: [
                Icon(Icons.local_fire_department_rounded,
                    color: AppTheme.of(context).coral, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thermal Shrink Fit & Expansion Solver',
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Calculate thermal bore expansion, hot slip clearance, and steel heat-tint oxidation color.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.of(context).textSecondary
                              : AppTheme.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Unit Toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: true, label: Text('Metric (mm / °C)')),
              ButtonSegment(
                  value: false, label: Text('Imperial (Inches / °F)')),
            ],
            selected: {_isMetric},
            onSelectionChanged: (val) {
              setState(() {
                _isMetric = val.first;
                if (_isMetric) {
                  _shaftOdCtrl.text = '50.050';
                  _hubIdCtrl.text = '50.000';
                  _startTempCtrl.text = '20';
                  _heatedTempCtrl.text = '200';
                } else {
                  _shaftOdCtrl.text = '2.0020';
                  _hubIdCtrl.text = '2.0000';
                  _startTempCtrl.text = '68';
                  _heatedTempCtrl.text = '392';
                }
                _recalculate();
              });
            },
          ),
          const SizedBox(height: 16),

          // Hub Material Selection
          DropdownButtonFormField<MaterialThermalProfile>(
            value: _hubMaterial,
            decoration: const InputDecoration(
              labelText: 'Hub / Outer Ring Material (To be heated)',
              prefixIcon: Icon(Icons.blur_circular_rounded),
            ),
            items: MaterialThermalProfile.standardMaterials
                .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(
                        '${m.name} (α=${m.alphaPerCelsius} μm/m·°C)',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _hubMaterial = val;
                  _recalculate();
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // Dimensions Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _hubIdCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Hub Bore ID (Cold) [$dimUnit]',
                    hintText: _isMetric ? '50.000' : '2.0000',
                  ),
                  onChanged: (_) => _recalculate(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _shaftOdCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Shaft OD (Cold) [$dimUnit]',
                    hintText: _isMetric ? '50.050' : '2.0020',
                  ),
                  onChanged: (_) => _recalculate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Temperature Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startTempCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Ambient Temp [$tempUnit]',
                    hintText: _isMetric ? '20' : '68',
                  ),
                  onChanged: (_) => _recalculate(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _heatedTempCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Final Heated Temp [$tempUnit]',
                    hintText: _isMetric ? '200' : '392',
                  ),
                  onChanged: (_) => _recalculate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Results Card
          ExpressiveCard(
            isGlowing: true,
            glowColor: _hotInstallationClearance > 0
                ? AppTheme.of(context).emerald
                : AppTheme.of(context).coral,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FIT & THERMAL CLEARANCE ANALYSIS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.of(context).primary,
                      ),
                    ),
                    ExpressiveBadge(
                      label: _hotInstallationClearance > 0
                          ? 'Slip Fit (+${_hotInstallationClearance.toStringAsFixed(_isMetric ? 3 : 4)} $dimUnit)'
                          : 'Insufficient Heat (Binding!)',
                      color: _hotInstallationClearance > 0
                          ? AppTheme.of(context).emerald
                          : AppTheme.of(context).coral,
                      fontSize: 10,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Metrics Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${_interference.toStringAsFixed(_isMetric ? 3 : 4)} $dimUnit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.of(context).amber,
                          ),
                        ),
                        const Text('Cold Interference Fit',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '+${_thermalExpansion.toStringAsFixed(_isMetric ? 3 : 4)} $dimUnit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.of(context).primary,
                          ),
                        ),
                        const Text('Thermal Expansion ΔD',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${_hotInstallationClearance.toStringAsFixed(_isMetric ? 3 : 4)} $dimUnit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _hotInstallationClearance > 0
                                ? AppTheme.of(context).emerald
                                : AppTheme.of(context).coral,
                          ),
                        ),
                        const Text('Hot Install Slip Clearance',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Heat Tint Oxidation Color Indicator
                const Text(
                  'METAL TEMPERING & HEAT-TINT COLOR',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.of(context).surfaceVariant
                        : AppTheme.of(context).surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: _currentTint.swatchColor.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Swatch Box
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _currentTint.swatchColor,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          boxShadow: [
                            BoxShadow(
                              color: _currentTint.swatchColor
                                  .withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentTint.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentTint.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppTheme.of(context).textSecondary
                                    : AppTheme.of(context).textSecondary,
                              ),
                            ),
                          ],
                        ),
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
