import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/expressive_card.dart';

enum ConversionCategory {
  length('Length & Metrology'),
  pressure('Pressure & Hydraulics'),
  torque('Torque & Fasteners'),
  temperature('Temperature'),
  mass('Mass & Weight'),
  power('Power & Energy');

  final String label;
  const ConversionCategory(this.label);
}

class UnitConverterView extends StatefulWidget {
  const UnitConverterView({super.key});

  @override
  State<UnitConverterView> createState() => _UnitConverterViewState();
}

class _UnitConverterViewState extends State<UnitConverterView> {
  ConversionCategory _category = ConversionCategory.length;
  double _inputValue = 1.0;
  String _selectedFromUnit = 'mm';
  late final TextEditingController _valueCtrl;

  final Map<ConversionCategory, Map<String, double>> _unitsToSI = {
    ConversionCategory.length: {
      'mm': 0.001,
      'cm': 0.01,
      'm': 1.0,
      'inch': 0.0254,
      'ft': 0.3048,
      'mil (thou)': 0.0000254,
      'micron (µm)': 0.000001,
    },
    ConversionCategory.pressure: {
      'psi': 6894.76,
      'bar': 100000.0,
      'kPa': 1000.0,
      'MPa': 1000000.0,
      'atm': 101325.0,
      'Pa': 1.0,
    },
    ConversionCategory.torque: {
      'N·m': 1.0,
      'lb·ft': 1.35582,
      'lb·in': 0.112985,
      'kg·cm': 0.0980665,
    },
    ConversionCategory.mass: {
      'g': 0.001,
      'kg': 1.0,
      'oz': 0.0283495,
      'lb': 0.453592,
    },
    ConversionCategory.power: {
      'Watts (W)': 1.0,
      'Kilowatts (kW)': 1000.0,
      'Horsepower (HP)': 745.7,
      'BTU/hr': 0.293071,
    },
  };

  @override
  void initState() {
    super.initState();
    _selectedFromUnit = _unitsToSI[_category]!.keys.first;
    _valueCtrl = TextEditingController(text: _inputValue.toString());
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  void _onCategoryChanged(ConversionCategory cat) {
    setState(() {
      _category = cat;
      _selectedFromUnit = cat == ConversionCategory.temperature
          ? '°C'
          : _unitsToSI[cat]!.keys.first;
    });
  }

  Map<String, String> _computeConversions() {
    if (_category == ConversionCategory.temperature) {
      double c = _inputValue;
      if (_selectedFromUnit == '°F') {
        c = (_inputValue - 32) * 5 / 9;
      } else if (_selectedFromUnit == 'K') {
        c = _inputValue - 273.15;
      }
      final f = (c * 9 / 5) + 32;
      final k = c + 273.15;
      return {
        'Celsius (°C)': '${c.toStringAsFixed(2)} °C',
        'Fahrenheit (°F)': '${f.toStringAsFixed(2)} °F',
        'Kelvin (K)': '${k.toStringAsFixed(2)} K',
      };
    }

    final rates = _unitsToSI[_category]!;
    final fromRate = rates[_selectedFromUnit] ?? 1.0;
    final baseSI = _inputValue * fromRate;

    final results = <String, String>{};
    for (final entry in rates.entries) {
      final val = baseSI / entry.value;
      results[entry.key] = val < 0.001 || val > 100000
          ? val.toStringAsExponential(4)
          : val.toStringAsFixed(4);
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final conversions = _computeConversions();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Engineering Dimensional & Unit Converter',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ConversionCategory.values
                  .map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat.label),
                        selected: _category == cat,
                        onSelected: (s) {
                          if (s) _onCategoryChanged(cat);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Input Box & From Selector
          ExpressiveCard(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Magnitude / Value'),
                    controller: _valueCtrl,
                    onChanged: (v) {
                      setState(() {
                        // Blank input is allowed and treated as zero; the field
                        // is not forced back to a number.
                        _inputValue = double.tryParse(v) ?? 0.0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedFromUnit,
                    decoration: const InputDecoration(labelText: 'From Unit'),
                    items: _category == ConversionCategory.temperature
                        ? ['°C', '°F', 'K']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList()
                        : _unitsToSI[_category]!
                            .keys
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedFromUnit = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Results Matrix
          const Text(
            'Direct Equivalents',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              return GridView.count(
                crossAxisCount: isWide ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: isWide ? 2.5 : 2.0,
                children: conversions.entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceHighlight : AppTheme.lightSurfaceHighlight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          e.value,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryCyan,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
