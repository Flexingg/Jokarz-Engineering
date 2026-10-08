import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/task_item.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/bamm_assign_dialog.dart';
import '../widgets/bamm_chip.dart';
import 'autosave.dart';
import 'panel_chrome.dart';

/// Right-hand editor for one project task, autosaved. Key it by task id so
/// selecting another task flushes this one first.
class TaskEditorPanel extends ConsumerStatefulWidget {
  final String projectId;
  final String taskId;
  final VoidCallback onClose;

  const TaskEditorPanel({
    super.key,
    required this.projectId,
    required this.taskId,
    required this.onClose,
  });

  @override
  ConsumerState<TaskEditorPanel> createState() => _TaskEditorPanelState();
}

class _TaskEditorPanelState extends ConsumerState<TaskEditorPanel>
    with AutosaveMixin {
  late ProviderContainer _container;
  final _desc = TextEditingController();
  final _pending = TextEditingController();
  DateTime? _scheduled;
  List<String> _bamms = [];

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    final t = _current();
    if (t != null) {
      _desc.text = t.description;
      _pending.text = t.pendingReason;
      _scheduled = t.scheduledDate;
      _bamms = List.of(t.bammWorkOrders);
    }
    _desc.addListener(markDirty);
    _pending.addListener(markDirty);
  }

  TaskItem? _current() => _container
      .read(projectProvider)
      .projects
      .where((p) => p.id == widget.projectId)
      .firstOrNull
      ?.tasks
      .where((t) => t.id == widget.taskId)
      .firstOrNull;

  @override
  bool get canSave => _desc.text.trim().isNotEmpty;

  @override
  Future<void> saveDraft() async {
    final current = _current();
    if (current == null) return; // deleted elsewhere
    final updated = current.copyWith(
      description: _desc.text.trim(),
      pendingReason: _pending.text.trim(),
      scheduledDate: _scheduled,
      clearScheduledDate: _scheduled == null,
      bammWorkOrders: List.of(_bamms),
    );
    await _container
        .read(projectProvider.notifier)
        .updateTask(widget.projectId, updated);
  }

  @override
  void dispose() {
    disposeAutosave();
    _desc.dispose();
    _pending.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduled ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => _scheduled = picked);
    markDirty();
    await flush();
  }

  Future<void> _assignBamms() async {
    final res = await BammAssignDialog.show(context, currentSelections: _bamms);
    if (res == null) return;
    setState(() => _bamms = res);
    markDirty();
    await flush();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return PanelChrome(
      title: 'Task',
      status: saveStatus,
      onRetry: flush,
      onBlur: flush,
      onClose: () async {
        await flush();
        widget.onClose();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _desc,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Task Description *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pending,
            decoration: const InputDecoration(
              labelText: 'Pending Value / Reason',
              hintText: 'e.g. Pending parts, Pending downtime',
              prefixIcon: Icon(Icons.hourglass_empty_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scheduled != null
                          ? DateFormat('MMM d, y').format(_scheduled!)
                          : 'No scheduled date',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Scheduled Target Date',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (_scheduled != null)
                IconButton(
                  tooltip: 'Clear date',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () async {
                    setState(() => _scheduled = null);
                    markDirty();
                    await flush();
                  },
                ),
              TextButton(onPressed: _pickDate, child: const Text('Pick date')),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Assigned BAMMs:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _assignBamms,
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'Assign BAMM',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          if (_bamms.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _bamms
                  .map(
                    (wo) => BammChip(
                      worNo: wo,
                      onDeleted: () async {
                        setState(() => _bamms.remove(wo));
                        markDirty();
                        await flush();
                      },
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
