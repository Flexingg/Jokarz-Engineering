import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';
import 'autosave.dart';
import 'panel_chrome.dart';

/// Right-hand editor for a project's own fields: category, priority, phase,
/// machine, sub-assembly, cost, tags and notes. Dropdowns apply as soon as
/// they change; text fields autosave like the other panels.
class ProjectEditorPanel extends ConsumerStatefulWidget {
  final String projectId;
  final VoidCallback onClose;

  const ProjectEditorPanel({
    super.key,
    required this.projectId,
    required this.onClose,
  });

  @override
  ConsumerState<ProjectEditorPanel> createState() => _ProjectEditorPanelState();
}

class _ProjectEditorPanelState extends ConsumerState<ProjectEditorPanel>
    with AutosaveMixin {
  late ProviderContainer _container;
  final _machine = TextEditingController();
  final _sub = TextEditingController();
  final _cost = TextEditingController();
  final _tags = TextEditingController();
  final _notes = TextEditingController();

  Project? _project() => _container
      .read(projectProvider)
      .projects
      .where((p) => p.id == widget.projectId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    final p = _project();
    if (p != null) {
      _machine.text = p.machine;
      _sub.text = p.subAssembly;
      _cost.text = p.cost > 0 ? p.cost.toStringAsFixed(2) : '';
      _tags.text = p.tags.join(', ');
      _notes.text = p.notes;
    }
    for (final c in [_machine, _sub, _cost, _tags, _notes]) {
      c.addListener(markDirty);
    }
  }

  List<String> get _tagList => _tags.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  @override
  Future<void> saveDraft() async {
    final p = _project();
    if (p == null) return;
    final cost = double.tryParse(_cost.text.trim()) ?? 0.0;
    final tags = _tagList;
    final changed =
        p.machine != _machine.text.trim() ||
        p.subAssembly != _sub.text.trim() ||
        p.cost != cost ||
        p.notes != _notes.text.trim() ||
        p.tags.join('\u0000') != tags.join('\u0000');
    if (!changed) return;
    await _container
        .read(projectProvider.notifier)
        .updateProject(
          p.copyWith(
            machine: _machine.text.trim(),
            subAssembly: _sub.text.trim(),
            cost: cost,
            tags: tags,
            notes: _notes.text.trim(),
          ),
        );
  }

  @override
  void dispose() {
    disposeAutosave();
    for (final c in [_machine, _sub, _cost, _tags, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _apply(Project Function(Project) change) async {
    final p = _project();
    if (p == null) return;
    await _container.read(projectProvider.notifier).updateProject(change(p));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final state = ref.watch(projectProvider);
    final p = state.projects.where((x) => x.id == widget.projectId).firstOrNull;
    if (p == null) return const SizedBox.shrink();
    final phases = state.availablePhases;
    final maxPriority = state.activeProjects.isEmpty
        ? 1
        : state.activeProjects.length;
    return PanelChrome(
      title: 'Project details',
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
          Text(
            p.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ProjectCategory>(
            key: ValueKey('cat-${p.category.name}'),
            initialValue: p.category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: ProjectCategory.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                .toList(),
            onChanged: (v) {
              if (v != null && v != p.category) {
                _apply((x) => x.copyWith(category: v));
              }
            },
          ),
          const SizedBox(height: 12),
          if (!p.isCompletedOrCancelled) ...[
            DropdownButtonFormField<int>(
              key: ValueKey('pri-${p.priority}'),
              initialValue: p.priority.clamp(1, maxPriority),
              decoration: const InputDecoration(
                labelText: 'Priority',
                prefixIcon: Icon(Icons.format_list_numbered_rounded),
              ),
              items: List.generate(
                maxPriority,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('#${i + 1}${i == 0 ? " (Top Urgent)" : ""}'),
                ),
              ),
              onChanged: (v) {
                if (v != null && v != p.priority) {
                  _apply((x) => x.copyWith(priority: v));
                }
              },
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            key: ValueKey('phase-${p.phase}'),
            initialValue: phases.contains(p.phase) ? p.phase : phases.first,
            decoration: const InputDecoration(labelText: 'Phase / Status'),
            items: phases
                .map((ph) => DropdownMenuItem(value: ph, child: Text(ph)))
                .toList(),
            onChanged: (v) {
              if (v != null && v != p.phase) {
                _apply((x) => x.copyWith(phase: v));
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _machine,
            decoration: const InputDecoration(
              labelText: 'Machine / Line',
              hintText: 'Use / to add multiple machines',
              prefixIcon: Icon(Icons.precision_manufacturing_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sub,
            decoration: const InputDecoration(
              labelText: 'Sub-Assembly',
              prefixIcon: Icon(Icons.account_tree_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cost (\$ USD)',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'Tags (comma separated)',
              prefixIcon: Icon(Icons.tag_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 14, color: colors.amber),
              const SizedBox(width: 6),
              Text(
                'Project Notes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notes,
            minLines: 5,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText: 'Key observations, measurements, decisions...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
