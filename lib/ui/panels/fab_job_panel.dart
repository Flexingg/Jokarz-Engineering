import '../fluid/fluid_dialog.dart';
import '../fluid/liquid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/fab_job.dart';
import '../../providers/project_provider.dart';
import '../../services/open_path.dart';
import '../../theme/app_theme.dart';
import 'autosave.dart';
import 'panel_chrome.dart';

/// Right-hand editor for one fab job. Text fields autosave; status and the two
/// dates apply the moment you pick them. Key it by job id.
class FabJobPanel extends ConsumerStatefulWidget {
  final String jobId;
  final VoidCallback onClose;
  final VoidCallback? onOpenProject;

  const FabJobPanel({
    super.key,
    required this.jobId,
    required this.onClose,
    this.onOpenProject,
  });

  @override
  ConsumerState<FabJobPanel> createState() => _FabJobPanelState();
}

class _FabJobPanelState extends ConsumerState<FabJobPanel> with AutosaveMixin {
  late ProviderContainer _container;
  final _title = TextEditingController();
  final _who = TextEditingController();
  final _path = TextEditingController();
  final _notes = TextEditingController();

  FabJob? _job() => _container
      .read(projectProvider)
      .fabJobs
      .where((j) => j.id == widget.jobId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    final j = _job();
    if (j != null) {
      _title.text = j.title;
      _who.text = j.who;
      _path.text = j.drawingPath;
      _notes.text = j.notes;
    }
    for (final c in [_title, _who, _path, _notes]) {
      c.addListener(markDirty);
    }
  }

  @override
  bool get canSave => _title.text.trim().isNotEmpty;

  @override
  Future<void> saveDraft() async {
    final j = _job();
    if (j == null) return; // deleted elsewhere
    final title = _title.text.trim();
    final who = _who.text.trim();
    final path = cleanFolderPath(_path.text);
    final notes = _notes.text.trim();
    if (j.title == title &&
        j.who == who &&
        j.drawingPath == path &&
        j.notes == notes) {
      return;
    }
    await _container
        .read(projectProvider.notifier)
        .updateFabJob(
          j.copyWith(title: title, who: who, drawingPath: path, notes: notes),
        );
  }

  @override
  void dispose() {
    disposeAutosave();
    for (final c in [_title, _who, _path, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _apply(FabJob Function(FabJob) change) async {
    final j = _job();
    if (j == null) return;
    await _container.read(projectProvider.notifier).updateFabJob(change(j));
  }

  Future<void> _pick(DateTime? current, void Function(DateTime) set) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) set(picked);
  }

  Widget _dateRow(
    String label,
    IconData icon,
    DateTime? value,
    VoidCallback onPick,
    VoidCallback onClear,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.of(context).primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value != null
                ? '$label: ${DateFormat('EEE, MMM d, y').format(value)}'
                : '$label: not set',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        if (value != null)
          IconButton(
            tooltip: 'Clear',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.clear, size: 16),
            onPressed: onClear,
          ),
        TextButton(onPressed: onPick, child: const Text('Pick')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final state = ref.watch(projectProvider);
    final job = state.fabJobs.where((j) => j.id == widget.jobId).firstOrNull;
    if (job == null) return const SizedBox.shrink();
    final recentWho = {
      for (final j in state.fabJobs)
        if (j.who.trim().isNotEmpty) j.who.trim(),
    }.take(8).toList();

    return PanelChrome(
      title: 'Fab job',
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
            controller: _title,
            decoration: const InputDecoration(labelText: 'Job / part *'),
          ),
          const SizedBox(height: 12),
          FluidSegmentedButton<FabStatus>(
            showSelectedIcon: false,
            segments: [
              for (final s in FabStatus.values)
                ButtonSegment(
                  value: s,
                  label: Text(
                    fabStatusLabel(s),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
            selected: {job.status},
            onSelectionChanged: (v) =>
                _apply((j) => j.copyWith(status: v.first)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _who,
            decoration: const InputDecoration(
              labelText: 'Who',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          if (recentWho.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final w in recentWho)
                    ActionChip(
                      label: Text(w, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _who.text = w,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          _dateRow(
            'Due',
            Icons.event_rounded,
            job.dueDate,
            () => _pick(
              job.dueDate,
              (d) => _apply((j) => j.copyWith(dueDate: d)),
            ),
            () => _apply((j) => j.copyWith(clearDueDate: true)),
          ),
          _dateRow(
            'Started',
            Icons.play_circle_outline_rounded,
            job.startedDate,
            () => _pick(
              job.startedDate,
              (d) => _apply((j) => j.copyWith(startedDate: d)),
            ),
            () => _apply((j) => j.copyWith(clearStartedDate: true)),
          ),
          if (job.completedAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2),
              child: Text(
                'Completed ${DateFormat('MMM d, y').format(job.completedAt!)}',
                style: TextStyle(fontSize: 12, color: colors.emerald),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _path,
            decoration: InputDecoration(
              labelText: 'Drawing folder',
              hintText: r'\\server\drawings\J-1042  or  C:\Drawings\J-1042',
              prefixIcon: const Icon(Icons.folder_open_rounded),
              suffixIcon: IconButton(
                tooltip: 'Open in File Explorer',
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                onPressed: () async {
                  await flush();
                  final ok = await openInFileBrowser(_path.text);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open that folder.'),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 4,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Notes',
              alignLabelWithHint: true,
            ),
          ),
          if (widget.onOpenProject != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onOpenProject,
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Open project'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final ok = await showFluidDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove from fab list?'),
                    content: Text(
                      'Remove "${job.title}"? The project task, if any, is not touched.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.coral,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                await _container
                    .read(projectProvider.notifier)
                    .deleteFabJob(job.id);
                widget.onClose();
              },
              icon: Icon(Icons.delete_outline, size: 16, color: colors.coral),
              label: Text(
                'Remove from list',
                style: TextStyle(color: colors.coral),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
