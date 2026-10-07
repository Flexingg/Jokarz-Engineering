import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ui_prefs_provider.dart';
import '../../router/app_router.dart';
import '../widgets/command_palette.dart';
import '../widgets/dashboard_customizer.dart';
import '../widgets/note_dialogs.dart';
import '../widgets/order_dialogs.dart';

/// The single place app-wide actions are performed. Keyboard shortcuts, the
/// desktop menu bar and the command palette all call [dispatchAppAction], so a
/// new action only has to be wired once.
///
/// Ids match `defaultKeyBindings` where an action has a shortcut.
void dispatchAppAction(WidgetRef ref, String actionId) {
  final router = appRouter;
  switch (actionId) {
    case 'palette':
      showCommandPalette(ref);
    case 'toggleSidebar':
      ref
          .read(uiPrefsProvider.notifier)
          .update((p) => p.copyWith(railCollapsed: !p.railCollapsed));
    case 'customizeDashboard':
      router.go('/');
      final ctx = appRootContext;
      if (ctx != null) showDashboardCustomizer(ctx);
    case 'createNote':
      final ctx = appRootContext;
      if (ctx != null) showNewFieldNoteDialog(ctx);
    case 'createProject':
      router.push('/projects/new');
    case 'createOrder':
      final ctx = appRootContext;
      if (ctx != null) showStandaloneOrderDialog(ctx);
    case 'tabDashboard':
      router.go('/');
    case 'tabProjects':
      router.go('/projects');
    case 'tabOrders':
      router.go('/orders');
    case 'tabWorkbench':
      router.go('/workbench');
    case 'tabNotes':
      router.go('/voice-notes');
    case 'tabSettings':
      router.go('/settings');
    case 'tabBamm':
      router.go('/bamm');
  }
}
