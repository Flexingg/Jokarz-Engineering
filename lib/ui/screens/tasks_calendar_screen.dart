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
        title: const Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: AppTheme.primaryCyan),
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
                  backgroundColor: AppTheme.accentCoral,
                  child: const Icon(Icons.event_busy_rounded,
                      color: AppTheme.accentCoral),
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
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 16, color: AppTheme.accentAmber),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('Day Note',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentAmber)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 16, color: AppTheme.primaryCyan),
                          tooltip: 'Edit Note',
                          onPressed: () => _showDateNoteDialog(_selectedDate),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 16, color: AppTheme.accentCoral),
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
                  icon: const Icon(Icons.note_add_outlined,
                      size: 16, color: AppTheme.accentAmber),
                  label: const Text('Add note for this day',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.accentAmber)),
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
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
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
            }),

          // ===== DAY HISTORY =====
          if (history.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('History — ${DateFormat('MMM d').format(_selectedDate)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primaryCyan)),
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
              const Expanded(child: Text('Machine Downtime', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.accentCoral))),
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
                  decoration: BoxDecoration(color: AppTheme.accentCoral.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.build_circle_outlined, size: 16, color: AppTheme.accentCoral),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${d.title}  •  ${d.machine}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      if (d.timeRange.isNotEmpty) Text(d.timeRange, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showDowntimeDialog(_selectedDate, existing: d), tooltip: 'Edit'),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.accentCoral), onPressed: () => ref.read(projectProvider.notifier).deleteDowntime(d.id), tooltip: 'Delete'),
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

  Future<void> _showDowntimeDialog(DateTime date, {DowntimeEvent? existing}) async {
    final projects = ref.read(projectProvider).projects;
    final machines = <String>{...projects.map((p) => p.machine).where((m) => m.isNotEmpty)};
    final machineCtrl = TextEditingController(text: existing?.machine ?? (machines.isNotEmpty ? machines.first : ''));
    final titleCtrl = TextEditingController(text: existing?.title ?? 'Maintenance');
    final timeCtrl = TextEditingController(text: existing?.timeRange ?? '');
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(existing == null ? 'Add Downtime' : 'Edit Downtime'),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: machineCtrl.text.isEmpty ? null : machineCtrl.text,
          items: machines.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => machineCtrl.text = v ?? '',
          decoration: const InputDecoration(labelText: 'Machine / Line', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. PM - Packer 621', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Time range (optional)', hintText: 'e.g. 07:00 - 11:00', isDense: true)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final machine = machineCtrl.text.trim();
          if (machine.isEmpty) return;
          final ev = DowntimeEvent(
            id: existing?.id,
            machine: machine,
            title: titleCtrl.text.trim().isEmpty ? 'Maintenance' : titleCtrl.text.trim(),
            date: date,
            timeRange: timeCtrl.text.trim(),
          );
          final n = ref.read(projectProvider.notifier);
          if (existing == null) { await n.addDowntime(ev); } else { await n.updateDowntime(ev.withId()); }
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Save')),
      ],
    ));
  }

  void _showMachineProjects(DowntimeEvent d) {
    final projects = ref.read(projectProvider).projects;
    final matches = projects.where((p) =>
        p.machine.toLowerCase().contains(d.machine.toLowerCase()) ||
        d.machine.toLowerCase().contains(p.machine.toLowerCase())).toList();
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
      child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Projects on ${d.machine}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          const Text('No projects on this machine.', style: TextStyle(color: Colors.grey))
        else
          ...matches.map((p) => ListTile(
            dense: true,
            leading: const Icon(Icons.engineering_outlined),
            title: Text('#${p.priority} ${p.title}'),
            subtitle: p.subAssembly.isNotEmpty ? Text(p.subAssembly) : null,
            onTap: () { Navigator.pop(ctx); context.push('/projects/${p.id}'); },
          )),
      ])),
    ));
  }

  Widget _buildHistoryView(BuildContext context, bool isDark) {
    final state = ref.watch(projectProvider);
    final logs = state.activityLog;
    if (logs.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.history_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('No activity recorded yet.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Actions like adding/completing tasks, orders, and notes will show here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final l = logs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(activityTypeIcon(l.type), style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${DateFormat('MMM d, y • h:mm a').format(l.timestamp)}  ${activityTypeLabel(l.type)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(l.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
              if (l.projectTitle != null)
                Text('• ${l.projectTitle}', style: const TextStyle(fontSize: 11, color: AppTheme.primaryCyan)),
            ])),
          ]),
        );
      },
    );
  }

  Widget _buildCalendarGrid({
    required int daysInMonth,
    required int firstWeekday,
    required Map<String, List<({Project project, TaskItem task})>> tasksByDate,
    required Map<String, VoiceNote> notesByDate,
    required Map<String, List<DowntimeEvent>> downtimesByDate,
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
        final hasNote = notesByDate.containsKey(dateKey);
        final hasDowntime = (downtimesByDate[dateKey] ?? []).isNotEmpty;

        return GestureDetector(
          onTap: () => setState(() => _selectedDate = cellDate),
          onLongPress: () => _showDateNoteDialog(cellDate),
          onSecondaryTap: () => _showDateNoteDialog(cellDate),
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
                if (hasDowntime) ...[
                  const SizedBox(height: 2),
                  Container(width: 12, height: 3, decoration: BoxDecoration(color: AppTheme.accentCoral, borderRadius: BorderRadius.circular(2))),
                ],
                if (tasksOnDay.isNotEmpty || hasNote) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (tasksOnDay.isNotEmpty)
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
                      if (hasNote) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 10, color: AppTheme.accentAmber),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDateNoteDialog(DateTime date) async {
    final current = ref.read(projectProvider);
    final key = DateFormat('yyyy-MM-dd').format(date);
    VoiceNote? existing;
    for (final n in current.voiceNotes) {
      if (n.date != null && DateFormat('yyyy-MM-dd').format(n.date!) == key) {
        existing = n;
        break;
      }
    }

    final titleCtrl = TextEditingController(
        text: existing?.title ?? DateFormat('MM/dd/yyyy').format(date));
    final contentCtrl =
        TextEditingController(text: existing?.transcript ?? '');
    final dateLabel = DateFormat('MMM d').format(date);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Note — $dateLabel' : 'Edit Note — $dateLabel'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Defaults to date (MM/DD/YYYY)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Details for this date...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    final title = titleCtrl.text.trim();
    final content = contentCtrl.text.trim();
    final notifier = ref.read(projectProvider.notifier);
    final fallbackTitle = DateFormat('MM/dd/yyyy').format(date);

    if (existing != null) {
      await notifier.updateVoiceNote(existing.copyWith(
        title: title.isEmpty ? fallbackTitle : title,
        transcript: content,
        date: date,
      ));
    } else {
      await notifier.addVoiceNote(VoiceNote(
        title: title.isEmpty ? fallbackTitle : title,
        transcript: content,
        durationSeconds: 0,
        date: date,
      ));
    }
  }

  Future<void> _deleteDateNote(DateTime date) async {
    final current = ref.read(projectProvider);
    final key = DateFormat('yyyy-MM-dd').format(date);
    VoiceNote? existing;
    for (final n in current.voiceNotes) {
      if (n.date != null && DateFormat('yyyy-MM-dd').format(n.date!) == key) {
        existing = n;
        break;
      }
    }
    if (existing == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: Text('Delete the note for ${DateFormat('MMM d').format(date)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCoral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(syncStatusProvider.notifier)
          .deleteVoiceNoteEverywhere(existing.id);
    }
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
