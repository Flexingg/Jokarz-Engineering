import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/bolt_spec.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

class FastenerChartView extends StatefulWidget {
  const FastenerChartView({super.key});

  @override
  State<FastenerChartView> createState() => _FastenerChartViewState();
}

class _FastenerChartViewState extends State<FastenerChartView> {
  FastenerStandard _standard = FastenerStandard.metric;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bolts = BoltSpec.database.where((b) {
      final matchesStd = b.standard == _standard;
      final matchesSearch = _search.isEmpty ||
          b.size.toLowerCase().contains(_search.toLowerCase()) ||
          b.pitchOrTpi.toLowerCase().contains(_search.toLowerCase()) ||
          b.tapDrillFraction.toLowerCase().contains(_search.toLowerCase()) ||
          b.tapDrillMmLabel.toLowerCase().contains(_search.toLowerCase());
      return matchesStd && matchesSearch;
    }).toList();

    return Column(
      children: [
        // Controls Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  SegmentedButton<FastenerStandard>(
                    segments: const [
                      ButtonSegment(
                        value: FastenerStandard.metric,
                        label: Text('Metric (M2 to M50)'),
                      ),
                      ButtonSegment(
                        value: FastenerStandard.imperial,
                        label: Text('Imperial (#2 to 2")'),
                      ),
                    ],
                    selected: {_standard},
                    onSelectionChanged: (val) => setState(() => _standard = val.first),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: _standard == FastenerStandard.metric
                      ? 'Search metric thread (e.g. M6, M12, M24, M48)...'
                      : 'Search imperial thread (e.g. 1/4, 1/2, 3/4, #10)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (val) => setState(() => _search = val),
              ),
            ],
          ),
        ),

        // Fastener Specs List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: bolts.length,
            itemBuilder: (context, idx) {
              final bolt = bolts[idx];
              final isMetric = bolt.standard == FastenerStandard.metric;

              return ExpressiveCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Bolt Size, Pitch, and Drive Key
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              bolt.size,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ExpressiveBadge(
                              label: bolt.pitchOrTpi,
                              color: AppTheme.primaryCyan,
                              fontSize: 10,
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            ExpressiveBadge(
                              label: '🔧 Hex Bolt: ${bolt.hexHeadWrenchSize}',
                              color: AppTheme.accentEmerald,
                              fontSize: 10,
                            ),
                            ExpressiveBadge(
                              label: '🔩 Socket: ${bolt.hexKeySize}',
                              color: AppTheme.accentAmber,
                              fontSize: 10,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Dimensions & Tap Drill Spec Grid
                    Row(
                      children: [
                        // Tap Drill Size
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentEmerald.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              border: Border.all(color: AppTheme.accentEmerald.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TAP DRILL (75% THREAD)',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentEmerald,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isMetric
                                      ? bolt.tapDrillMmLabel
                                      : bolt.tapDrillFraction,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (isMetric)
                                  Text(
                                    '(${bolt.tapDrillDecimalInch.toStringAsFixed(4)}")',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  )
                                else
                                  Text(
                                    '(${bolt.tapDrillMm.toStringAsFixed(2)} mm)',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Close Clearance Hole (Tight fit)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CLOSE CLEARANCE (TIGHT)',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isMetric
                                      ? '${bolt.clearanceCloseMm.toStringAsFixed(2)} mm'
                                      : bolt.clearanceCloseInch,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Free Clearance Hole (Standard fit)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FREE CLEARANCE (STD)',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isMetric
                                      ? '${bolt.clearanceFreeMm.toStringAsFixed(2)} mm'
                                      : bolt.clearanceFreeInch,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
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
}
