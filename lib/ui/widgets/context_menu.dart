import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// One entry in a right-click menu. A null [onTap] shows it disabled.
class MenuAction {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;

  /// Draws a divider above this entry.
  final bool dividerBefore;

  const MenuAction(
    this.label,
    this.icon,
    this.onTap, {
    this.danger = false,
    this.dividerBefore = false,
  });
}

/// Shows [actions] as a popup menu at [globalPosition] and runs the chosen one.
Future<void> showContextMenu(
  BuildContext context,
  Offset globalPosition,
  List<MenuAction> actions,
) async {
  if (actions.isEmpty) return;
  final colors = AppTheme.of(context);
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final items = <PopupMenuEntry<int>>[];
  for (var i = 0; i < actions.length; i++) {
    final a = actions[i];
    if (a.dividerBefore) items.add(const PopupMenuDivider());
    final color = a.danger ? colors.coral : null;
    items.add(
      PopupMenuItem<int>(
        value: i,
        enabled: a.onTap != null,
        height: 40,
        child: Row(
          children: [
            Icon(a.icon, size: 18, color: color ?? colors.textSecondary),
            const SizedBox(width: 12),
            Text(a.label, style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }
  final chosen = await showMenu<int>(
    context: context,
    position: RelativeRect.fromRect(
      globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: items,
  );
  if (chosen != null) actions[chosen].onTap?.call();
}
