import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../models/bolt_spec.dart';
import '../../../providers/tools_provider.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

class FastenerChartView extends ConsumerWidget {
  const FastenerChartView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fasteners = ref.watch(filteredFastenersProvider);
    final search = ref.watch(fastenerSearchProvider);
    final standard = ref.watch(fastenerStandardProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => ref.read(fastenerSearchProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: 'Search bolt size, tap drill, thread (e.g. M3, 1/4-20, #4)...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              ref.read(fastenerSearchProvider.notifier).state = '',
                        )
                      : null,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Standards'),
                    selected: standard == null,
                    onSelected: (_) =>
                        ref.read(fastenerStandardProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Metric (ISO)'),
                    selected: standard == FastenerStandard.metric,
                    onSelected: (sel) => ref
                        .read(fastenerStandardProvider.notifier)
                        .state = sel ? FastenerStandard.metric : null,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Imperial (UNC)'),
                    selected: standard == FastenerStandard.imperial,
                    onSelected: (sel) => ref
                        .read(fastenerStandardProvider.notifier)
                        .state = sel ? FastenerStandard.imperial : null,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Fastener list
        Expanded(
          child: fasteners.isEmpty
              ? const Center(
                  child: Text('No fasteners match your search'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: fasteners.length,
                  itemBuilder: (context, index) {
                    final spec = fasteners[index];
                    return ExpressiveCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                spec.size,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryCyan,
                                ),
                              ),
                              ExpressiveBadge(
                                label: spec.standard == FastenerStandard.metric
                                    ? 'METRIC'
                                    : 'IMPERIAL',
                                color: spec.standard == FastenerStandard.metric
                                    ? AppTheme.accentEmerald
                                    : AppTheme.accentAmber,
                                fontSize: 10,
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 500;
                              return GridView.count(
                                crossAxisCount: isWide ? 4 : 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                childAspectRatio: isWide ? 2.5 : 2.0,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                children: [
                                  _buildParamTile(
                                    'Tap Drill Size',
                                    '${spec.tapDrillMm} mm',
                                    spec.tapDrillFraction,
                                    AppTheme.accentEmerald,
                                  ),
                                  _buildParamTile(
                                    'Close Clearance',
                                    '${spec.clearanceCloseMm} mm',
                                    'Tight Fit',
                                    AppTheme.primaryCyan,
                                  ),
                                  _buildParamTile(
                                    'Free Clearance',
                                    '${spec.clearanceFreeMm} mm',
                                    'Standard Fit',
                                    AppTheme.accentAmber,
                                  ),
                                  _buildParamTile(
                                    'Hex / Allen Key',
                                    spec.hexKeySize,
                                    'Drive Tool',
                                    AppTheme.accentPurple,
                                  ),
                                ],
                              );
                            },
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

  Widget _buildParamTile(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
