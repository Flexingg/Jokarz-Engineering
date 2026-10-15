import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/voice_note.dart';
import '../../providers/project_provider.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import 'autosave.dart';
import 'panel_chrome.dart';

/// Right-hand editor for a field note ([noteId]) or for a project's own notes
/// ([projectId]). Autosaves; key it by the record id so switching flushes.
class NoteEditorPanel extends ConsumerStatefulWidget {
  final String? noteId;
  final String? projectId;
  final VoidCallback onClose;
  final VoidCallback? onOpenProject;

  const NoteEditorPanel({
    super.key,
    this.noteId,
    this.projectId,
    required this.onClose,
    this.onOpenProject,
  }) : assert(noteId != null || projectId != null);

  @override
  ConsumerState<NoteEditorPanel> createState() => _NoteEditorPanelState();
}

class _NoteEditorPanelState extends ConsumerState<NoteEditorPanel>
    with AutosaveMixin {
  late ProviderContainer _container;
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _linkedProject;

  bool get _isProjectNote => widget.noteId == null;

  VoiceNote? _note() => _container
      .read(projectProvider)
      .voiceNotes
      .where((n) => n.id == widget.noteId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    if (_isProjectNote) {
      final p = _container
          .read(projectProvider)
          .projects
          .where((p) => p.id == widget.projectId)
          .firstOrNull;
      _body.text = p?.notes ?? '';
    } else {
      final n = _note();
      if (n != null) {
        _title.text = n.title;
        _body.text = n.transcript;
        _linkedProject = n.projectId;
      }
    }
    _title.addListener(markDirty);
    _body.addListener(markDirty);
  }

  @override
  bool get canSave => _isProjectNote || _title.text.trim().isNotEmpty;

  @override
  Future<void> saveDraft() async {
    final notifier = _container.read(projectProvider.notifier);
    if (_isProjectNote) {
      await notifier.updateProjectNotes(widget.projectId!, _body.text.trim());
      return;
    }
    final n = _note();
    if (n == null) return; // deleted elsewhere
    await notifier.updateVoiceNote(
      n.copyWith(
        title: _title.text.trim(),
        transcript: _body.text.trim(),
        projectId: _linkedProject,
        clearProjectId: _linkedProject == null,
      ),
    );
  }

  @override
  void dispose() {
    disposeAutosave();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final n = _note();
    if (n == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: Text('Delete "${n.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.of(context).coral,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // Nothing left to save once the note is gone.
    _title.removeListener(markDirty);
    _body.removeListener(markDirty);
    await _container
        .read(syncStatusProvider.notifier)
        .deleteVoiceNoteEverywhere(n.id);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final state = ref.watch(projectProvider);
    final note = _isProjectNote ? null : _note();
    final project = state.projects
        .where((p) => p.id == (_isProjectNote ? widget.projectId : _linkedProject))
        .firstOrNull;
    return PanelChrome(
      title: _isProjectNote ? 'Project notes' : 'Field note',
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
          if (_isProjectNote) ...[
            Text(
              project?.title ?? '',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (widget.onOpenProject != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onOpenProject,
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Open project'),
                ),
              ),
          ] else ...[
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Note Title *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('proj-$_linkedProject'),
              initialValue: state.projects.any((p) => p.id == _linkedProject)
                  ? _linkedProject
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Attach to Project (Optional)',
                prefixIcon: Icon(Icons.precision_manufacturing_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('General'),
                ),
                ...state.projects.map(
                  (p) => DropdownMenuItem<String?>(
                    value: p.id,
                    child: Text(p.title, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) async {
                setState(() => _linkedProject = v);
                markDirty();
                await flush();
              },
            ),
            if (note?.photoPath != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: Image.file(
                    File(note!.photoPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 10,
            maxLines: 30,
            decoration: InputDecoration(
              labelText: _isProjectNote
                  ? 'Notes'
                  : 'Engineering Notes & Observations',
              alignLabelWithHint: true,
            ),
          ),
          if (!_isProjectNote) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _delete,
                icon: Icon(Icons.delete_outline, size: 16, color: colors.coral),
                label: Text('Delete note', style: TextStyle(color: colors.coral)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
