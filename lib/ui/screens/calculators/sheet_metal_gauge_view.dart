import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Sheet metal thickness gauge chart (Manufacturer's Standard Gauge for sheet
/// steel) with equivalent thickness in inches and millimetres.
class SheetMetalGaugeView extends StatefulWidget {
  const SheetMetalGaugeView({super.key});

  @override
  State<SheetMetalGaugeView> createState() => _SheetMetalGaugeViewState();
}

class _SheetMetalGaugeViewState extends State<SheetMetalGaugeView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = sheetGaugeData.where((r) {
      if (_query.isEmpty) return true;
      return r.$1.toLowerCase().contains(_query.toLowerCase()) ||
          r.$2.toString().contains(_query);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search gauge or thickness',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Text(
                  'Manufacturer\u2019s Standard Gauge for sheet steel. '
                  'Thickness shown is nominal. For aluminum the thickness is '
                  'similar but not identical \u2014 confirm with the supplier.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 10),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1.4),
                  2: FlexColumnWidth(1.4),
                },
                border: TableBorder.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 0.5,
                ),
                children: [
                  _header('Gauge', 'Inches', 'Millimetres'),
                  for (final (g, inches) in rows)
                    TableRow(children: [
                      _cell(g, bold: true),
                      _cell(inches.toStringAsFixed(4)),
                      _cell((inches * 25.4).toStringAsFixed(2)),
                    ]),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  TableRow _header(String a, String b, String c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TableRow(
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant),
      children: [
        _cell(a, bold: true, header: true),
        _cell(b, bold: true, header: true),
        _cell(c, bold: true, header: true),
      ],
    );
  }

  Widget _cell(String text, {bool bold = false, bool header = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: header ? AppTheme.primaryCyan : (isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}

/// (gauge label, thickness in inches)
const List<(String, double)> sheetGaugeData = [
  ('3', 0.2391), ('4', 0.2242), ('5', 0.2092), ('6', 0.1943),
  ('7', 0.1793), ('8', 0.1644), ('9', 0.1495), ('10', 0.1345),
  ('11', 0.1196), ('12', 0.1046), ('13', 0.0897), ('14', 0.0747),
  ('15', 0.0673), ('16', 0.0598), ('17', 0.0538), ('18', 0.0478),
  ('19', 0.0418), ('20', 0.0359), ('21', 0.0329), ('22', 0.0299),
  ('23', 0.0269), ('24', 0.0239), ('25', 0.0209), ('26', 0.0179),
  ('27', 0.0164), ('28', 0.0149), ('29', 0.0135), ('30', 0.0120),
];
