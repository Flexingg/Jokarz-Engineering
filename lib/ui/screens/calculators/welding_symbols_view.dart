import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Reference dictionary of common welding symbols (AWS-style) with their
/// meaning and typical use.
class WeldingSymbolsView extends StatefulWidget {
  const WeldingSymbolsView({super.key});

  @override
  State<WeldingSymbolsView> createState() => _WeldingSymbolsViewState();
}

class _WeldingSymbolsViewState extends State<WeldingSymbolsView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = _weldSymbols.where((e) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return e.name.toLowerCase().contains(q) ||
          e.desc.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search welding symbols',
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(e.icon, style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(e.desc,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                )),
                          ],
                        ),
                      ),
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

class _WeldSymbol {
  final String icon;
  final String name;
  final String desc;
  const _WeldSymbol(this.icon, this.name, this.desc);
}

const List<_WeldSymbol> _weldSymbols = [
  _WeldSymbol('🔺', 'Fillet Weld',
      'Triangular cross-section, joins two surfaces roughly at right angles. '
      'Most common weld type; size = leg length in inches or mm.'),
  _WeldSymbol('▢', 'Square-Groove Weld',
      'Butt joint with square edges; used on thin material. Little to no gap.'),
  _WeldSymbol('V', 'Single-V Groove Weld',
      'Butt joint beveled to a V. Bevel angle typically 60°; root faces ground.'),
  _WeldSymbol('⌐', 'Single-Bevel Groove Weld',
      'One member beveled, other square. Common for T-joints with full penetration.'),
  _WeldSymbol('⍜', 'Single-U Groove Weld',
      'U-shaped groove for thick plate; reduces filler volume vs a V.'),
  _WeldSymbol('J', 'Single-J Groove Weld',
      'One member with a J-shaped groove; used on thick joints and one-sided access.'),
  _WeldSymbol('◉', 'Plug Weld',
      'Weld filling a round hole in one member to join it to the member below.'),
  _WeldSymbol('▭', 'Slot Weld',
      'Weld filling an elongated (slot) hole in one member.'),
  _WeldSymbol('•', 'Spot Weld',
      'Circular resistance weld at a point joining overlapping sheets.'),
  _WeldSymbol('≋', 'Seam Weld',
      'Continuous or intermittent resistance weld along a seam of overlapping sheets.'),
  _WeldSymbol('⭘', 'Surfacing Weld',
      'Weld deposit applied to a surface for build-up, hard-facing, or wear protection.'),
  _WeldSymbol('❌', 'Stud Weld',
      'Weld attaching a stud (threaded rod) to a base member.'),
  _WeldSymbol('▲▲', 'Field Weld',
      'Indicates a weld made on-site (in the field) rather than in the shop.'),
  _WeldSymbol('∿', 'All Around',
      'Flag on the weld symbol indicating the weld extends around the entire joint.'),
  _WeldSymbol('🛠️', 'Backing / Melt-Thru',
      'Indicates a backing strip or complete joint penetration from the back side.'),
];
