import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/task_item.dart';
import '../../models/voice_note.dart';
import '../../models/activity_log.dart';
import '../../models/downtime_event.dart';
import '../../providers/project_provider.dart';
import '../../services/sync_service.dart';
import '../../utils/text_utils.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';

part 'tasks_calendar_parts/dialogs.dart';
part 'tasks_calendar_parts/views.dart';

class TasksCalendarScreen extends ConsumerStatefulWidget {
  const TasksCalendarScreen({super.key});

  @override
  ConsumerState<TasksCalendarScreen> createState() =>
      _TasksCalendarScreenState();
}

class _TasksCalendarScreenState extends ConsumerState<TasksCalendarScreen> {
  /// `setState` is protected, so the part-file extensions rebuild through this.
  void _rebuild(VoidCallback fn) => setState(fn);

  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);
  int _filterMode = 0; // 0 = Incomplete Only, 1 = All Tasks, 2 = Pending Bottlenecks
  int _tab = 0; // 0 = Schedule, 1 = History

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

    // Date-attached notes (one per date)
    final notesByDate = <String, VoiceNote>{};
    for (final n in state.voiceNotes) {
      if (n.date != null) {
        notesByDate[DateFormat('yyyy-MM-dd').format(n.date!)] = n;
      }
    }
    final dayNote = notesByDate[selectedKey];

    // Downtime events keyed by day.
    final downtimesByDate = <String, List<DowntimeEvent>>{};
    for (final d in state.downtimes) {
      downtimesByDate
          .putIfAbsent(DateFormat('yyyy-MM-dd').format(d.date), () => [])
          .add(d);
    }
    final dayDowntimes = downtimesByDate[selectedKey] ?? [];

    // Historical log of things that happened on the selected day.
    final history = <({String icon, String text, DateTime time})>[];
    for (final n in state.voiceNotes) {
      if (DateUtils.isSameDay(n.timestamp, _selectedDate)) {
        history.add((
          icon: '📝',
          text: n.title + (n.transcript.isNotEmpty ? ': ${n.transcript}' : ''),
          time: n.timestamp,
        ));
      }
    }
    for (final p in state.projects) {
      for (final log in p.logs) {
        if (DateUtils.isSameDay(log.timestamp, _selectedDate)) {
          history.add((icon: '📋', text: '${p.title}: ${log.title}', time: log.timestamp));
        }
      }
      if (p.completedAt != null && DateUtils.isSameDay(p.completedAt!, _selectedDate)) {
        history.add((icon: '✅', text: '${p.title} → ${p.phase}', time: p.completedAt!));
      }
    }
    history.sort((a, b) => b.time.compareTo(a.time));

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
        title: Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: AppTheme.of(context).primary),
            SizedBox(width: 8),
            Text(
              'Calendar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Overdue tasks shortcut (count badge navigates to the list).
          Builder(builder: (context) {
            final overdueCount = state.overdueTasks.length;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: overdueCount == 0
                    ? 'No overdue tasks'
                    : '$overdueCount overdue task${overdueCount == 1 ? '' : 's'}',
                onPressed: () => context.push('/overdue'),
                icon: Badge(
                  isLabelVisible: overdueCount > 0,
                  label: Text('$overdueCount'),
                  backgroundColor: AppTheme.of(context).coral,
                  child: Icon(Icons.event_busy_rounded,
                      color: AppTheme.of(context).coral),
                ),
              ),
            );
          }),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Schedule', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: 1, label: Text('History', style: TextStyle(fontSize: 12))),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
        ),
        Expanded(
          child: _tab == 1
              ? _buildHistoryView(context, isDark)
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
          // ===== TASK LIST (top) =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.of(context).primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExpressiveBadge(
                      label: '${dayTasks.length} Scheduled',
                      color: AppTheme.of(context).primary,
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
          // ===== DAY NOTE =====
          if (dayNote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ExpressiveCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sticky_note_2_outlined,
                            size: 16, color: AppTheme.of(context).amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Day Note',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.of(context).amber)),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 16, color: AppTheme.of(context).primary),
                          tooltip: 'Edit Note',
                          onPressed: () => _showDateNoteDialog(_selectedDate),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 16, color: AppTheme.of(context).coral),
                          tooltip: 'Delete Note',
                          onPressed: () => _deleteDateNote(_selectedDate),
                        ),
                      ],
                    ),
                    if (dayNote.title.isNotEmpty) ...[
                      Text(dayNote.title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                    ],
                    SelectableText(
                      decodeUnicodeEscapes(dayNote.transcript),
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showDateNoteDialog(_selectedDate),
                  icon: Icon(Icons.note_add_outlined,
                      size: 16, color: AppTheme.of(context).amber),
                  label: Text('Add note for this day',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.of(context).amber)),
                ),
              ),
            ),

          const SizedBox(height: 6),

          if (dayTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.of(context).textSecondary
                          : AppTheme.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...dayTasks.map((entry) {
              final project = entry.project;
              final task = entry.task;

              return ExpressiveCard(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Project & Machine Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () =>
                              context.push('/projects/${project.id}'),
                          child: Row(
                            children: [
                              Icon(
                                Icons.precision_manufacturing_outlined,
                                size: 14,
                                color: AppTheme.of(context).primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                project.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.of(context).primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (project.machine.isNotEmpty)
                          ExpressiveBadge(
                            label: project.machine,
                            color: AppTheme.of(context).amber,
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
                          activeColor: AppTheme.of(context).emerald,
                          onChanged: (_) {
                            notifier.toggleTask(project.id, task.id);
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                  color: AppTheme.of(context).coral,
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
            }),

          // ===== DAY HISTORY =====
          if (history.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('History — ${DateFormat('MMM d').format(_selectedDate)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.of(context).primary)),
            ),
            const SizedBox(height: 6),
            ...history.map((h) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.icon, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(child: Text('${DateFormat('h:mm a').format(h.time)}  ${h.text}',
                    style: const TextStyle(fontSize: 12, height: 1.3))),
              ]),
            )),
            const SizedBox(height: 6),
          ],

          // ===== MACHINE DOWNTIME =====
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Expanded(child: Text('Machine Downtime', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.of(context).coral))),
              TextButton.icon(
                onPressed: () => _showDowntimeDialog(_selectedDate),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: const EdgeInsets.symmetric(horizontal: 6)),
              ),
            ]),
          ),
          if (dayDowntimes.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Text('No planned downtime. Tap Add to schedule maintenance.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            )
          else
            ...dayDowntimes.map((d) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: InkWell(
                onTap: () => _showMachineProjects(d),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.of(context).coral.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.build_circle_outlined, size: 16, color: AppTheme.of(context).coral),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${d.title}  •  ${d.machine}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      if (d.timeRange.isNotEmpty) Text(d.timeRange, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showDowntimeDialog(_selectedDate, existing: d), tooltip: 'Edit'),
                    IconButton(icon: Icon(Icons.delete_outline, size: 16, color: AppTheme.of(context).coral), onPressed: () => ref.read(projectProvider.notifier).deleteDowntime(d.id), tooltip: 'Delete'),
                  ]),
                ),
              ),
            )),

          const Divider(height: 28),

          // ===== CALENDAR (bottom) =====
          // Month Header Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
              notesByDate: notesByDate,
              downtimesByDate: downtimesByDate,
              isDark: isDark,
            ),
          ),
                  ],
                ),
        ),
      ]),
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
