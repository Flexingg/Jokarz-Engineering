import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/voice_note.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/voice_memo_modal.dart';

class VoiceNotesScreen extends ConsumerStatefulWidget {
  const VoiceNotesScreen({super.key});

  @override
  ConsumerState<VoiceNotesScreen> createState() => _VoiceNotesScreenState();
}

class _VoiceNotesScreenState extends ConsumerState<VoiceNotesScreen> {
  String _search = '';

  void _showNewTextNoteDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String? selectedProjId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final projects = ref.read(projectProvider).projects;

          return AlertDialog(
            title: const Text('New Engineering Field Note'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note Title *',
                      hintText: 'e.g. Line 1 Bearing Clearance Observations',
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
                        child: Text('Global Workshop Note'),
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
                      hintText: 'Type field notes, torque readings, clearance measurements, or parts needed...',
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
                  final newNote = VoiceNote(
                    title: titleCtrl.text.trim(),
                    transcript: contentCtrl.text.trim(),
                    durationSeconds: 0,
                    projectId: selectedProjId,
                  );
                  await ref.read(projectProvider.notifier).addVoiceNote(newNote);
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Note'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final notes = state.voiceNotes.where((n) {
      return _search.isEmpty ||
          n.title.toLowerCase().contains(_search.toLowerCase()) ||
          n.transcript.toLowerCase().contains(_search.toLowerCase());
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
                hintText: 'Search field notes, observations, machine logs...',
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
            child: notes.isEmpty
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
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final project = note.projectId != null
                          ? ref.read(projectProvider.notifier).getProjectById(note.projectId!)
                          : null;

                      return ExpressiveCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ExpressiveBadge(
                                  label: note.durationSeconds > 0
                                      ? '🎙️ Voice (${note.durationSeconds}s)'
                                      : '📝 Written Note',
                                  color: note.durationSeconds > 0
                                      ? AppTheme.accentAmber
                                      : AppTheme.primaryCyan,
                                  fontSize: 10,
                                ),
                                if (project != null) ...[
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '• ${project.title}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  DateFormat('MMM d, y • h:mm a').format(note.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                  onPressed: () => ref.read(projectProvider.notifier).deleteVoiceNote(note.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              note.title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            if (note.transcript.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              SelectableText(
                                note.transcript,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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
