import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/key_bindings.dart';
import '../../providers/keybindings_provider.dart';
import '../../router/app_router.dart';
import 'note_dialogs.dart';
import 'order_dialogs.dart';

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
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final combo = comboForEvent(event);
        if (combo == null) return KeyEventResult.ignored;
        final String comboStr = combo;
        String? actionId;
        bindings.forEach((id, c) {
          if (c == comboStr) actionId = id;
        });
        if (actionId == null) return KeyEventResult.ignored;
        _dispatch(ref, actionId!);
        return KeyEventResult.handled;
      },
      child: child,
    );
  }

  void _dispatch(WidgetRef ref, String actionId) {
    final router = appRouter;
    switch (actionId) {
      case 'search':
        router.push('/search');
        break;
      case 'createNote':
        final ctx = appRootContext;
        if (ctx != null) showNewFieldNoteDialog(ctx, ref);
        break;
      case 'createProject':
        router.push('/projects/new');
        break;
      case 'createOrder':
        final ctx = appRootContext;
        if (ctx != null) showStandaloneOrderDialog(ctx, ref);
        break;
      case 'tabDashboard':
        router.go('/');
        break;
      case 'tabProjects':
        router.go('/projects');
        break;
      case 'tabOrders':
        router.go('/orders');
        break;
      case 'tabWorkbench':
        router.go('/workbench');
        break;
      case 'tabNotes':
        router.go('/voice-notes');
        break;
      case 'tabSettings':
        router.go('/settings');
        break;
    }
  }
}
