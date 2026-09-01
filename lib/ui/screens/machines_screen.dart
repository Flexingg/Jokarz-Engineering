import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/machine_asset.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';

class MachinesScreen extends ConsumerStatefulWidget {
  const MachinesScreen({super.key});

  @override
  ConsumerState<MachinesScreen> createState() => _MachinesScreenState();
}

class _MachinesScreenState extends ConsumerState<MachinesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    var assets = state.machineAssets;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      assets = assets.where((m) => m.name.toLowerCase().contains(q)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.precision_manufacturing_rounded, color: AppTheme.primaryCyan),
            SizedBox(width: 8),
            Text('Plant Machines & Lines', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search plant lines, machines, equipment...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
          ),

          // Machine Asset List
          Expanded(
            child: assets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.precision_manufacturing_outlined, size: 54, color: Colors.grey),
                        const SizedBox(height: 14),
                        const Text(
                          'No Machines Found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Assign machines to your projects (e.g. "Line 1 / Filler")\nto automatically track machine health, downtime, and spare parts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: assets.length,
                    itemBuilder: (context, index) {
                      final asset = assets[index];
                      return _MachineAssetCard(
                        asset: asset,
                        currency: currency,
                        onTap: () => context.push('/machines/${Uri.encodeComponent(asset.name)}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MachineAssetCard extends StatelessWidget {
  final MachineAsset asset;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _MachineAssetCard({
    required this.asset,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (asset.status) {
      case MachineStatus.breakdown:
        statusColor = AppTheme.accentCoral;
        statusLabel = 'BREAKDOWN / DOWN';
        statusIcon = Icons.warning_rounded;
        break;
      case MachineStatus.inMaintenance:
        statusColor = AppTheme.accentAmber;
        statusLabel = 'IN MAINTENANCE';
        statusIcon = Icons.build_rounded;
        break;
      case MachineStatus.operational:
        statusColor = AppTheme.accentEmerald;
        statusLabel = 'OPERATIONAL';
        statusIcon = Icons.check_circle_rounded;
        break;
    }

    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.precision_manufacturing_rounded, color: AppTheme.primaryCyan, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        asset.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ExpressiveBadge(
                label: statusLabel,
                icon: statusIcon,
                color: statusColor,
                fontSize: 10,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metrics strip
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ExpressiveBadge(
                label: '${asset.activeProjects.length} Active Projects',
                icon: Icons.engineering_rounded,
                color: AppTheme.primaryCyan,
                fontSize: 11,
              ),
              if (asset.openOrders.isNotEmpty)
                ExpressiveBadge(
                  label: '${asset.openOrders.length} Orders (${currency.format(asset.totalOpenOrderSpend)})',
                  icon: Icons.local_shipping_outlined,
                  color: AppTheme.accentAmber,
                  fontSize: 11,
                ),
              if (asset.downtimes.isNotEmpty)
                ExpressiveBadge(
                  label: '${asset.totalDowntimeEvents} Downtimes',
                  icon: Icons.timer_outlined,
                  color: AppTheme.accentCoral,
                  fontSize: 11,
                ),

              if (asset.notes.isNotEmpty)
                ExpressiveBadge(
                  label: '${asset.notes.length} Notes',
                  icon: Icons.notes_rounded,
                  color: Colors.purpleAccent,
                  fontSize: 11,
                ),
            ],
          ),

          if (asset.subAssemblies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Sub-Assemblies: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Expanded(
                  child: Text(
                    asset.subAssemblies.join(' • '),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
