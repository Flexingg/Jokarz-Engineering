import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/voice_note.dart';
import '../../models/task_item.dart';
import '../../services/speech_service.dart';
import '../../providers/project_provider.dart';
import '../widgets/searchable_dropdown.dart';

class VoiceMemoModal extends ConsumerStatefulWidget {
  final String? preselectedProjectId;

  const VoiceMemoModal({super.key, this.preselectedProjectId});

  static Future<void> show(BuildContext context, {String? preselectedProjectId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceMemoModal(preselectedProjectId: preselectedProjectId),
    );
  }

  @override
  ConsumerState<VoiceMemoModal> createState() => _VoiceMemoModalState();
}

class _VoiceMemoModalState extends ConsumerState<VoiceMemoModal>
    with SingleTickerProviderStateMixin {
  final SpeechService _speechService = SpeechService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _transcriptController = TextEditingController();
  String? _selectedProjectId;
  bool _isRecording = false;
  bool _splitIntoTasks = false;
  late AnimationController _animController;
  final int _recordSeconds = 0;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.preselectedProjectId;
    _titleController.text = 'Workshop Dictation #${DateTime.now().minute}';
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _speechService.stopListening();
    _titleController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  void _toggleRecording() async {
    if (_isRecording) {
      await _speechService.stopListening();
      setState(() {
        _isRecording = false;
      });
    } else {
      setState(() {
        _isRecording = true;
      });
      await _speechService.startListening(
        onResult: (text) {
          setState(() {
            _transcriptController.text = text;
          });
        },
      );
    }
  }

  void _saveMemo() async {
    final transcript = _transcriptController.text.trim();
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please speak or enter a voice transcript.')),
      );
      return;
    }

    final note = VoiceNote(
      title: _titleController.text.trim().isEmpty
          ? 'Workshop Memo'
          : _titleController.text.trim(),
      transcript: transcript,
      durationSeconds: _recordSeconds > 0 ? _recordSeconds : 10,
      projectId: _selectedProjectId,
    );

    final notifier = ref.read(projectProvider.notifier);
    await notifier.addVoiceNote(note);

    // Optional: split the dictation into separate tasks on the selected project.
    // Speak "slash" (or type "/") between items; each becomes its own task.
    var tasksCreated = 0;
    if (_splitIntoTasks && _selectedProjectId != null) {
      final segments = transcript
          .split(RegExp(r'/\s*|\bslash\b', caseSensitive: false))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      for (final seg in segments) {
        await notifier.addTask(_selectedProjectId!, TaskItem(description: seg));
        tasksCreated++;
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
      final project =
          _selectedProjectId == null ? null : notifier.getProjectById(_selectedProjectId!);
      final message = tasksCreated > 0
          ? 'Added $tasksCreated task${tasksCreated == 1 ? '' : 's'} to "${project?.title ?? 'project'}" + note saved'
          : (_splitIntoTasks
              ? 'Note saved (select a project to split dictation into tasks)'
              : (_selectedProjectId != null
                  ? 'Voice Memo logged & attached to project!'
                  : 'Voice Memo saved to Workshop Notes!'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.of(context).emerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(projectProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.of(context).surface : AppTheme.of(context).surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
          border: Border.all(
            color: isDark ? AppTheme.of(context).border : AppTheme.of(context).border,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(Icons.mic, color: AppTheme.of(context).amber, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Workshop Voice Logger',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Hands-free speech dictation for lab & workbench notes',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title Field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Note Title / Topic',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),

            // Project Selector (searchable)
            Builder(builder: (context) {
              final projectTitles = {
                for (final p in state.projects) p.id: p.title,
              };
              return SearchableDropdownFormField<String>(
                value: _selectedProjectId,
                items: state.projects.map((p) => p.id).toList(),
                labelOf: (id) => projectTitles[id] ?? 'Project',
                onChanged: (val) {
                  setState(() {
                    _selectedProjectId = val;
                  });
                },
                labelText: 'Attach to Engineering Project (Optional)',
                prefixIcon: const Icon(Icons.folder_outlined),
              );
            }),
            const SizedBox(height: 16),

            // Live Transcript Box
            TextField(
              controller: _transcriptController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Transcript / Dictation Content',
                hintText: _isRecording
                    ? 'Listening... Speak your observations, measurements, or specs...'
                    : 'Tap microphone below to record speech, or type here...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),

            // Split dictation into tasks
            CheckboxListTile(
              value: _splitIntoTasks,
              onChanged: (v) => setState(() => _splitIntoTasks = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppTheme.of(context).emerald,
              title: const Text('Split dictation into tasks',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: const Text(
                  'Speak "slash" between items to make each a separate task '
                  '(requires a selected project).',
                  style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(height: 12),

            // Recording Pulsing Button & Action Buttons
            Row(
              children: [
                // Record Mic Button
                GestureDetector(
                  onTap: _toggleRecording,
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording
                              ? AppTheme.of(context).coral
                              : (isDark ? AppTheme.of(context).surfaceHighlight : AppTheme.of(context).surfaceHighlight),
                          border: Border.all(
                            color: _isRecording
                                ? AppTheme.of(context).coral
                                : AppTheme.of(context).primary,
                            width: 2,
                          ),
                          boxShadow: _isRecording
                              ? [
                                  BoxShadow(
                                    color: AppTheme.of(context).coral.withValues(
                                      alpha: 0.2 + (_animController.value * 0.4),
                                    ),
                                    blurRadius: 18 * _animController.value + 4,
                                    spreadRadius: 4 * _animController.value,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: _isRecording ? Colors.white : AppTheme.of(context).primary,
                          size: 26,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Save Action
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveMemo,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Note to Workshop'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
