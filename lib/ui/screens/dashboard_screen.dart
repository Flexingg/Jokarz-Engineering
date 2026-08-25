import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/voice_memo_modal.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    if (state.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryCyan),
        ),
      );
    }

    final totalBOMCost = state.projects.fold(
      0.0,
      (prev, p) => prev + p.totalBOMCost,
    );
    final activeCount = state.projects
        .where((p) => p.status != ProjectStatus.complete && p.status != ProjectStatus.archived)
        .length;
    final allBomItems = state.projects.expand((p) => p.bom).toList();
    final purchasedRatio = allBomItems.isEmpty
        ? 0.0
        : (allBomItems.where((i) => i.isPurchased).length / allBomItems.length);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.precision_manufacturing_rounded, color: AppTheme.primaryCyan),
            SizedBox(width: 8),
            Text(
              'Jokarz Engineering',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: AppTheme.accentAmber),
            tooltip: 'Dictate Workshop Note',
            onPressed: () => VoiceMemoModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryCyan),
            tooltip: 'New Project',
            onPressed: () => context.push('/projects/new'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Engineering Banner
            _buildWelcomeBanner(context, activeCount),
            const SizedBox(height: 24),

            // Top Quick Stat Metrics Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: isWide ? 1.8 : 1.4,
                  children: [
                    _buildStatCard(
                      context,
                      title: 'Active Builds',
                      value: '$activeCount',
                      subtitle: '${state.projects.length} Total Projects',
                      icon: Icons.architecture_rounded,
                      color: AppTheme.primaryCyan,
                    ),
                    _buildStatCard(
                      context,
                      title: 'Total BOM Cost',
                      value: currency.format(totalBOMCost),
                      subtitle: '${allBomItems.length} Sourced Parts',
                      icon: Icons.receipt_long_rounded,
                      color: AppTheme.accentEmerald,
                    ),
                    _buildStatCard(
                      context,
                      title: 'Sourcing Progress',
                      value: '${(purchasedRatio * 100).toStringAsFixed(0)}%',
                      subtitle: '${allBomItems.where((i) => i.isPurchased).length} of ${allBomItems.length} Procured',
                      icon: Icons.inventory_2_rounded,
                      color: AppTheme.accentAmber,
                    ),
                    _buildStatCard(
                      context,
                      title: 'Voice Field Logs',
                      value: '${state.voiceNotes.length}',
                      subtitle: 'Hands-free Memos',
                      icon: Icons.mic_rounded,
                      color: AppTheme.accentPurple,
                      onTap: () => context.go('/voice-notes'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),

            // Quick Workbench Tool Launchers
            const Text(
              'Workbench Tools & Calculators',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildToolLaunchers(context),
            const SizedBox(height: 28),

            // Active Projects Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Projects & CAD Builds',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/projects'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Projects List or Grid
            if (state.projects.isEmpty)
              ExpressiveCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.build_circle_outlined, size: 48, color: AppTheme.primaryCyan),
                        const SizedBox(height: 12),
                        const Text(
                          'No engineering projects created yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Start tracking your 3D prints, electronics, and machining builds.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/projects/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create First Project'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...state.projects.take(4).map((p) => _buildProjectTile(context, p)),

            const SizedBox(height: 28),

            // Recent Voice Notes & Logs Stream
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Voice Notes & Workshop Memos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/voice-notes'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('All Memos'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (state.voiceNotes.isEmpty)
              ExpressiveCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mic_none, color: AppTheme.accentAmber),
                        const SizedBox(width: 8),
                        const Text('No voice notes recorded yet. Tap microphone to dictate!'),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...state.voiceNotes.take(3).map(
                    (vn) => ExpressiveCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.mic, color: AppTheme.accentAmber, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      vn.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      DateFormat('MMM d, h:mm a').format(vn.timestamp),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  vn.transcript,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, int activeCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.8),
            AppTheme.darkSurfaceCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.primaryCyan.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RANDALL ENGINEERING WORKSHOP',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryCyan,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Jokarz Engineering Hub',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'CAD & 3D Print Estimates • Electronics & Hardware Calculators • Voice Lab Logs',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
              foregroundColor: Colors.black87,
            ),
            onPressed: () => context.push('/projects/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Project'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ExpressiveCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.lightTextPrimary,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolLaunchers(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isWide ? 2.3 : 1.8,
          children: [
            _buildLauncherTile(
              context,
              title: '3D Print & Slicer Cost',
              desc: 'Filament & energy calculator',
              icon: Icons.view_in_ar_rounded,
              color: AppTheme.primaryCyan,
              onTap: () => context.go('/workbench?tab=0'),
            ),
            _buildLauncherTile(
              context,
              title: 'Fastener & Drill Chart',
              desc: 'Metric/Imperial tap specs',
              icon: Icons.settings_outlined,
              color: AppTheme.accentEmerald,
              onTap: () => context.go('/workbench?tab=1'),
            ),
            _buildLauncherTile(
              context,
              title: 'Electronics Workbench',
              desc: 'Ohm, Resistor color, AWG',
              icon: Icons.electric_bolt_rounded,
              color: AppTheme.accentAmber,
              onTap: () => context.go('/workbench?tab=2'),
            ),
            _buildLauncherTile(
              context,
              title: 'Unit & Fit Converter',
              desc: 'Length, Torque, ISO fits',
              icon: Icons.straighten_rounded,
              color: AppTheme.accentPurple,
              onTap: () => context.go('/workbench?tab=3'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLauncherTile(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ExpressiveCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectTile(BuildContext context, Project project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return ExpressiveCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push('/projects/${project.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    ExpressiveBadge(
                      label: project.category.label,
                      color: AppTheme.primaryCyan,
                      fontSize: 10,
                    ),
                    const SizedBox(width: 8),
                    ExpressiveBadge(
                      label: project.status.label,
                      color: project.status == ProjectStatus.complete
                          ? AppTheme.accentEmerald
                          : AppTheme.accentAmber,
                      fontSize: 10,
                    ),
                  ],
                ),
              ),
              Text(
                currency.format(project.totalBOMCost),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            project.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // BOM & Timeline Progress
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BOM Sourcing (${project.purchasedItemCount}/${project.bom.length} items)',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          '${(project.bomCompletionRatio * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: project.bomCompletionRatio,
                        backgroundColor: isDark ? AppTheme.darkSurfaceHighlight : AppTheme.lightSurfaceHighlight,
                        color: AppTheme.accentEmerald,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.chevron_right, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            ],
          ),
        ],
      ),
    );
  }
}
