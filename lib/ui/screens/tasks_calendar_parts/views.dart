part of '../tasks_calendar_screen.dart';

extension _TasksCalendarViews on _TasksCalendarScreenState {
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
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary)),
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
                Text('• ${l.projectTitle}', style: TextStyle(fontSize: 11, color: AppTheme.of(context).primary)),
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
          onTap: () => _rebuild(() => _selectedDate = cellDate),
          onLongPress: () => _showDateNoteDialog(cellDate),
          onSecondaryTap: () => _showDateNoteDialog(cellDate),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.of(context).primary.withValues(alpha: 0.25)
                  : isToday
                      ? AppTheme.of(context).amber.withValues(alpha: 0.15)
                      : (isDark
                          ? AppTheme.of(context).surface
                          : AppTheme.of(context).surface),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: isSelected
                    ? AppTheme.of(context).primary
                    : isToday
                        ? AppTheme.of(context).amber
                        : (isDark ? AppTheme.of(context).border : AppTheme.of(context).border),
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
                        ? AppTheme.of(context).primary
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                if (hasDowntime) ...[
                  const SizedBox(height: 2),
                  Container(width: 12, height: 3, decoration: BoxDecoration(color: AppTheme.of(context).coral, borderRadius: BorderRadius.circular(2))),
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
                                ? AppTheme.of(context).coral
                                : AppTheme.of(context).emerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasNote) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.sticky_note_2_outlined,
                            size: 10, color: AppTheme.of(context).amber),
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
}
