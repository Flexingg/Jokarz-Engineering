import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ui_prefs_provider.dart';
import '../../theme/app_theme.dart';

/// A right-hand side panel whose width the user can drag, remembered per
/// screen ([prefKey]) so dense screens (BAMM) can run wider than light ones.
class ResizablePanel extends ConsumerStatefulWidget {
  final String prefKey;
  final double defaultWidth;
  final double minWidth;
  final double maxWidth;
  final Widget child;

  const ResizablePanel({
    super.key,
    required this.prefKey,
    required this.defaultWidth,
    required this.child,
    this.minWidth = 340,
    this.maxWidth = 760,
  });

  @override
  ConsumerState<ResizablePanel> createState() => _ResizablePanelState();
}

class _ResizablePanelState extends ConsumerState<ResizablePanel> {
  double? _dragWidth;

  double _clamp(double w, double available) {
    // Never take more than ~70% of the space beside the panel.
    final hi = widget.maxWidth.clamp(
      widget.minWidth,
      available * 0.7 < widget.minWidth ? widget.minWidth : available * 0.7,
    );
    return w.clamp(widget.minWidth, hi);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final saved = ref.watch(
      uiPrefsProvider.select((p) => p.panelWidths[widget.prefKey]),
    );
    return LayoutBuilder(
      builder: (context, c) {
        final available = c.hasBoundedWidth ? c.maxWidth : 1400.0;
        final width = _clamp(
          _dragWidth ?? saved ?? widget.defaultWidth,
          available,
        );
        return SizedBox(
          width: width,
          child: Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) => setState(
                    () => _dragWidth = _clamp(
                      (_dragWidth ?? width) - d.delta.dx,
                      available,
                    ),
                  ),
                  onHorizontalDragEnd: (_) {
                    final w = _dragWidth;
                    if (w == null) return;
                    ref
                        .read(uiPrefsProvider.notifier)
                        .update(
                          (p) => p.copyWith(
                            panelWidths: {...p.panelWidths, widget.prefKey: w},
                          ),
                        );
                    setState(() => _dragWidth = null);
                  },
                  child: SizedBox(
                    width: 10,
                    child: Center(
                      child: Container(
                        width: 2,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: widget.child),
            ],
          ),
        );
      },
    );
  }
}
