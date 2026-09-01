import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../models/inbox_item.dart';
import '../../providers/project_provider.dart';
import '../../services/speech_service.dart';

/// Instant floor brain-dump modal: type or speak a quick thought,
/// which saves directly to the Triage Inbox without filling out forms.
class InboxQuickCaptureModal extends ConsumerStatefulWidget {
  const InboxQuickCaptureModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const InboxQuickCaptureModal(),
    );
  }

  @override
  ConsumerState<InboxQuickCaptureModal> createState() =>
      _InboxQuickCaptureModalState();
}

class _InboxQuickCaptureModalState extends ConsumerState<InboxQuickCaptureModal> {
  final _textController = TextEditingController();
  final _speechService = SpeechService();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speechService.initialize();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speechService.stopListening();
      setState(() => _isListening = false);
    } else {
      final available = await _speechService.initialize();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available.')),
          );
        }
        return;
      }
      setState(() => _isListening = true);
      await _speechService.startListening(
        onResult: (text) {
          if (mounted) {
            setState(() {
              _textController.text = text;
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            });
          }
        },
      );
    }
  }


  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_isListening) {
      await _speechService.stopListening();
    }

    final item = InboxItem(text: text);
    await ref.read(projectProvider.notifier).addInboxItem(item);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.of(context).surface : AppTheme.of(context).surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: AppTheme.of(context).primary.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.flash_on_rounded, color: AppTheme.of(context).amber, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Quick Note',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/inbox');
                  },
                  icon: const Icon(Icons.inbox_rounded, size: 16),
                  label: const Text('Inbox'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.of(context).primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Input field
            TextField(
              controller: _textController,
              autofocus: true,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Line 2 filler bearing vibrating, order spare 6205RS or check with Mike tomorrow...',
                hintStyle: TextStyle(
                  color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: isDark ? AppTheme.of(context).surfaceVariant : AppTheme.of(context).surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),

            // Action row
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _toggleListening,
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_rounded,
                    color: _isListening ? Colors.redAccent : AppTheme.of(context).primary,
                  ),
                  tooltip: _isListening ? 'Stop Recording' : 'Voice Dictate',
                ),
                const SizedBox(width: 8),
                if (_isListening)
                  const Text(
                    'Listening...',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Save to Inbox'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.of(context).emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
