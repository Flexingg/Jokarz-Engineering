import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// One master-detail implementation, two presentations. On
/// [WindowSizeClass.expanded] windows, [list] and [detailBuilder] render
/// side by side in a fixed-width master pane plus a flexible detail pane.
/// On [WindowSizeClass.compact] / [WindowSizeClass.medium] windows, only
/// [list] renders - selecting an item is the caller's job (typically a
/// go_router push to a detail route), which is how every list+detail
/// screen in the app already navigates on mobile (drill-down).
///
/// This widget does not own selection state - it is a pure layout. The
/// caller's [detailBuilder] decides what to show for "nothing selected"
/// (e.g. an empty-state placeholder) in the expanded layout.
class AdaptiveMasterDetail extends StatelessWidget {
  /// The list/master pane. Always shown.
  final Widget list;

  /// Builds the detail pane, shown only in the expanded two-pane layout.
  final WidgetBuilder detailBuilder;

  /// Width of the master (list) pane in the two-pane expanded layout.
  final double masterWidth;

  const AdaptiveMasterDetail({
    super.key,
    required this.list,
    required this.detailBuilder,
    this.masterWidth = 380,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!Breakpoints.isExpanded(constraints.maxWidth)) {
          // Compact/medium: master pane only.
          return list;
        }

        return Row(
          children: [
            SizedBox(width: masterWidth, child: list),
            const VerticalDivider(width: 1),
            Expanded(child: Builder(builder: detailBuilder)),
          ],
        );
      },
    );
  }
}
