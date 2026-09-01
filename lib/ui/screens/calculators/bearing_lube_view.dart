import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Bearing lubrication reference: grease volume per regrease plus recommended
/// regreasing frequency by operating speed.
class BearingLubeView extends StatefulWidget {
  const BearingLubeView({super.key});

  @override
  State<BearingLubeView> createState() => _BearingLubeViewState();
}

class _BearingLubeViewState extends State<BearingLubeView> {
  final TextEditingController _od = TextEditingController(text: '1.00');
  final TextEditingController _width = TextEditingController(text: '0.50');

  double get _oz {
    final od = double.tryParse(_od.text) ?? 0;
    final w = double.tryParse(_width.text) ?? 0;
    // Rule of thumb: ounces of grease per regrease = 0.114 × OD(in) × width(in)
    return od * w * 0.114;
  }

  @override
  void dispose() {
    _od.dispose();
    _width.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Regrease Volume Calculator',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.of(context).primary)),
        const SizedBox(height: 4),
        Text('Approx. grease per regrease = 0.114 × OD × width (ounces). '
            'Fill the housing cavity about 1/3 to 1/2 full.',
            style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _od,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Bearing OD (in)', isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _width,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Width (in)', isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Card(
          color: AppTheme.of(context).amber.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Text('Grease per regrease',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary)),
              const SizedBox(height: 4),
              Text('${_oz.toStringAsFixed(2)} oz  (${(_oz * 28.35).toStringAsFixed(1)} g)',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        Text('Recommended Regreasing Frequency (ball bearings)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.of(context).primary)),
        const SizedBox(height: 8),
        _freqTable(isDark),
      ],
    );
  }

  Widget _freqTable(bool isDark) {
    const rows = <(String, String)>[
      ('< 150 RPM', '12 months (or per OEM)'),
      ('150–300 RPM', '6 months'),
      ('300–1,000 RPM', '3 months'),
      ('1,000–2,000 RPM', '1 month'),
      ('2,000–3,600 RPM', '2 weeks'),
      ('> 3,600 RPM', '1 week (oil lube preferred)'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          for (final (speed, freq) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(speed,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(freq,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary)),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              'Intervals assume clean, dry environment and moderate load. '
              'Consult OEM/manufacturer for severe duty, high temp, or vibration.',
              style: TextStyle(fontSize: 10.5, height: 1.3,
                  color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary),
            ),
          ),
        ]),
      ),
    );
  }
}
