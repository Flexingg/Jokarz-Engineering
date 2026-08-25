import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/task_item.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';

class TasksCalendarScreen extends ConsumerStatefulWidget {
  const TasksCalendarScreen({super.key});

  @override
  ConsumerState<TasksCalendarScreen> createState() =>
      _TasksCalendarScreenState();
}

class _TasksCalendarScreenState extends ConsumerState<TasksCalendarScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);
  int _filterMode = 0; // 0 = Incomplete Only, 1 = All Tasks, 2 = Pending Bottlenecks

  void _prevMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final monthFormat = DateFormat('MMMM yyyy');

    // Collect all tasks paired with their parent project
    final allTaskEntries = <({Project project, TaskItem task})>[];
    for (final project in state.projects) {
      for (final task in project.tasks) {
        allTaskEntries.add((project: project, task: task));
      }
    }

    // Map tasks by date string (YYYY-MM-DD)
    final tasksByDate = <String, List<({Project project, TaskItem task})>>{};
    for (final entry in allTaskEntries) {
      if (entry.task.scheduledDate != null) {
        final dateKey =
            DateFormat('yyyy-MM-dd').format(entry.task.scheduledDate!);
        tasksByDate.putIfAbsent(dateKey, () => []).add(entry);
      }
    }

    final selectedKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    List<({Project project, TaskItem task})> dayTasks =
        tasksByDate[selectedKey] ?? [];

    if (_filterMode == 0) {
      dayTasks = dayTasks.where((e) => !e.task.isCompleted).toList();
    } else if (_filterMode == 2) {
      dayTasks = dayTasks
          .where((e) => e.task.pendingReason.isNotEmpty)
          .toList();
    }

    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Mon..7=Sun

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: AppTheme.primaryCyan),
            SizedBox(width: 8),
            Text(
              'Maintenance Schedule & Tasks',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Month Header Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _prevMonth,
                ),
                Text(
                  monthFormat.format(_currentMonth),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          // Days of Week Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: const [
                _DayOfWeekLabel('Mon'),
                _DayOfWeekLabel('Tue'),
                _DayOfWeekLabel('Wed'),
                _DayOfWeekLabel('Thu'),
                _DayOfWeekLabel('Fri'),
                _DayOfWeekLabel('Sat'),
                _DayOfWeekLabel('Sun'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Calendar Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildCalendarGrid(
              daysInMonth: daysInMonth,
              firstWeekday: firstWeekday,
              tasksByDate: tasksByDate,
              isDark: isDark,
            ),
          ),
          const Divider(height: 20),

          // Selected Day Header & Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryCyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExpressiveBadge(
                      label: '${dayTasks.length} Scheduled',
                      color: AppTheme.primaryCyan,
                      fontSize: 10,
                    ),
                  ],
                ),
                // Filter Dropdown
                DropdownButton<int>(
                  value: _filterMode,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Incomplete Only', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 1, child: Text('All Scheduled', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 2, child: Text('Has Pending Bottlecks', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _filterMode = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Task List for Selected Date
          Expanded(
            child: dayTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.event_available_rounded,
                          size: 44,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No maintenance tasks scheduled for ${DateFormat("MMM d").format(_selectedDate)}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assign scheduled dates to project tasks to track plant shutdowns and PMs.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: dayTasks.length,
                    itemBuilder: (context, index) {
                      final entry = dayTasks[index];
                      final project = entry.project;
                      final task = entry.task;

                      return ExpressiveCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Project & Machine Link
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                InkWell(
                                  onTap: () =>
                                      context.push('/projects/${project.id}'),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.precision_manufacturing_outlined,
                                        size: 14,
                                        color: AppTheme.primaryCyan,
                                      ),
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
                            const Divider(height: 12),

                            // Task Checkbox & Description
                            Row(
                              children: [
                                Checkbox(
                                  value: task.isCompleted,
                                  activeColor: AppTheme.accentEmerald,
                                  onChanged: (_) {
                                    notifier.toggleTask(project.id, task.id);
                                  },
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.description,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      if (task.pendingReason.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        ExpressiveBadge(
                                          label: '⏳ ${task.pendingReason}',
                                          color: AppTheme.accentCoral,
                                          fontSize: 10,
                                        ),
                                      ],
                                    ],
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
      ),
    );
  }

  Widget _buildCalendarGrid({
    required int daysInMonth,
    required int firstWeekday,
    required Map<String, List<({Project project, TaskItem task})>> tasksByDate,
    required bool isDark,
  }) {
    final totalCells = ((daysInMonth + firstWeekday - 1) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.25,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: totalCells,
      itemBuilder: (context, idx) {
        final dayNumber = idx - firstWeekday + 2;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox();
        }

        final cellDate =
            DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
        final dateKey = DateFormat('yyyy-MM-dd').format(cellDate);
        final tasksOnDay = tasksByDate[dateKey] ?? [];

        final isSelected = cellDate.year == _selectedDate.year &&
            cellDate.month == _selectedDate.month &&
            cellDate.day == _selectedDate.day;

        final isToday = cellDate.year == DateTime.now().year &&
            cellDate.month == DateTime.now().month &&
            cellDate.day == DateTime.now().day;

        final hasIncomplete = tasksOnDay.any((e) => !e.task.isCompleted);

        return InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: () => setState(() => _selectedDate = cellDate),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryCyan.withValues(alpha: 0.25)
                  : isToday
                      ? AppTheme.accentAmber.withValues(alpha: 0.15)
                      : (isDark
                          ? AppTheme.darkSurface
                          : AppTheme.lightSurface),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryCyan
                    : isToday
                        ? AppTheme.accentAmber
                        : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w900
                        : FontWeight.bold,
                    color: isSelected
                        ? AppTheme.primaryCyan
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                if (tasksOnDay.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: hasIncomplete
                          ? AppTheme.accentCoral
                          : AppTheme.accentEmerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DayOfWeekLabel extends StatelessWidget {
  final String label;
  const _DayOfWeekLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
