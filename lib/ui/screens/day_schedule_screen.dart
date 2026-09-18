import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/project.dart';
import '../../models/task_item.dart';
import '../../models/time_block.dart';
import '../../providers/project_provider.dart';
import '../../providers/time_block_provider.dart';

/// One unscheduled task available in the tray, paired with its owning
/// project (for `projectId` + display).
class _TrayEntry {
  final Project project;
  final TaskItem task;
  const _TrayEntry({required this.project, required this.task});
}

/// The day-view timeline: today's [TimeBlock]s in order with gaps visible,
/// plus a tray of unscheduled tasks to drag (or tap) into a gap. Personal
/// planning data only - nothing here is ever sent to BAMM. No phone/Home
/// Assistant notifications anywhere in this screen or its provider.
class DayScheduleScreen extends ConsumerWidget {
  const DayScheduleScreen({super.key});

  static final DateFormat _timeFmt = DateFormat('h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeBlockState = ref.watch(timeBlockProvider);
    final projectState = ref.watch(projectProvider);
    final today = DateTime.now();
    final dayBlocks = timeBlockState.blocksForDay(today);
    final summary = timeBlockState.weeklySlipSummary();

    final scheduledTaskIds = timeBlockState.blocks.map((b) => b.taskId).toSet();
    final tray = <_TrayEntry>[
      for (final project in projectState.projects)
        for (final task in project.tasks)
          if (!task.isCompleted && !scheduledTaskIds.contains(task.id)) _TrayEntry(project: project, task: task),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Day Schedule')),
      body: Column(
        children: [
          _SummaryBar(summaryLine: summary.summaryLine, cascadeEnabled: timeBlockState.cascadeEnabled),
          Expanded(
            child: dayBlocks.isEmpty
                ? const Center(child: Text('No blocks scheduled today - drag a task in below'))
                : _Timeline(blocks: dayBlocks, timeFmt: _timeFmt),
          ),
          _Tray(entries: tray, dayBlocks: dayBlocks, today: today),
        ],
      ),
    );
  }
}

class _SummaryBar extends ConsumerWidget {
  final String summaryLine;
  final bool cascadeEnabled;
  const _SummaryBar({required this.summaryLine, required this.cascadeEnabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const Key('weekly_slip_summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.trending_flat, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(summaryLine, style: const TextStyle(fontWeight: FontWeight.w600))),
          const Text('Cascade', style: TextStyle(fontSize: 12)),
          Switch(
            key: const Key('cascade_toggle'),
            value: cascadeEnabled,
            onChanged: (v) => ref.read(timeBlockProvider.notifier).setCascadeEnabled(v),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<TimeBlock> blocks;
  final DateFormat timeFmt;
  const _Timeline({required this.blocks, required this.timeFmt});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      children.add(_BlockTile(block: block, timeFmt: timeFmt));
      if (i < blocks.length - 1) {
        final gapMinutes = blocks[i + 1].start.difference(block.end).inMinutes;
        children.add(_GapStrip(gapStart: block.end, minutes: gapMinutes, index: i));
      }
    }
    return ListView(padding: const EdgeInsets.all(12), children: children);
  }
}

class _GapStrip extends ConsumerWidget {
  final DateTime gapStart;
  final int minutes;
  final int index;
  const _GapStrip({required this.gapStart, required this.minutes, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (minutes <= 0) return const SizedBox.shrink();
    return DragTarget<String>(
      onAcceptWithDetails: (details) => _scheduleTaskById(ref, details.data, gapStart),
      builder: (context, candidateData, rejectedData) {
        return InkWell(
          key: Key('gap_$index'),
          onTap: () => _openTrayPickerForSlot(context, ref, gapStart),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid, width: 1),
            ),
            child: Text('$minutes min free - tap to schedule', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        );
      },
    );
  }
}

/// Schedules the dragged task ([taskId]) directly into [slotStart] - used by
/// the drag-and-drop path, where the payload already names the exact task
/// (unlike the tap path, which has to ask via the tray picker sheet).
void _scheduleTaskById(WidgetRef ref, String taskId, DateTime slotStart) {
  final projectState = ref.read(projectProvider);
  for (final project in projectState.projects) {
    for (final task in project.tasks) {
      if (task.id == taskId) {
        ref.read(timeBlockProvider.notifier).scheduleTask(
              taskId: task.id,
              projectId: project.id,
              title: task.description,
              start: slotStart,
            );
        return;
      }
    }
  }
}

void _openTrayPickerForSlot(BuildContext context, WidgetRef ref, DateTime slotStart) {
  final projectState = ref.read(projectProvider);
  final scheduledTaskIds = ref.read(timeBlockProvider).blocks.map((b) => b.taskId).toSet();
  final tray = <_TrayEntry>[
    for (final project in projectState.projects)
      for (final task in project.tasks)
        if (!task.isCompleted && !scheduledTaskIds.contains(task.id)) _TrayEntry(project: project, task: task),
  ];
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Schedule a task here', style: TextStyle(fontWeight: FontWeight.bold))),
          if (tray.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No unscheduled tasks')),
          for (final entry in tray)
            ListTile(
              title: Text(entry.task.description),
              subtitle: Text(entry.project.title),
              onTap: () {
                ref.read(timeBlockProvider.notifier).scheduleTask(
                      taskId: entry.task.id,
                      projectId: entry.project.id,
                      title: entry.task.description,
                      start: slotStart,
                    );
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    ),
  );
}

class _BlockTile extends ConsumerWidget {
  final TimeBlock block;
  final DateFormat timeFmt;
  const _BlockTile({required this.block, required this.timeFmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: Key('block_${block.id}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _showBlockActions(context, ref, block),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(block.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('${timeFmt.format(block.start)} - ${timeFmt.format(block.end)} (${block.estimatedMinutes} min)',
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    if (block.status != TimeBlockStatus.scheduled)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          block.status == TimeBlockStatus.done ? 'Done (${block.actualMinutes} min)' : 'Partial',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.more_vert),
            ],
          ),
        ),
      ),
    );
  }
}

void _showBlockActions(BuildContext context, WidgetRef ref, TimeBlock block) {
  final notifier = ref.read(timeBlockProvider.notifier);
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: [
          _ActionTile(
            icon: Icons.add,
            label: '+15 minutes',
            onTap: () {
              notifier.pushBy(block.id, const Duration(minutes: 15), kind: SlipLogPushKind.plus15);
              Navigator.pop(ctx);
            },
          ),
          _ActionTile(
            icon: Icons.add_circle_outline,
            label: '+1 hour',
            onTap: () {
              notifier.pushBy(block.id, const Duration(hours: 1), kind: SlipLogPushKind.plus1Hour);
              Navigator.pop(ctx);
            },
          ),
          _ActionTile(
            icon: Icons.wb_sunny_outlined,
            label: 'Push to tomorrow',
            onTap: () {
              notifier.pushToTomorrow(block.id);
              Navigator.pop(ctx);
            },
          ),
          _ActionTile(
            icon: Icons.fast_forward,
            label: 'Push the rest of today',
            onTap: () {
              notifier.pushRestOfDay(block.id);
              Navigator.pop(ctx);
            },
          ),
          _ActionTile(
            icon: Icons.pause_circle_outline,
            label: 'Interrupted',
            onTap: () async {
              Navigator.pop(ctx);
              final note = await _promptText(context, title: 'What got done?');
              if (note != null) notifier.markInterrupted(block.id, doneNote: note);
            },
          ),
          _ActionTile(
            icon: Icons.check_circle_outline,
            label: 'Close (done)',
            onTap: () async {
              Navigator.pop(ctx);
              final actual = await _promptMinutes(context, defaultValue: block.estimatedMinutes);
              if (actual != null) notifier.closeBlock(block.id, actualMinutes: actual);
            },
          ),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Big touch target - this is used one-handed on a phone.
    return ListTile(
      key: Key('block_action_$label'),
      leading: Icon(icon, size: 28),
      title: Text(label, style: const TextStyle(fontSize: 16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      onTap: onTap,
    );
  }
}

Future<String?> _promptText(BuildContext context, {required String title}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, maxLines: 3),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
      ],
    ),
  );
}

Future<int?> _promptMinutes(BuildContext context, {required int defaultValue}) {
  final ctrl = TextEditingController(text: '$defaultValue');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Actual minutes'),
      content: TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim()) ?? defaultValue),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _Tray extends StatelessWidget {
  final List<_TrayEntry> entries;
  final List<TimeBlock> dayBlocks;
  final DateTime today;
  const _Tray({required this.entries, required this.dayBlocks, required this.today});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('unscheduled_tray'),
      height: 96,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade400)),
      ),
      child: entries.isEmpty
          ? const Center(child: Text('No unscheduled tasks', style: TextStyle(color: Colors.grey)))
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              children: [
                for (final entry in entries)
                  Draggable<String>(
                    data: entry.task.id,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _TrayCard(entry: entry),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: _TrayCard(entry: entry)),
                    child: _TrayCard(entry: entry),
                  ),
              ],
            ),
    );
  }
}

class _TrayCard extends StatelessWidget {
  final _TrayEntry entry;
  const _TrayCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('tray_${entry.task.id}'),
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(entry.task.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(entry.project.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
