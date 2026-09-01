import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/machine_asset.dart';
import '../../models/downtime_event.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';

class MachineDetailScreen extends ConsumerStatefulWidget {
  final String machineName;

  const MachineDetailScreen({super.key, required this.machineName});

  @override
  ConsumerState<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends ConsumerState<MachineDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddDowntimeDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();

    showDialog(

      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Downtime on ${widget.machineName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Downtime Reason / Root Cause *',
                hintText: 'e.g. Broken timing belt, jammed diverter arm',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              final d = DowntimeEvent(
                machine: widget.machineName,
                title: reason,
                date: DateTime.now(),
              );
              await ref.read(projectProvider.notifier).addDowntime(d);
              if (ctx.mounted) Navigator.pop(ctx);
            },

            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Downtime'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, y');

    // Find the specific machine asset
    final asset = state.machineAssets.firstWhere(
      (m) => m.name.toLowerCase() == widget.machineName.toLowerCase(),
      orElse: () => MachineAsset(name: widget.machineName),
    );

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.machineName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert_rounded, color: AppTheme.accentCoral),
            tooltip: 'Log Downtime',
            onPressed: () => _showAddDowntimeDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.primaryCyan),
            tooltip: 'New Project on Machine',
            onPressed: () => context.push('/projects/new', extra: {
              'initialTitle': '${widget.machineName} - ',
            }),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'Projects (${asset.activeProjects.length})'),
            Tab(text: 'Spare Parts / POs (${asset.openOrders.length})'),
            Tab(text: 'Downtime (${asset.downtimes.length})'),
            Tab(text: 'Notes & Photos (${asset.notes.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Machine Status & Summary Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${asset.downtimes.length} Downtime Events',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),


          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Projects Tab
                asset.activeProjects.isEmpty && asset.completedProjects.isEmpty
                    ? const Center(child: Text('No projects linked to this machine.'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (asset.activeProjects.isNotEmpty) ...[
                            const Text('Active Projects',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            ...asset.activeProjects.map((p) => ExpressiveCard(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  onTap: () => context.push('/projects/${p.id}'),
                                  child: Row(
                                    children: [
                                      ExpressiveBadge(
                                        label: '#${p.priority}',
                                        color: AppTheme.primaryCyan,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.title,
                                                style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Text('${p.category.label} • ${p.phase}',
                                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                                    ],
                                  ),
                                )),
                          ],
                          if (asset.completedProjects.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text('Completed Projects',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                            const SizedBox(height: 8),
                            ...asset.completedProjects.map((p) => ExpressiveCard(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  onTap: () => context.push('/projects/${p.id}'),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: AppTheme.accentEmerald, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          p.title,
                                          style: const TextStyle(
                                            decoration: TextDecoration.lineThrough,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ],
                      ),

                // 2. Spare Parts / Orders Tab
                asset.openOrders.isEmpty
                    ? const Center(child: Text('No orders or spare parts linked to this machine.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: asset.openOrders.length,
                        itemBuilder: (context, index) {
                          final o = asset.openOrders[index];
                          return ExpressiveCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        o.description,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text(
                                      currency.format(o.price),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    if (o.po.isNotEmpty)
                                      ExpressiveBadge(label: 'PO: ${o.po}', color: AppTheme.primaryCyan, fontSize: 10),
                                    if (o.pr.isNotEmpty)
                                      ExpressiveBadge(label: 'PR: ${o.pr}', color: Colors.grey, fontSize: 10),
                                    if (o.vendorName.isNotEmpty)
                                      ExpressiveBadge(label: o.vendorName, color: AppTheme.accentAmber, fontSize: 10),
                                    if (o.eta != null)
                                      ExpressiveBadge(
                                        label: 'ETA: ${dateFormat.format(o.eta!)}',
                                        color: o.delivered ? AppTheme.accentEmerald : AppTheme.accentAmber,
                                        fontSize: 10,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // 3. Downtime Tab
                asset.downtimes.isEmpty
                    ? const Center(child: Text('No downtime events recorded for this machine.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: asset.downtimes.length,
                        itemBuilder: (context, index) {
                          final d = asset.downtimes[index];
                          return ExpressiveCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.report_problem_rounded,
                                  color: AppTheme.accentCoral,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(
                                        '${dateFormat.format(d.date)}${d.timeRange.isNotEmpty ? " • ${d.timeRange}" : ""}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),

                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  onPressed: () =>
                                      ref.read(projectProvider.notifier).deleteDowntime(d.id),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // 4. Notes & Photos Tab
                asset.notes.isEmpty
                    ? const Center(child: Text('No field notes or photos linked to this machine.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: asset.notes.length,
                        itemBuilder: (context, index) {
                          final n = asset.notes[index];
                          return ExpressiveCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(n.transcript, style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 6),
                                Text(dateFormat.format(n.timestamp),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
