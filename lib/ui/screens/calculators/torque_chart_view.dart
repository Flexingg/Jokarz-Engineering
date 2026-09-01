import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/bolt_spec.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

class TorqueChartView extends StatefulWidget {
  const TorqueChartView({super.key});

  @override
  State<TorqueChartView> createState() => _TorqueChartViewState();
}

class _TorqueChartViewState extends State<TorqueChartView> {
  FastenerStandard _standard = FastenerStandard.metric;
  String _search = '';
  bool _useFtLbs = true; // true = ft-lbs, false = N-m

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allBolts = BoltSpec.database.where((b) {
      final matchesStd = b.standard == _standard;
      final matchesSearch = _search.isEmpty ||
          b.size.toLowerCase().contains(_search.toLowerCase()) ||
          b.pitchOrTpi.toLowerCase().contains(_search.toLowerCase());
      return matchesStd && matchesSearch;
    }).toList();

    return Column(
      children: [
        // Controls Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(
            children: [
              Row(
                children: [
                  // Metric / Imperial Toggle
                  SegmentedButton<FastenerStandard>(
                    segments: const [
                      ButtonSegment(
                        value: FastenerStandard.metric,
                        label: Text('Metric (ISO)', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: FastenerStandard.imperial,
                        label: Text('Imperial (SAE)', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_standard},
                    onSelectionChanged: (val) => setState(() => _standard = val.first),
                  ),
                  const Spacer(),

                  // Unit Toggle (ft-lbs vs N-m)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('ft-lbs', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: false, label: Text('N·m', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {_useFtLbs},
                    onSelectionChanged: (val) => setState(() => _useFtLbs = val.first),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search bolt size (e.g. M12, 1/2", M24, 3/4")...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (val) => setState(() => _search = val),
              ),
            ],
          ),
        ),

        // Grade Legend Banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.of(context).surfaceVariant : AppTheme.of(context).surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                _standard == FastenerStandard.metric ? 'Class 8.8' : 'Grade 2',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.of(context).primary),
              ),
              Text(
                _standard == FastenerStandard.metric ? 'Class 10.9 (High-Strength)' : 'Grade 5 (Automotive)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.of(context).amber),
              ),
              Text(
                _standard == FastenerStandard.metric ? 'Class 12.9 (Alloy Steel)' : 'Grade 8 (High Tensile)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.of(context).emerald),
              ),
            ],
          ),
        ),

        // Bolt Torque Spec Cards List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: allBolts.length,
            itemBuilder: (context, idx) {
              final bolt = allBolts[idx];

              final lowDry = _useFtLbs ? bolt.gradeLow.dryFtLbs : bolt.gradeLow.dryNm;
              final lowLub = _useFtLbs ? bolt.gradeLow.lubedFtLbs : bolt.gradeLow.lubedNm;

              final midDry = _useFtLbs ? bolt.gradeMid.dryFtLbs : bolt.gradeMid.dryNm;
              final midLub = _useFtLbs ? bolt.gradeMid.lubedFtLbs : bolt.gradeMid.lubedNm;

              final highDry = _useFtLbs ? bolt.gradeHigh.dryFtLbs : bolt.gradeHigh.dryNm;
              final highLub = _useFtLbs ? bolt.gradeHigh.lubedFtLbs : bolt.gradeHigh.lubedNm;

              final unitLabel = _useFtLbs ? 'ft-lbs' : 'N·m';

              return ExpressiveCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bolt.size,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            ExpressiveBadge(
                              label: '🔧 Hex Bolt: ${bolt.hexHeadWrenchSize}',
                              color: AppTheme.of(context).emerald,
                              fontSize: 10,
                            ),
                            ExpressiveBadge(
                              label: '🔩 Socket: ${bolt.hexKeySize}',
                              color: AppTheme.of(context).primary,
                              fontSize: 10,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 14),

                    // 3-Column Grade Grid
                    Row(
                      children: [
                        // Grade Low (8.8 / Grade 2)
                        Expanded(
                          child: _buildTorqueColumn(
                            gradeLabel: _standard == FastenerStandard.metric ? '8.8' : 'Grade 2',
                            dryVal: lowDry,
                            lubVal: lowLub,
                            unit: unitLabel,
                            color: AppTheme.of(context).primary,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Grade Mid (10.9 / Grade 5)
                        Expanded(
                          child: _buildTorqueColumn(
                            gradeLabel: _standard == FastenerStandard.metric ? '10.9' : 'Grade 5',
                            dryVal: midDry,
                            lubVal: midLub,
                            unit: unitLabel,
                            color: AppTheme.of(context).amber,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Grade High (12.9 / Grade 8)
                        Expanded(
                          child: _buildTorqueColumn(
                            gradeLabel: _standard == FastenerStandard.metric ? '12.9' : 'Grade 8',
                            dryVal: highDry,
                            lubVal: highLub,
                            unit: unitLabel,
                            color: AppTheme.of(context).emerald,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTorqueColumn({
    required String gradeLabel,
    required double dryVal,
    required double lubVal,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            gradeLabel,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            'Dry: ${dryVal.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            'Lubed: ${lubVal.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
