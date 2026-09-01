import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/voice_note.dart';
import '../../providers/project_provider.dart';
import 'searchable_dropdown.dart';

/// Shared "New Engineering Field Note" dialog, used by the Field Notes screen
/// and the universal search quick-add. [prefillTitle] / [prefillContent] are
/// populated from search text when launched from the search flow.
Future<void> showNewFieldNoteDialog(
  BuildContext context,
  WidgetRef ref, {
  String prefillTitle = '',
  String prefillContent = '',
}) {
  final titleCtrl = TextEditingController(text: prefillTitle);
  final contentCtrl = TextEditingController(text: prefillContent);
  String? selectedProjId;

  return showDialog(
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
                SearchableDropdownFormField<String>(
                  value: selectedProjId,
                  labelText: 'Attach to Project (Optional)',
                  prefixIcon: const Icon(Icons.precision_manufacturing_outlined),
                  items: projects.map((p) => p.id).toList(),
                  labelOf: (id) => projects.firstWhere((p) => p.id == id,
                      orElse: () => projects.isNotEmpty ? projects.first : throw StateError('')).title,
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
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Note'),
            ),
          ],
        );
      },
    ),
  );
}
