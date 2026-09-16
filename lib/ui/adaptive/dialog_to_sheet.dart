import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// Shows [builder] as a centered dialog on expanded windows (desktop) and
/// as a full-height draggable bottom sheet on compact/medium windows
/// (mobile) - the same content and actions, presented the way each form
/// factor expects. Callers that build their content once as a widget and
/// pass it here get both presentations for free.
Future<T?> showAdaptiveDialogOrSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (Breakpoints.isExpanded(width)) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: barrierDismissible,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => builder(ctx),
    ),
  );
}
