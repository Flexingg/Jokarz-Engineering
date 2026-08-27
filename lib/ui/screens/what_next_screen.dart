import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';

/// In-memory snooze set: project IDs snoozed until tomorrow.
/// Resets on app restart (intentional for v1.0.3).
final _snoozedTodayProvider = StateProvider<Set<String>>((ref) => {});

class WhatNextScreen extends ConsumerStatefulWidget {
  const WhatNextScreen({super.key});

  @override
  ConsumerState<WhatNextScreen> createState() => _WhatNextScreenState();
}

class _WhatNextScreenState extends ConsumerState<WhatNextScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  AnimationController? _swipeController;
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _swipeController?.dispose();
    super.dispose();
  }

  List<Project> _getQueue() {
    final state = ref.read(projectProvider);
    final snoozed = ref.read(_snoozedTodayProvider);
    return state.queuedProjects.where((p) => !snoozed.contains(p.id)).toList();
  }

  Future<void> _markActioned(Project project) async {
    await ref.read(projectProvider.notifier).markProjectActioned(project.id);
    if (mounted) setState(() => _currentIndex = 0);
  }

  void _snooze(Project project) {
    ref.read(_snoozedTodayProvider.notifier).update((s) => {...s, project.id});
    if (mounted) setState(() => _currentIndex = 0);
  }

  Color _actionColor(int days) {
    if (days == 0) return AppTheme.accentEmerald;
    if (days <= 3) return AppTheme.accentAmber;
    return Colors.red.shade400;
  }

  String _actionLabel(int days) {
    if (days == 0) return 'Today';
    if (days == 1) return '1 day ago';
    return ' days ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final queue = _getQueue();

    return Scaffold(
      appBar: AppBar(
        title: const Text('What\'s Next?', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: queue.isEmpty
          ? _buildEmptyState(theme)
          : _buildCardStack(context, theme, isDark, queue),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✅', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 20),
          Text(
            'All caught up!',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Every active project has been actioned today.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCardStack(BuildContext context, ThemeData theme, bool isDark, List<Project> queue) {
    final project = queue[_currentIndex];
    final days = project.daysSinceLastAction;
    final dateFormat = DateFormat('MMM d');
    final nextTask = project.nextPendingTask;
    final total = queue.length;
    final remaining = total - _currentIndex;

    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$remaining remaining',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              Text(
                ' / ',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: (_currentIndex + 1) / total,
          backgroundColor: Colors.grey.withValues(alpha: 0.2),
          color: AppTheme.primaryCyan,
          minHeight: 3,
        ),
        const SizedBox(height: 16),

        // Swipeable card
        Expanded(
          child: GestureDetector(
            onHorizontalDragStart: (_) => setState(() { _isDragging = true; _dragOffset = 0; }),
            onHorizontalDragUpdate: (d) => setState(() => _dragOffset += d.delta.dx),
            onHorizontalDragEnd: (d) {
              setState(() => _isDragging = false);
              if (_dragOffset > 80) {
                _markActioned(project);
              } else if (_dragOffset < -80) {
                _snooze(project);
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            child: Transform.translate(
              offset: Offset(_isDragging ? _dragOffset : 0, 0),
              child: Transform.rotate(
                angle: (_isDragging ? _dragOffset : 0) * 0.003,
                child: _buildProjectCard(context, theme, isDark, project, days, nextTask, dateFormat),
              ),
            ),
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Row(
            children: [
              // Skip
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _snooze(project),
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.grey),
                  label: const Text('Skip Today', style: TextStyle(color: Colors.grey)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Tap to open
              IconButton(
                onPressed: () => context.push('/projects/'),
                icon: const Icon(Icons.open_in_new_rounded),
                tooltip: 'Open project',
                color: AppTheme.primaryCyan,
              ),
              const SizedBox(width: 16),
              // Actioned
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _markActioned(project),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Worked on It'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProjectCard(BuildContext context, ThemeData theme, bool isDark,
      Project project, int days, dynamic nextTask, DateFormat dateFormat) {
    final actionColor = _actionColor(days);
    final actionLabel = _actionLabel(days);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 8,
        shadowColor: AppTheme.primaryCyan.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/projects/'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Priority + Category row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#${project.priority} — $actionLabel',
                        style: const TextStyle(
                          color: AppTheme.primaryCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _categoryColor(project.category).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        project.category.label,
                        style: TextStyle(
                          color: _categoryColor(project.category),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Phase chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        project.phase,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  project.title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (project.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    project.description,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                // Machine
                if (project.machine.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.precision_manufacturing_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          children: project.machineList.map((m) => Chip(
                            label: Text(m, style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Last action badge
                Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16, color: actionColor),
                    const SizedBox(width: 6),
                    Text(
                      'Last action: ',
                      style: TextStyle(color: actionColor, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),

                // Next task
                if (nextTask != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.task_alt_rounded, size: 16, color: AppTheme.primaryCyan),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Next: ',
                          style: const TextStyle(fontSize: 13, color: AppTheme.primaryCyan),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (nextTask.scheduledDate != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          dateFormat.format(nextTask.scheduledDate!),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ],

                const Spacer(),
                // Swipe hint
                Center(
                  child: Text(
                    '← Skip     Worked on It →',
                    style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _categoryColor(ProjectCategory cat) {
    switch (cat) {
      case ProjectCategory.maintenance:
        return AppTheme.primaryCyan;
      case ProjectCategory.kaizen:
        return AppTheme.accentEmerald;
      case ProjectCategory.capital:
        return AppTheme.accentAmber;
    }
  }
}
