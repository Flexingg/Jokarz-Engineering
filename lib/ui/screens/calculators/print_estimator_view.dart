import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../models/filament_profile.dart';
import '../../../models/order_item.dart';
import '../../../providers/tools_provider.dart';
import '../../../providers/project_provider.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

class PrintEstimatorView extends ConsumerStatefulWidget {
  const PrintEstimatorView({super.key});

  @override
  ConsumerState<PrintEstimatorView> createState() => _PrintEstimatorViewState();
}

class _PrintEstimatorViewState extends ConsumerState<PrintEstimatorView> {
  final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printEstimatorProvider);
    final notifier = ref.read(printEstimatorProvider.notifier);
    final projectsState = ref.watch(projectProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header description
          const Text(
            '3D Print & Slicer Cost Estimator',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Calculate exact filament consumption, electricity, machine wear, labor, and commercial markups.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Total Cost Banner Card
          ExpressiveCard(
            isGlowing: true,
            glowColor: AppTheme.primaryCyan,
            backgroundColor: isDark ? const Color(0xFF0F1B2B) : const Color(0xFFE6F7FF),
            borderColor: AppTheme.primaryCyan,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL ESTIMATED COST',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currency.format(state.totalNetCost),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Commercial Multipliers',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ExpressiveBadge(
                              label: '2x: ${currency.format(state.suggestedPrice2x)}',
                              color: AppTheme.accentEmerald,
                              fontSize: 11,
                            ),
                            const SizedBox(width: 6),
                            ExpressiveBadge(
                              label: '3x: ${currency.format(state.suggestedPrice3x)}',
                              color: AppTheme.accentAmber,
                              fontSize: 11,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Breakdown Badges
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildCostPill('Filament', currency.format(state.rawFilamentCost), AppTheme.primaryCyan),
                    _buildCostPill('Power', currency.format(state.powerCost), AppTheme.accentAmber),
                    _buildCostPill('Wear', currency.format(state.machineWearCost), AppTheme.accentPurple),
                    _buildCostPill('Labor', currency.format(state.laborCost), AppTheme.accentEmerald),
                    _buildCostPill('Buffer (${state.failureBufferPercent.toInt()}%)', currency.format(state.failureBufferCost), AppTheme.accentCoral),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Filament Selector
          const Text(
            'Material & Spool Profile',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: FilamentProfile.defaultProfiles.map((f) {
                final isSel = state.selectedFilament.id == f.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text('${f.name} (${currency.format(f.spoolCostUsd)}/kg)'),
                    selected: isSel,
                    onSelected: (sel) {
                      if (sel) notifier.setFilament(f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Input Sliders & Fields
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Part Weight Slider
                _buildSliderRow(
                  title: 'Part Net Weight',
                  value: state.partWeightGrams,
                  unit: 'g',
                  min: 5.0,
                  max: 1000.0,
                  divisions: 199,
                  color: AppTheme.primaryCyan,
                  onChanged: (v) => notifier.updateParams(weight: v),
                ),
                const SizedBox(height: 16),

                // Print Time Slider
                _buildSliderRow(
                  title: 'Print Run Time',
                  value: state.printTimeHours,
                  unit: 'hrs',
                  min: 0.5,
                  max: 48.0,
                  divisions: 95,
                  color: AppTheme.accentEmerald,
                  onChanged: (v) => notifier.updateParams(hours: v),
                ),
                const SizedBox(height: 16),

                // Failure Buffer Slider
                _buildSliderRow(
                  title: 'Failure & Purge Risk Buffer',
                  value: state.failureBufferPercent,
                  unit: '%',
                  min: 0.0,
                  max: 30.0,
                  divisions: 30,
                  color: AppTheme.accentCoral,
                  onChanged: (v) => notifier.updateParams(failureBuffer: v),
                ),
                const SizedBox(height: 16),

                // Labor Minutes Slider
                _buildSliderRow(
                  title: 'Post-Processing & Setup Labor',
                  value: state.operatorLaborMinutes,
                  unit: 'mins',
                  min: 0.0,
                  max: 120.0,
                  divisions: 24,
                  color: AppTheme.accentAmber,
                  onChanged: (v) => notifier.updateParams(laborMins: v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Apply to Project button
          if (projectsState.projects.isNotEmpty)
            ExpressiveCard(
              child: Row(
                children: [
                  const Icon(Icons.bookmark_add_outlined, color: AppTheme.primaryCyan),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Apply this estimate (hours & filament) to an active project',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  PopupMenuButton<String>(
                    child: ElevatedButton(
                      onPressed: null,
                      child: const Text('Apply to Project ▾'),
                    ),
                    itemBuilder: (ctx) => projectsState.projects
                        .map(
                          (p) => PopupMenuItem(
                            value: p.id,
                            child: Text(p.title),
                          ),
                        )
                        .toList(),
                    onSelected: (projId) async {
                      final p = ref
                          .read(projectProvider.notifier)
                          .getProjectById(projId);
                      if (p != null) {
                        await ref.read(projectProvider.notifier).addOrder(
                              projId,
                              OrderItem(
                                description:
                                    '${state.selectedFilament.name} 3D Print (${state.partWeightGrams.toStringAsFixed(0)}g, ${state.printTimeHours.toStringAsFixed(1)}h)',
                                price: state.totalNetCost,
                                delivered: true,
                              ),
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Updated "${p.title}" with estimate!'),
                              backgroundColor: AppTheme.accentEmerald,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCostPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String title,
    required double value,
    required String unit,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              '${value.toStringAsFixed(value < 10 && unit != 'mins' ? 1 : 0)} $unit',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
