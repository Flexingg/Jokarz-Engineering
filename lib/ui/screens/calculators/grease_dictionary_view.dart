import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Lubrication / grease dictionary: NLGI grades, thickeners, base oils and
/// practical guidance, searchable.
class GreaseDictionaryView extends StatefulWidget {
  const GreaseDictionaryView({super.key});

  @override
  State<GreaseDictionaryView> createState() => _GreaseDictionaryViewState();
}

class _GreaseDictionaryViewState extends State<GreaseDictionaryView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = _greaseEntries.where((e) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return e.name.toLowerCase().contains(q) || e.desc.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search lubrication terms',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: e.accent)),
                      const SizedBox(height: 4),
                      Text(e.desc,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: isDark
                                  ? AppTheme.of(context).textSecondary
                                  : AppTheme.of(context).textSecondary)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GreaseEntry {
  final String name;
  final String desc;
  final Color accent;
  const _GreaseEntry(this.name, this.desc, this.accent);
}

const List<_GreaseEntry> _greaseEntries = [
  _GreaseEntry('NLGI Grade', 'Consistency rating of grease (ASTM worked penetration). '
      'Higher number = stiffer grease. NLGI 0 = semi-fluid, NLGI 2 = standard multipurpose, '
      'NLGI 3 = firmer (larger/vertical bearings), NLGI 000-00 = fluid for centralized systems.', AppTheme.primaryCyan),
  _GreaseEntry('Lithium Complex', 'Most common modern thickener. High drop point (~260°C+), '
      'good water resistance, multipurpose. Great general-purpose EP grease.', AppTheme.accentEmerald),
  _GreaseEntry('Lithium (12-OH)', 'General-purpose grease, good pumpability and water resistance. '
      'Drop point ~190°C. Standard multipurpose (e.g. general chassis/bearing grease).', AppTheme.accentEmerald),
  _GreaseEntry('Calcium / Calcium Sulfonate', 'Excellent water resistance and rust protection. '
      'Calcium sulfonate complex is high-temp and EP capable; good for wet/marine environments.', AppTheme.accentAmber),
  _GreaseEntry('Polyurea', 'High-temp, long-life electric motor bearing grease. '
      'Not compatible with many soap thickeners (separation risk). Use only where specified.', AppTheme.accentCoral),
  _GreaseEntry('Bentonite / Clay', 'Non-soap thickener, very high drop point. '
      'Good for high-temp applications where soap greases would melt out.', AppTheme.accentCoral),
  _GreaseEntry('Mineral Base Oil', 'Petroleum-derived base oil. Cost-effective; '
      'temperature range typically -20°C to +120°C. Most industrial greases use mineral oil.', AppTheme.primaryBlue),
  _GreaseEntry('Synthetic (PAO) / Synthetic Esters', 'Synthetic base oils with wider temperature range '
      '(-50°C to +180°C+), better oxidation stability and longer life. For high-temp, high-speed, or cold service.', AppTheme.accentEmerald),
  _GreaseEntry('EP Additives', 'Extreme-pressure additives (sulfur/phosphorus compounds). '
      'Protect against scoring and wear under heavy loads and shock loading (gear, heavy bearing service).', AppTheme.accentAmber),
  _GreaseEntry('Molybdenum Disulfide (MoS₂)', 'Solid lubricant additive for extreme pressure, '
      'boundary lubrication, and anti-seize. Good for slow, heavily-loaded sliding surfaces.', AppTheme.accentCoral),
  _GreaseEntry('Drop Point', 'Temperature at which the grease thickener changes phase and the '
      'grease melts. Higher is generally better for high-temperature service.', AppTheme.primaryCyan),
  _GreaseEntry('Worked Penetration', 'A measure of grease consistency/softness (ASTM D217). '
      '60-stroke worked penetration of 265-295 corresponds to NLGI 2. Lower number = stiffer.', AppTheme.primaryCyan),
  _GreaseEntry('Compatibility', 'Greases with different thickener types should NOT be mixed '
      '(can soften or harden). Flush or purge old grease before switching types.', AppTheme.accentCoral),
];
