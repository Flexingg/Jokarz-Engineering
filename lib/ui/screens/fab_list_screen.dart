import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/fab_job.dart';
import '../../providers/project_provider.dart';
import '../../services/open_path.dart';
import '../../theme/app_theme.dart';
import '../adaptive/breakpoints.dart';
import '../keynav/key_nav.dart';
import '../panels/fab_job_panel.dart';
import '../panels/resizable_panel.dart';

enum _FabFilter { open, all, done }

/// The fabricators' list: one row per job with who, dates, drawing folder,
/// notes and status. Click a row (or Enter) to edit it beside the table.
class FabListScreen extends ConsumerStatefulWidget {
  const FabListScreen({super.key});

  @override
  ConsumerState<FabListScreen> createState() => _FabListScreenState();
}

class _FabListScreenState extends ConsumerState<FabListScreen> {
  final _nav = KeyNavController();
  _FabFilter _filter = _FabFilter.open;
  String _search = '';
  String? _activeId;

  bool get _wide => Breakpoints.isExpanded(MediaQuery.sizeOf(context).width);

  @override
  void dispose() {
    _nav.dispose();
    super.dispose();
  }

  List<FabJob> _visible(List<FabJob> all) {
    final q = _search.trim().toLowerCase();
    final list = all.where((j) {
      switch (_filter) {
        case _FabFilter.open:
          if (!j.isOpen) return false;
        case _FabFilter.done:
          if (j.isOpen) return false;
        case _FabFilter.all:
      }
      if (q.isEmpty) return true;
      return j.title.toLowerCase().contains(q) ||
          j.who.toLowerCase().contains(q) ||
          j.notes.toLowerCase().contains(q) ||
          j.drawingPath.toLowerCase().contains(q);
    }).toList();
    // Soonest due first, undated last; finished jobs newest first.
    list.sort((a, b) {
      if (!a.isOpen && !b.isOpen) {
        return (b.completedAt ?? b.updatedAt).compareTo(
          a.completedAt ?? a.updatedAt,
        );
      }
      if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
      final ad = a.dueDate, bd = b.dueDate;
      if (ad == null && bd == null) return a.createdAt.compareTo(b.createdAt);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return list;
  }

  Future<void> _addJob() async {
    final job = FabJob(title: 'New fab job');
    await ref.read(projectProvider.notifier).addFabJob(job);
    _open(job.id);
  }

  void _open(String id) {
    if (_wide) {
      setState(() => _activeId = id);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          child: Scaffold(
            body: SafeArea(
              child: FabJobPanel(jobId: id, onClose: () => Navigator.pop(ctx)),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _setStatus(FabJob job, FabStatus status) => ref
      .read(projectProvider.notifier)
      .updateFabJob(job.copyWith(status: status));

  Future<void> _openFolder(FabJob job) async {
    if (job.drawingPath.trim().isEmpty) {
      _open(job.id);
      return;
    }
    final ok = await openInFileBrowser(job.drawingPath);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that folder.')),
      );
    }
  }

  FabStatus _next(FabStatus s) => switch (s) {
    FabStatus.pending => FabStatus.inProgress,
    FabStatus.inProgress => FabStatus.completed,
    FabStatus.completed => FabStatus.pending,
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final state = ref.watch(projectProvider);
    final rows = _visible(state.fabJobs);
    final openCount = state.fabJobs.where((j) => j.isOpen).length;

    final list = rows.isEmpty
        ? Center(
            child: Text(
              state.fabJobs.isEmpty
                  ? 'Nothing on the fab list yet.\nAdd a job here, or use "Add to fab list" on a project task.'
                  : 'No jobs match.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
            itemCount: rows.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: KeyNavItem(
                controller: _nav,
                index: i,
                radius: 12,
                child: _row(rows[i], i, colors),
              ),
            ),
          );

    final body = KeyNav(
      controller: _nav,
      count: rows.length,
      onActivate: (i) => _open(rows[i].id),
      onEscape: () {
        if (_activeId != null) setState(() => _activeId = null);
      },
      keys: {
        LogicalKeyboardKey.keyS: (i) =>
            _setStatus(rows[i], _next(rows[i].status)),
        LogicalKeyboardKey.keyO: (i) => _openFolder(rows[i]),
        LogicalKeyboardKey.keyE: (i) => _open(rows[i].id),
        LogicalKeyboardKey.keyN: (_) => _addJob(),
      },
      help: const {
        'S': 'Cycle status: pending, in progress, completed',
        'O': 'Open the drawing folder',
        'E': 'Edit the job',
        'N': 'New job',
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                SegmentedButton<_FabFilter>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _FabFilter.open,
                      label: Text('Open ($openCount)'),
                    ),
                    const ButtonSegment(
                      value: _FabFilter.all,
                      label: Text('All'),
                    ),
                    const ButtonSegment(
                      value: _FabFilter.done,
                      label: Text('Completed'),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (v) => setState(() => _filter = v.first),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
              ],
            ),
          ),
          if (_wide) _header(colors),
          Expanded(child: list),
        ],
      ),
    );

    final panelJob = _activeId == null
        ? null
        : state.fabJobs.where((j) => j.id == _activeId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.construction_rounded),
            SizedBox(width: 8),
            Text('Fab list', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addJob,
        icon: const Icon(Icons.add),
        label: const Text('Add job'),
      ),
      body: _wide && panelJob != null
          ? Row(
              children: [
                Expanded(child: body),
                ResizablePanel(
                  prefKey: 'fab',
                  defaultWidth: 440,
                  child: FabJobPanel(
                    key: ValueKey('fab-${panelJob.id}'),
                    jobId: panelJob.id,
                    onClose: () => setState(() => _activeId = null),
                    onOpenProject: panelJob.projectId == null
                        ? null
                        : () => context.push('/projects/${panelJob.projectId}'),
                  ),
                ),
              ],
            )
          : body,
    );
  }

  static const _flex = [
    5,
    2,
    2,
    2,
    4,
    4,
    2,
  ]; // title, who, due, started, drawings, notes, status

  Widget _header(AppColors colors) {
    const labels = [
      'JOB',
      'WHO',
      'DUE',
      'STARTED',
      'DRAWINGS',
      'NOTES',
      'STATUS',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: _flex[i],
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: colors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(FabStatus s, AppColors c) => switch (s) {
    FabStatus.pending => c.amber,
    FabStatus.inProgress => c.primary,
    FabStatus.completed => c.emerald,
  };

  Widget _statusChip(FabJob job, AppColors colors) {
    final color = _statusColor(job.status, colors);
    return PopupMenuButton<FabStatus>(
      tooltip: 'Change status',
      onSelected: (s) => _setStatus(job, s),
      itemBuilder: (_) => [
        for (final s in FabStatus.values)
          PopupMenuItem(value: s, child: Text(fabStatusLabel(s))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          fabStatusLabel(job.status),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _row(FabJob job, int index, AppColors colors) {
    final fmt = DateFormat('MMM d');
    final overdue = job.isOverdue();
    final selected = _activeId == job.id;

    Widget text(String t, {Color? color, bool bold = false, int lines = 2}) =>
        Text(
          t.isEmpty ? '–' : t,
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : null,
            color: t.isEmpty ? colors.textSecondary : color,
            decoration: job.status == FabStatus.completed && bold
                ? TextDecoration.lineThrough
                : null,
          ),
        );

    final drawing = job.drawingPath.trim().isEmpty
        ? text('')
        : InkWell(
            onTap: () => _openFolder(job),
            child: Tooltip(
              message: '${job.drawingPath}\nClick to open in File Explorer',
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 15,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.drawingPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

    final cells = <Widget>[
      text(job.title, bold: true),
      text(job.who),
      text(
        job.dueDate != null ? fmt.format(job.dueDate!) : '',
        color: overdue ? colors.coral : null,
      ),
      text(job.startedDate != null ? fmt.format(job.startedDate!) : ''),
      drawing,
      text(job.notes, lines: 2),
      Align(alignment: Alignment.centerLeft, child: _statusChip(job, colors)),
    ];

    return Material(
      color: selected ? colors.primary.withValues(alpha: 0.08) : colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _nav.select(index);
          _nav.takeFocus();
          _open(job.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: _wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < cells.length; i++)
                      Expanded(
                        flex: _flex[i],
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: cells[i],
                        ),
                      ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: cells[0]),
                        cells[6],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        if (job.who.isNotEmpty)
                          Text(
                            '👷 ${job.who}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (job.dueDate != null)
                          Text(
                            'Due ${fmt.format(job.dueDate!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: overdue ? colors.coral : null,
                            ),
                          ),
                        if (job.startedDate != null)
                          Text(
                            'Started ${fmt.format(job.startedDate!)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                    if (job.drawingPath.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      drawing,
                    ],
                    if (job.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      text(job.notes, lines: 2),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
