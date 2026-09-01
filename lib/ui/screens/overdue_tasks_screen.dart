import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/expressive_card.dart';

/// Lists every incomplete task whose scheduled date is before today, with a
/// one-click "make due today" action. Opened from the Maintenance Schedule &
/// Tasks calendar screen.
class OverdueTasksScreen extends ConsumerWidget {
  const OverdueTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);
    final overdue = state.overdueTasks;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final today = DateUtils.dateOnly(DateTime.now());

    int daysOverdue(DateTime d) =>
        today.difference(DateUtils.dateOnly(d)).inDays;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.event_busy_rounded, color: AppTheme.accentCoral),
            SizedBox(width: 8),
            Text('Overdue Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: overdue.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.task_alt_rounded,
                      size: 48, color: AppTheme.accentEmerald),
                  const SizedBox(height: 8),
                  const Text('Nothing overdue 🎉',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('All scheduled tasks are on time.',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back to Calendar'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: overdue.length,
              itemBuilder: (context, i) {
                final entry = overdue[i];
                final project = entry.project;
                final task = entry.task;
                final overdueDays = daysOverdue(task.scheduledDate!);

                return ExpressiveCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project & machine
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () =>
                                context.push('/projects/${project.id}'),
                            child: Row(
                              children: [
                                const Icon(Icons.precision_manufacturing_outlined,
                                    size: 14, color: AppTheme.primaryCyan),
                                const SizedBox(width: 6),
                                Text(
                                  project.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryCyan,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (project.machine.isNotEmpty)
                            ExpressiveBadge(
                              label: project.machine,
                              color: AppTheme.accentAmber,
                              fontSize: 10,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Task description
                      Text(task.description,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      // Overdue meta + action
                      Row(
                        children: [
                          ExpressiveBadge(
                            label:
                                '${DateFormat('MMM d').format(task.scheduledDate!)} · $overdueDays day${overdueDays == 1 ? '' : 's'} overdue',
                            color: AppTheme.accentCoral,
                            fontSize: 10,
                          ),
                          if (task.pendingReason.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            ExpressiveBadge(
                              label: '⏳ ${task.pendingReason}',
                              color: AppTheme.accentCoral,
                              fontSize: 10,
                            ),
                          ],
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () async {
                              await notifier.rescheduleTaskToToday(
                                  project.id, task.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Due date moved to today: ${task.description}'),
                                    backgroundColor: AppTheme.accentEmerald,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.today_rounded, size: 16),
                            label: const Text('Set Due Today',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  AppTheme.accentEmerald.withValues(alpha: 0.15),
                              foregroundColor: AppTheme.accentEmerald,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
