import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/voice_memo_modal.dart';

class VoiceNotesScreen extends ConsumerWidget {
  const VoiceNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workshop Voice Notes & Field Logs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: AppTheme.accentAmber),
            onPressed: () => VoiceMemoModal.show(context),
            tooltip: 'Dictate Note',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.voiceNotes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic_none_outlined, size: 56, color: AppTheme.accentAmber),
                  const SizedBox(height: 16),
                  const Text(
                    'No voice notes recorded yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Dictate hands-free measurements, ideas, and workbench observations.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => VoiceMemoModal.show(context),
                    icon: const Icon(Icons.mic),
                    label: const Text('Record First Memo'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: state.voiceNotes.length,
              itemBuilder: (context, index) {
                final note = state.voiceNotes[index];
                final linkedProject = note.projectId != null
                    ? notifier.getProjectById(note.projectId!)
                    : null;

                return ExpressiveCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.mic, color: AppTheme.accentAmber, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  DateFormat('EEEE, MMM d, y • h:mm a').format(note.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                            onPressed: () => notifier.deleteVoiceNote(note.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        note.transcript,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                      if (linkedProject != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.link_rounded, size: 14, color: AppTheme.primaryCyan),
                            const SizedBox(width: 4),
                            Text(
                              'Attached to: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                            ExpressiveBadge(
                              label: linkedProject.title,
                              color: AppTheme.primaryCyan,
                              fontSize: 10,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => VoiceMemoModal.show(context),
        backgroundColor: AppTheme.accentAmber,
        foregroundColor: Colors.black87,
        child: const Icon(Icons.mic_rounded),
      ),
    );
  }
}
