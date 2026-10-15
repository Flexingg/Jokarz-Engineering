import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/key_bindings.dart';
import '../../providers/keybindings_provider.dart';
import '../shell/app_actions.dart';

/// Wraps the whole app and dispatches configurable desktop keyboard shortcuts
/// to navigation and quick-create actions. Placed via `MaterialApp.builder` so
/// it is an ancestor of the Navigator and receives bubbled key events.
class AppShortcuts extends ConsumerWidget {
  final Widget child;
  const AppShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindings = ref.watch(keyBindingsProvider);

    return Focus(
      // Autofocus so shortcuts work from a cold start, before anything has been
      // clicked; key events from focused descendants still bubble up here.
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final combo = comboForEvent(event);
        if (combo == null) return KeyEventResult.ignored;
        final String comboStr = combo;
        String? actionId;
        bindings.forEach((id, c) {
          if (c == comboStr) actionId = id;
        });
        // Familiar "find" keys open the command palette too, unless rebound.
        if (actionId == null &&
            (comboStr == 'ctrl+s' || comboStr == 'ctrl+f' || comboStr == 'ctrl+shift+s')) {
          actionId = 'palette';
        }
        if (actionId == null) return KeyEventResult.ignored;
        dispatchAppAction(ref, actionId!);
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
