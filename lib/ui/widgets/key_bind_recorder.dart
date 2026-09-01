import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/key_bindings.dart';
import '../../providers/keybindings_provider.dart';

/// A single configurable key binding row with a "Record" button that captures
/// the next pressed key combination and saves it.
class KeyBindRecorder extends ConsumerStatefulWidget {
  final String actionId;
  const KeyBindRecorder({super.key, required this.actionId});

  @override
  ConsumerState<KeyBindRecorder> createState() => _KeyBindRecorderState();
}

class _KeyBindRecorderState extends ConsumerState<KeyBindRecorder> {
  bool _recording = false;

  @override
  Widget build(BuildContext context) {
    final bindings = ref.watch(keyBindingsProvider);
    final combo = bindings[widget.actionId] ?? '—';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        _recording ? Icons.graphic_eq_rounded : Icons.keyboard_command_key_rounded,
        color: _recording ? AppTheme.of(context).coral : AppTheme.of(context).primary,
        size: 20,
      ),
      title: Text(
        keyBindingsLabels[widget.actionId] ?? widget.actionId,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        _recording ? 'Press the new key combination…' : combo,
        style: TextStyle(
          fontSize: 11,
          color: _recording
              ? AppTheme.of(context).coral
              : (Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.of(context).textSecondary
                  : AppTheme.of(context).textSecondary),
          fontFamily: 'monospace',
        ),
      ),
      trailing: _recording
          ? Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final c = comboForEvent(event);
                if (c != null && c.isNotEmpty) {
                  ref
                      .read(keyBindingsProvider.notifier)
                      .setBinding(widget.actionId, c);
                  setState(() => _recording = false);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SizedBox(
                width: 90,
                height: 30,
                child: Center(
                  child: Text(
                    'Listening…',
                    style: TextStyle(fontSize: 12, color: AppTheme.of(context).coral),
                  ),
                ),
              ),
            )
          : OutlinedButton(
              onPressed: () => setState(() => _recording = true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Record', style: TextStyle(fontSize: 11)),
            ),
    );
  }
}
