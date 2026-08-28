import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/voice_note.dart';
import '../../providers/project_provider.dart';
import '../../services/sync_service.dart';
import '../../utils/text_utils.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/voice_memo_modal.dart';
import '../widgets/note_dialogs.dart';

class VoiceNotesScreen extends ConsumerStatefulWidget {
  const VoiceNotesScreen({super.key});

  @override
  ConsumerState<VoiceNotesScreen> createState() => _VoiceNotesScreenState();
}

class _VoiceNotesScreenState extends ConsumerState<VoiceNotesScreen> {
  String _search = '';

  void _showNewTextNoteDialog(BuildContext context) {
    showNewFieldNoteDialog(context, ref);
  }

  Future<void> _pickPhotoNote(BuildContext context) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    if (!context.mounted) return;
    context.push('/photo-note?path=${Uri.encodeComponent(x.path)}');
  }

  void _showEditNoteDialog(BuildContext context, VoiceNote note) {
    final titleCtrl = TextEditingController(text: note.title);
    final contentCtrl = TextEditingController(text: note.transcript);
    String? selectedProjId = note.projectId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final projects = ref.read(projectProvider).projects;

          return AlertDialog(
            title: const Text('Edit Engineering Field Note'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note Title *',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedProjId,
                    decoration: const InputDecoration(
                      labelText: 'Attach to Project (Optional)',
                      prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('General'),
                      ),
                      ...projects.map(
                        (p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(p.title, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => selectedProjId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Engineering Notes & Observations',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final updated = note.copyWith(
                    title: titleCtrl.text.trim(),
                    transcript: contentCtrl.text.trim(),
                    projectId: selectedProjId,
                    clearProjectId: selectedProjId == null,
                  );
                  await ref.read(projectProvider.notifier).updateVoiceNote(updated);
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Update Note'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditProjectNotesDialog(BuildContext context, Project project) {
    final ctrl = TextEditingController(text: project.notes);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: AppTheme.accentAmber),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Project Notes',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 8,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Key observations, measurements, decisions, follow-ups...',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(projectProvider.notifier)
                  .updateProjectNotes(project.id, ctrl.text.trim());
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Notes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Merge voice/written notes with project-attached notes into one feed.
    final projectById = {for (final p in state.projects) p.id: p};
    final entries = <_NoteEntry>[];
    for (final n in state.voiceNotes) {
      final proj = n.projectId != null ? projectById[n.projectId] : null;
      entries.add(_NoteEntry(
        voiceNote: n,
        title: n.title,
        content: n.transcript,
        timestamp: n.timestamp,
        projectId: n.projectId,
        projectTitle: proj?.title,
      ));
    }
    for (final p in state.projects) {
      if (p.notes.trim().isNotEmpty) {
        entries.add(_NoteEntry(
          project: p,
          isProjectNote: true,
          title: p.title,
          content: p.notes,
          timestamp: p.updatedAt,
          projectId: p.id,
          projectTitle: p.title,
        ));
      }
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final filtered = entries.where((e) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return e.title.toLowerCase().contains(q) ||
          e.content.toLowerCase().contains(q) ||
          (e.projectTitle?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primaryCyan, size: 28),
            SizedBox(width: 8),
            Text(
              'Field Notes & Notepad',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_camera_outlined, color: AppTheme.accentCoral),
            tooltip: 'Photo Note',
            onPressed: () => _pickPhotoNote(context),
          ),
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: AppTheme.accentAmber),
            tooltip: 'Dictate Voice Note',
            onPressed: () => VoiceMemoModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primaryCyan),
            tooltip: 'New Written Note',
            onPressed: () => _showNewTextNoteDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
          ),

          // Notes List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.note_alt_outlined,
                          size: 56,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No engineering notes recorded yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Type a field observation or tap the mic for hands-free speech dictation.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showNewTextNoteDialog(context),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Write Note'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => VoiceMemoModal.show(context),
                              icon: const Icon(Icons.mic, color: AppTheme.accentAmber),
                              label: const Text('Voice Dictate'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final isProjectNote = entry.isProjectNote;

                      return ExpressiveCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        onTap: entry.isProjectNote
                            ? () => context.push('/projects/${entry.project!.id}')
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isProjectNote)
                                  const ExpressiveBadge(
                                    label: '📌 Project Note',
                                    color: AppTheme.accentAmber,
                                    fontSize: 10,
                                  )
                                else
                                  ExpressiveBadge(
                                    label: entry.voiceNote!.durationSeconds > 0
                                        ? '🎙️ Voice (${entry.voiceNote!.durationSeconds}s)'
                                        : '📝 Written Note',
                                    color: entry.voiceNote!.durationSeconds > 0
                                        ? AppTheme.accentAmber
                                        : AppTheme.primaryCyan,
                                    fontSize: 10,
                                  ),
                                if (entry.projectId != null) ...[
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '• ${entry.projectTitle ?? ''}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  DateFormat('MMM d, y • h:mm a').format(entry.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  ),
                                ),
                                if (isProjectNote)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.accentAmber),
                                    tooltip: 'Edit Project Notes',
                                    onPressed: () => _showEditProjectNotesDialog(context, entry.project!),
                                  )
                                else ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primaryCyan),
                                    tooltip: 'Edit Note',
                                    onPressed: () => _showEditNoteDialog(context, entry.voiceNote!),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                    tooltip: 'Delete Note',
                                    onPressed: () async {
                                      final note = entry.voiceNote!;
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Note?'),
                                          content: Text(
                                            'Delete "${note.title}"? This cannot be undone.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.accentCoral,
                                              ),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await ref
                                            .read(syncStatusProvider.notifier)
                                            .deleteVoiceNoteEverywhere(note.id);
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              decodeUnicodeEscapes(entry.title),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            if (entry.voiceNote?.photoPath != null) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  child: Image.file(
                                    File(entry.voiceNote!.photoPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ],
                            if (entry.content.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              SelectableText(
                                decodeUnicodeEscapes(entry.content),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                              ),
                            ],
                            if (isProjectNote) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await ref
                                        .read(projectProvider.notifier)
                                        .updateProjectNotes(entry.project!.id, '');
                                  },
                                  icon: const Icon(Icons.delete_outline, size: 14),
                                  label: const Text('Clear Notes', style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewTextNoteDialog(context),
        child: const Icon(Icons.edit_note_rounded),
      ),
    );
  }
}

/// A unified display entry for the Field Notes feed — either a voice/written
/// `VoiceNote` or a project-attached `Project.notes` entry.
class _NoteEntry {
  final VoiceNote? voiceNote;
  final Project? project;
  final String title;
  final String content;
  final DateTime timestamp;
  final String? projectId;
  final String? projectTitle;
  final bool isProjectNote;

  const _NoteEntry({
    this.voiceNote,
    this.project,
    required this.title,
    required this.content,
    required this.timestamp,
    this.projectId,
    this.projectTitle,
    this.isProjectNote = false,
  });
}
