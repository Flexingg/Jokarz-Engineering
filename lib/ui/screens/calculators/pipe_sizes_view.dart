import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Pipe sizes & schedules reference + calculator. Shows nominal pipe size (NPS)
/// outside diameter, and for a chosen schedule the wall thickness and inside
/// diameter (ID = OD - 2×wall).
class PipeSizesView extends StatefulWidget {
  const PipeSizesView({super.key});

  @override
  State<PipeSizesView> createState() => _PipeSizesViewState();
}

class _PipeSizesViewState extends State<PipeSizesView> {
  String _nps = '1"';
  int _schedule = 40;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final od = pipeData[_nps]!.$1;
    final wall = pipeData[_nps]!.$2[_schedule] ?? 0;
    final id = od - 2 * wall;

    Widget label(String s) => Text(s,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary));
    Widget value(String s) => Text(s,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Interactive calculator
        Text('Pipe Dimension Calculator',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _nps,
              decoration: const InputDecoration(labelText: 'Nominal Pipe Size (NPS)'),
              items: pipeData.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
              onChanged: (v) => setState(() => _nps = v ?? '1"'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _schedule,
              decoration: const InputDecoration(labelText: 'Schedule'),
              items: [5, 10, 40, 80].map((s) => DropdownMenuItem(value: s, child: Text('SCH $s'))).toList(),
              onChanged: (v) => setState(() => _schedule = v ?? 40),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Card(
          color: AppTheme.primaryCyan.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  label('OD (in)'), value(od.toStringAsFixed(3)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  label('Wall (in)'), value(wall.toStringAsFixed(3)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  label('ID (in)'), value(id.toStringAsFixed(3)),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              label('OD (mm)'),
              Text((od * 25.4).toStringAsFixed(1),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              label('ID (mm)'),
              Text((id * 25.4).toStringAsFixed(1),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        Text('Reference: NPS → OD & wall thickness',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan)),
        const SizedBox(height: 8),
        // Reference table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 22,
            columns: const [
              DataColumn(label: Text('NPS')),
              DataColumn(label: Text('OD (in)')),
              DataColumn(label: Text('SCH40 wall')),
              DataColumn(label: Text('SCH80 wall')),
              DataColumn(label: Text('SCH40 ID')),
            ],
            rows: [
              for (final e in pipeData.entries)
                DataRow(cells: [
                  DataCell(Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(e.value.$1.toStringAsFixed(3))),
                  DataCell(Text((e.value.$2[40] ?? 0).toStringAsFixed(3))),
                  DataCell(Text((e.value.$2[80] ?? 0).toStringAsFixed(3))),
                  DataCell(Text((e.value.$1 - 2 * (e.value.$2[40] ?? 0)).toStringAsFixed(2))),
                ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// NPS -> (OD inches, {schedule: wall thickness inches})
const Map<String, (double, Map<int, double>)> pipeData = {
  '1/8"': (0.405, {5: 0.049, 10: 0.068, 40: 0.068, 80: 0.095}),
  '1/4"': (0.540, {5: 0.065, 10: 0.088, 40: 0.088, 80: 0.119}),
  '3/8"': (0.675, {5: 0.065, 10: 0.091, 40: 0.091, 80: 0.126}),
  '1/2"': (0.840, {5: 0.065, 10: 0.083, 40: 0.109, 80: 0.147}),
  '3/4"': (1.050, {5: 0.065, 10: 0.083, 40: 0.113, 80: 0.154}),
  '1"': (1.315, {5: 0.065, 10: 0.109, 40: 0.133, 80: 0.179}),
  '1-1/4"': (1.660, {5: 0.065, 10: 0.109, 40: 0.140, 80: 0.191}),
  '1-1/2"': (1.900, {5: 0.065, 10: 0.109, 40: 0.145, 80: 0.200}),
  '2"': (2.375, {5: 0.065, 10: 0.109, 40: 0.154, 80: 0.218}),
  '2-1/2"': (2.875, {5: 0.083, 10: 0.120, 40: 0.203, 80: 0.276}),
  '3"': (3.500, {5: 0.083, 10: 0.120, 40: 0.216, 80: 0.300}),
  '3-1/2"': (4.000, {5: 0.083, 10: 0.120, 40: 0.226, 80: 0.318}),
  '4"': (4.500, {5: 0.083, 10: 0.120, 40: 0.237, 80: 0.337}),
  '5"': (5.563, {5: 0.109, 10: 0.134, 40: 0.258, 80: 0.375}),
  '6"': (6.625, {5: 0.109, 10: 0.134, 40: 0.280, 80: 0.432}),
  '8"': (8.625, {5: 0.109, 10: 0.148, 40: 0.322, 80: 0.500}),
  '10"': (10.750, {5: 0.134, 10: 0.165, 40: 0.365, 80: 0.594}),
  '12"': (12.750, {5: 0.156, 10: 0.180, 40: 0.406, 80: 0.688}),
};
