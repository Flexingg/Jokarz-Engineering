import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// One data set, two presentations: a desktop-style table (via
/// [tableBuilder], typically a [DataTable] or a header row plus dense list
/// rows) on expanded windows, and a scrollable card list (via
/// [cardBuilder], one call per item) on compact/medium windows. Both
/// builders receive the same [items], so a screen wires up its data once
/// and only changes how each row's fields are arranged.
class AdaptiveDataView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, List<T> items) tableBuilder;
  final Widget Function(BuildContext context, T item, int index) cardBuilder;
  final WidgetBuilder? emptyBuilder;

  const AdaptiveDataView({
    super.key,
    required this.items,
    required this.tableBuilder,
    required this.cardBuilder,
    this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyBuilder != null) {
      return Builder(builder: emptyBuilder!);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (Breakpoints.isExpanded(constraints.maxWidth)) {
          return tableBuilder(context, items);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) => cardBuilder(context, items[index], index),
        );
      },
    );
  }
}
