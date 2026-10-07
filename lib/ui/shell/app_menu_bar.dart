import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/key_bindings.dart';
import '../../providers/keybindings_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../screens/diagnostics_screen.dart';
import '../widgets/sync_status_badge.dart';
import 'app_actions.dart';

/// Desktop menu bar (File / View / Go / Help). Every item calls the same
/// [dispatchAppAction] the keyboard shortcuts use, and shows the user's
/// current binding for it.
class AppMenuBar extends ConsumerWidget {
  const AppMenuBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppTheme.of(context);
    final keys = ref.watch(keyBindingsProvider);

    Widget item(
      String label, {
      String? action,
      VoidCallback? onTap,
      IconData? icon,
    }) {
      final combo = action == null ? null : keys[action];
      return MenuItemButton(
        leadingIcon: icon == null ? null : Icon(icon, size: 18),
        trailingIcon: combo == null
            ? null
            : Text(
                prettyCombo(combo),
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
        onPressed: onTap ?? () => dispatchAppAction(ref, action!),
        child: Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Text(label),
        ),
      );
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          MenuBar(
            style: const MenuStyle(
              padding: WidgetStatePropertyAll(EdgeInsets.zero),
              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
              elevation: WidgetStatePropertyAll(0),
            ),
            children: [
              SubmenuButton(
                menuChildren: [
                  item(
                    'New project',
                    action: 'createProject',
                    icon: Icons.add_box_outlined,
                  ),
                  item(
                    'New order',
                    action: 'createOrder',
                    icon: Icons.add_shopping_cart_rounded,
                  ),
                  item(
                    'New note',
                    action: 'createNote',
                    icon: Icons.note_add_outlined,
                  ),
                  const Divider(height: 8),
                  item(
                    'Backup and restore...',
                    icon: Icons.archive_outlined,
                    onTap: () => appRouter.go('/settings'),
                  ),
                ],
                child: const Text('File'),
              ),
              SubmenuButton(
                menuChildren: [
                  item(
                    'Search and commands',
                    action: 'palette',
                    icon: Icons.keyboard_command_key_rounded,
                  ),
                  item(
                    'Toggle sidebar',
                    action: 'toggleSidebar',
                    icon: Icons.view_sidebar_outlined,
                  ),
                  item(
                    'Customize dashboard...',
                    action: 'customizeDashboard',
                    icon: Icons.tune_rounded,
                  ),
                  const Divider(height: 8),
                  item(
                    'Calendar',
                    icon: Icons.calendar_month_rounded,
                    onTap: () => appRouter.push('/calendar'),
                  ),
                  item(
                    'Inbox',
                    icon: Icons.inbox_rounded,
                    onTap: () => appRouter.push('/inbox'),
                  ),
                ],
                child: const Text('View'),
              ),
              SubmenuButton(
                menuChildren: [
                  item('Dashboard', action: 'tabDashboard'),
                  item('Projects', action: 'tabProjects'),
                  item('Open Orders', action: 'tabOrders'),
                  item('Workbench Tools', action: 'tabWorkbench'),
                  item('BAMM Orders', action: 'tabBamm'),
                  item('Notes', action: 'tabNotes'),
                  item('Settings', action: 'tabSettings'),
                ],
                child: const Text('Go'),
              ),
              SubmenuButton(
                menuChildren: [
                  item(
                    'Keyboard shortcuts',
                    icon: Icons.keyboard_alt_outlined,
                    onTap: () => appRouter.go('/settings'),
                  ),
                  item(
                    'Diagnostics log',
                    icon: Icons.bug_report_outlined,
                    onTap: () {
                      final ctx = appRootContext;
                      if (ctx != null) {
                        Navigator.of(ctx).push(
                          MaterialPageRoute(
                            builder: (_) => const DiagnosticsScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ],
                child: const Text('Help'),
              ),
            ],
          ),
          const Spacer(),
          const SyncStatusBadge(compact: true),
        ],
      ),
    );
  }
}
