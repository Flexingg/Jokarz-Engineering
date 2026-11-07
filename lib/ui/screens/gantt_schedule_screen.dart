import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/project.dart';
import '../../models/task_item.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';
import '../fluid/glass.dart';
import '../widgets/expressive_badge.dart';

enum GanttZoom {
  days('Day View (14 Days)', 14, 56.0),
  weeks('Week View (8 Weeks)', 56, 24.0),
  months('Month View (6 Months)', 180, 8.0);

  final String label;
  final int totalDays;
  final double dayColumnWidth;
  const GanttZoom(this.label, this.totalDays, this.dayColumnWidth);
}

class GanttScheduleScreen extends ConsumerStatefulWidget {
  const GanttScheduleScreen({super.key});

  @override
  ConsumerState<GanttScheduleScreen> createState() => _GanttScheduleScreenState();
}

class _GanttScheduleScreenState extends ConsumerState<GanttScheduleScreen> {
  GanttZoom _zoom = GanttZoom.days;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 2));
  String? _selectedMachine;
  bool _criticalPathOnly = false;
  final ScrollController _horizontalScroll = ScrollController();

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  void _shiftDays(int days) {
    setState(() {
      _startDate = _startDate.add(Duration(days: days));
    });
  }

  void _resetToToday() {
    setState(() {
      _startDate = DateTime.now().subtract(const Duration(days: 2));
    });
  }

  bool _isCritical(Project p, TaskItem t) {
    // Critical path:
    // 1. Task has "Pending downtime" or "Pending shutdown"
    // 2. Or project priority is #1
    // 3. Or task is scheduled in the past but not completed (bottleneck)
    final r = t.pendingReason.toLowerCase();
    if (r.contains('downtime') || r.contains('shutdown')) return true;
    if (p.priority == 1 && !t.isCompleted) return true;
    if (t.scheduledDate != null && t.scheduledDate!.isBefore(DateTime.now()) && !t.isCompleted) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(projectProvider);
    final projects = state.projects;

    // Collect all machines
    final allMachines = <String>{};
    for (final p in projects) {
      if (p.machine.isNotEmpty) allMachines.add(p.machine);
    }
    final machineList = allMachines.toList()..sort();

    // Filter projects & tasks
    final visibleProjects = projects.where((p) {
      if (_selectedMachine != null && p.machine != _selectedMachine) return false;
      return true;
    }).toList();

    final daysCount = _zoom.totalDays;
    final colW = _zoom.dayColumnWidth;
    final totalTimelineWidth = daysCount * colW;

    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.timeline_rounded, color: colors.primary),
            const SizedBox(width: 8),
            const Text(
              'Shutdown & Overhaul Gantt Scheduler',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Go to Today',
            icon: const Icon(Icons.today_rounded),
            onPressed: _resetToToday,
          ),
          IconButton(
            tooltip: 'Shift Backward',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => _shiftDays(-7),
          ),
          IconButton(
            tooltip: 'Shift Forward',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _shiftDays(7),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Zoom Picker
                SegmentedButton<GanttZoom>(
                  segments: GanttZoom.values.map((z) {
                    return ButtonSegment(
                      value: z,
                      label: Text(z == GanttZoom.days ? 'Days' : (z == GanttZoom.weeks ? 'Weeks' : 'Months'), style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  selected: {_zoom},
                  onSelectionChanged: (s) => setState(() => _zoom = s.first),
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),

                // Machine Filter Dropdown
                DropdownButton<String?>(
                  value: _selectedMachine,
                  hint: const Text('All Plant Machines', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Plant Machines', style: TextStyle(fontSize: 12)),
                    ),
                    ...machineList.map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m, style: const TextStyle(fontSize: 12)),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedMachine = val),
                ),

                // Critical Path Toggle Chip
                FilterChip(
                  label: const Text('Critical Path Only', style: TextStyle(fontSize: 12)),
                  selected: _criticalPathOnly,
                  onSelected: (val) => setState(() => _criticalPathOnly = val),
                  avatar: Icon(Icons.warning_amber_rounded, size: 14, color: _criticalPathOnly ? colors.coral : colors.textSecondary),
                  selectedColor: colors.coral.withAlpha(40),
                ),

                const Spacer(),

                // Date Range Label
                Text(
                  '${DateFormat("MMM d, y").format(_startDate)} – ${DateFormat("MMM d, y").format(_startDate.add(Duration(days: daysCount)))}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textSecondary),
                ),
              ],
            ),
          ),

          // Main Gantt Matrix
          Expanded(
            child: visibleProjects.isEmpty
                ? Center(
                    child: Text('No active projects or tasks for selected filter.', style: TextStyle(color: colors.textSecondary)),
                  )
                : Row(
                    children: [
                      // Left fixed pane: Project & Task Descriptions
                      SizedBox(
                        width: 280,
                        child: ListView.builder(
                          itemCount: visibleProjects.length,
                          itemBuilder: (context, pIndex) {
                            final p = visibleProjects[pIndex];
                            var tasks = p.tasks;
                            if (_criticalPathOnly) {
                              tasks = tasks.where((t) => _isCritical(p, t)).toList();
                            }
                            if (tasks.isEmpty && _criticalPathOnly) return const SizedBox.shrink();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Project Header
                                InkWell(
                                  onTap: () => context.push('/projects/${p.id}'),
                                  child: Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    color: colors.surfaceVariant.withAlpha(120),
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        ExpressiveBadge(
                                          label: '#${p.priority}',
                                          color: p.priority == 1 ? colors.coral : colors.primary,
                                          fontSize: 9,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            p.title,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (p.machine.isNotEmpty)
                                          Text(
                                            p.machine,
                                            style: TextStyle(fontSize: 9, color: colors.textSecondary),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Task rows
                                ...tasks.map((t) {
                                  final isCrit = _isCritical(p, t);
                                  return Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: colors.border.withAlpha(50))),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        Icon(
                                          t.isCompleted
                                              ? Icons.check_circle_rounded
                                              : (isCrit ? Icons.warning_rounded : Icons.radio_button_unchecked),
                                          size: 13,
                                          color: t.isCompleted
                                              ? colors.emerald
                                              : (isCrit ? colors.coral : colors.textSecondary),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            t.description,
                                            style: TextStyle(
                                              fontSize: 11,
                                              decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                                              color: isCrit ? colors.coral : (t.isCompleted ? colors.textSecondary : colors.textPrimary),
                                              fontWeight: isCrit ? FontWeight.bold : FontWeight.normal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),

                      // Vertical Divider
                      Container(width: 1, color: colors.border),

                      // Right scrollable timeline canvas
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _horizontalScroll,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: totalTimelineWidth,
                            child: Column(
                              children: [
                                // Timeline Date Header
                                Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: colors.cardBackground,
                                    border: Border(bottom: BorderSide(color: colors.border)),
                                  ),
                                  child: Row(
                                    children: List.generate(daysCount, (i) {
                                      final day = _startDate.add(Duration(days: i));
                                      final isToday = day.year == todayClean.year && day.month == todayClean.month && day.day == todayClean.day;
                                      final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

                                      return Container(
                                        width: colW,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isToday
                                              ? colors.primary.withAlpha(35)
                                              : (isWeekend ? colors.cardBackground.withAlpha(180) : null),
                                          border: Border(right: BorderSide(color: colors.border.withAlpha(50))),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              DateFormat('E').format(day).substring(0, 1),
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isToday ? colors.primary : colors.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              DateFormat('d').format(day),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                                color: isToday ? colors.primary : colors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                                ),

                                // Timeline Task Bars Body
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: visibleProjects.length,
                                    itemBuilder: (context, pIndex) {
                                      final p = visibleProjects[pIndex];
                                      var tasks = p.tasks;
                                      if (_criticalPathOnly) {
                                        tasks = tasks.where((t) => _isCritical(p, t)).toList();
                                      }
                                      if (tasks.isEmpty && _criticalPathOnly) return const SizedBox.shrink();

                                      return Column(
                                        children: [
                                          // Project header separator row
                                          Container(
                                            height: 38,
                                            color: colors.surfaceVariant.withAlpha(120),
                                            decoration: BoxDecoration(
                                              border: Border(bottom: BorderSide(color: colors.border.withAlpha(40))),
                                            ),
                                          ),
                                          // Task timeline bars
                                          ...tasks.map((t) {
                                            final isCrit = _isCritical(p, t);
                                            final sched = t.scheduledDate;

                                            return Container(
                                              height: 36,
                                              decoration: BoxDecoration(
                                                border: Border(bottom: BorderSide(color: colors.border.withAlpha(50))),
                                              ),
                                              child: Stack(
                                                children: [
                                                  // Grid day lines
                                                  Row(
                                                    children: List.generate(daysCount, (i) {
                                                      final day = _startDate.add(Duration(days: i));
                                                      final isToday = day.year == todayClean.year && day.month == todayClean.month && day.day == todayClean.day;
                                                      return Container(
                                                        width: colW,
                                                        decoration: BoxDecoration(
                                                          color: isToday ? colors.primary.withAlpha(15) : null,
                                                          border: Border(right: BorderSide(color: colors.border.withAlpha(30))),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                  // Render task bar if scheduled within visible window
                                                  if (sched != null) ...[
                                                    Builder(
                                                      builder: (context) {
                                                        final diffDays = sched.difference(_startDate).inDays;
                                                        if (diffDays >= -2 && diffDays < daysCount) {
                                                          final leftPos = (diffDays.clamp(0, daysCount)) * colW;
                                                          final barWidth = (colW * 2.5).clamp(24.0, 160.0);

                                                          final barColor = t.isCompleted
                                                              ? colors.emerald
                                                              : (isCrit ? colors.coral : colors.primary);

                                                          return Positioned(
                                                            left: leftPos,
                                                            top: 6,
                                                            height: 24,
                                                            width: barWidth,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                                              decoration: BoxDecoration(
                                                                color: barColor.withAlpha(220),
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(color: barColor),
                                                                boxShadow: [
                                                                  if (isCrit)
                                                                    BoxShadow(color: colors.coral.withAlpha(90), blurRadius: 4),
                                                                ],
                                                              ),
                                                              alignment: Alignment.centerLeft,
                                                              child: Text(
                                                                t.pendingReason.isNotEmpty ? t.pendingReason : (t.isCompleted ? 'Done' : 'Scheduled'),
                                                                style: const TextStyle(
                                                                  fontSize: 9,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Colors.white,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                        return const SizedBox.shrink();
                                                      },
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
