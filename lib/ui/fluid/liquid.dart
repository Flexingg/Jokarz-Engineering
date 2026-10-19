import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../motion/motion.dart';

/// A selection highlight that flows between positions like a drop of
/// liquid: the leading edge leaves first and the trailing edge catches up, so
/// it stretches in the direction of travel and then settles (with the app's
/// spring). Put it in a [Stack] behind the items; [rect] is the target in the
/// Stack's coordinates.
class LiquidIndicator extends StatefulWidget {
  final Rect? rect;
  final Decoration decoration;
  const LiquidIndicator({
    super.key,
    required this.rect,
    required this.decoration,
  });

  @override
  State<LiquidIndicator> createState() => _LiquidIndicatorState();
}

class _LiquidIndicatorState extends State<LiquidIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    value: 1,
  );
  Rect? _from;
  Rect? _to;

  @override
  void initState() {
    super.initState();
    _to = widget.rect;
  }

  @override
  void didUpdateWidget(LiquidIndicator old) {
    super.didUpdateWidget(old);
    final next = widget.rect;
    if (next == _to) return;
    final motion = Motion.of(context);
    if (_to == null || next == null || !motion.enabled) {
      _from = null;
      _to = next;
      _c.value = 1;
      return;
    }
    _from = _current(); // interruptible: start from wherever it is now
    _to = next;
    _c.duration = motion.d(460);
    _c.forward(from: 0);
  }

  Rect? _current() {
    final to = _to;
    final from = _from;
    if (to == null) return null;
    if (from == null || _c.value >= 1) return to;
    return _at(from, to, _c.value, Motion.of(context).spring);
  }

  /// Leading edge on an early interval, trailing edge on a later one.
  static Rect _at(Rect from, Rect to, double t, Curve spring) {
    final lead = spring.transform(const Interval(0, 0.72).transform(t));
    final trail = spring.transform(const Interval(0.18, 1).transform(t));
    double l(double a, double b, double k) => a + (b - a) * k;
    final movingRight = to.center.dx >= from.center.dx;
    final movingDown = to.center.dy >= from.center.dy;
    return Rect.fromLTRB(
      l(from.left, to.left, movingRight ? trail : lead),
      l(from.top, to.top, movingDown ? trail : lead),
      l(from.right, to.right, movingRight ? lead : trail),
      l(from.bottom, to.bottom, movingDown ? lead : trail),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final r = _current();
        if (r == null) return const SizedBox.shrink();
        return Positioned.fromRect(
          rect: r,
          child: IgnorePointer(
            child: DecoratedBox(decoration: widget.decoration),
          ),
        );
      },
    );
  }
}

/// Decoration for a lit selection pill: accent wash, accent edge, soft glow.
BoxDecoration litPill(
  AppColors c, {
  double radius = AppTheme.radiusFull,
  bool glow = true,
}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  color: c.primary.withValues(alpha: 0.16),
  border: Border.all(color: c.primary.withValues(alpha: 0.55)),
  boxShadow: glow
      ? [BoxShadow(color: c.primary.withValues(alpha: 0.20), blurRadius: 12)]
      : null,
);

/// Measures where each of [count] children ended up inside the enclosing
/// Stack, after layout, so a [LiquidIndicator] can move between them.
class _RectTracker {
  final List<GlobalKey> keys;
  _RectTracker(int count) : keys = List.generate(count, (_) => GlobalKey());

  void resize(int count) {
    while (keys.length < count) {
      keys.add(GlobalKey());
    }
    while (keys.length > count) {
      keys.removeLast();
    }
  }

  Rect? rectOf(int index, RenderBox? stack) {
    if (stack == null || index < 0 || index >= keys.length) return null;
    final box = keys[index].currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !stack.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: stack);
    return topLeft & box.size;
  }
}

/// A single-choice segmented control in the fluid style: a glass pill track
/// whose selected segment is a lit pill that flows between choices. A
/// drop-in for single-select [SegmentedButton] uses (same segments API).
class FluidSegmentedButton<T> extends StatefulWidget {
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;

  /// Accepted for drop-in compatibility; a compact [ButtonStyle.visualDensity]
  /// makes the control shorter.
  final ButtonStyle? style;
  final bool showSelectedIcon;

  const FluidSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    this.onSelectionChanged,
    this.style,
    this.showSelectedIcon = false,
  });

  @override
  State<FluidSegmentedButton<T>> createState() =>
      _FluidSegmentedButtonState<T>();
}

class _FluidSegmentedButtonState<T> extends State<FluidSegmentedButton<T>> {
  final _stackKey = GlobalKey();
  late final _RectTracker _tracker = _RectTracker(widget.segments.length);
  Rect? _rect;

  int get _index =>
      widget.segments.indexWhere((s) => widget.selected.contains(s.value));

  void _measure() {
    if (!mounted) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final r = _tracker.rectOf(_index, stack)?.deflate(3);
    if (r != _rect) setState(() => _rect = r);
  }

  @override
  Widget build(BuildContext context) {
    _tracker.resize(widget.segments.length);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final c = AppTheme.of(context);
    final compact = widget.style?.visualDensity == VisualDensity.compact;
    final height = compact ? 36.0 : 42.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fill = constraints.hasTightWidth;
        final children = <Widget>[];
        for (var i = 0; i < widget.segments.length; i++) {
          final seg = widget.segments[i];
          final on = widget.selected.contains(seg.value);
          Widget cell = _Segment(
            key: _tracker.keys[i],
            segment: seg,
            selected: on,
            height: height,
            compact: compact,
            onTap: seg.enabled && widget.onSelectionChanged != null && !on
                ? () {
                    HapticFeedback.selectionClick();
                    widget.onSelectionChanged!({seg.value});
                  }
                : null,
          );
          if (fill) {
            cell = Expanded(child: cell);
          } else if (constraints.hasBoundedWidth) {
            // Natural width when it fits; shrinks (labels ellipsize) when not.
            cell = Flexible(child: cell);
          }
          children.add(cell);
        }
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: c.surfaceHighlight,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(color: c.border),
          ),
          child: Stack(
            key: _stackKey,
            children: [
              LiquidIndicator(rect: _rect, decoration: litPill(c, glow: false)),
              Row(
                mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Segment<T> extends StatefulWidget {
  final ButtonSegment<T> segment;
  final bool selected;
  final double height;
  final bool compact;
  final VoidCallback? onTap;
  const _Segment({
    super.key,
    required this.segment,
    required this.selected,
    required this.height,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_Segment<T>> createState() => _SegmentState<T>();
}

class _SegmentState<T> extends State<_Segment<T>> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final motion = Motion.of(context);
    final seg = widget.segment;
    final color = !seg.enabled
        ? c.textSecondary.withValues(alpha: 0.5)
        : widget.selected
        ? c.primary
        : c.textPrimary;
    final style = TextStyle(
      fontSize: 13,
      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
      color: color,
    );
    Widget content = Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (seg.icon != null)
            IconTheme.merge(
              data: IconThemeData(color: color, size: 18),
              child: seg.icon!,
            ),
          if (seg.icon != null && seg.label != null) const SizedBox(width: 6),
          if (seg.label != null)
            Flexible(
              child: DefaultTextStyle.merge(
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: seg.label!,
              ),
            ),
        ],
      ),
    );
    content = Semantics(
      button: true,
      selected: widget.selected,
      enabled: seg.enabled,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onTap,
          child: SizedBox(
            height: widget.height,
            child: AnimatedScale(
              scale: _down ? 0.94 : 1,
              duration: _down ? motion.d(90) : motion.d(380),
              curve: _down ? Curves.easeOut : motion.spring,
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
    if (seg.tooltip != null)
      content = Tooltip(message: seg.tooltip!, child: content);
    return content;
  }
}

/// One destination of the [FluidNavIsland].
class IslandDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const IslandDestination(this.icon, this.selectedIcon, this.label);
}

/// The phone navigation "island": a floating glass pill. The selected
/// destination shows its label inside a lit pill that flows to the next one.
/// Slide a finger along the bar to scrub between sections; release to go.
class FluidNavIsland extends StatefulWidget {
  final List<IslandDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const FluidNavIsland({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<FluidNavIsland> createState() => _FluidNavIslandState();
}

class _FluidNavIslandState extends State<FluidNavIsland> {
  final _stackKey = GlobalKey();
  late final _RectTracker _tracker = _RectTracker(widget.destinations.length);
  Rect? _rect;
  int? _scrub;

  int get _shown => _scrub ?? widget.selectedIndex;

  void _measure() {
    if (!mounted) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final r = _tracker.rectOf(_shown, stack)?.deflate(6);
    if (r != _rect) setState(() => _rect = r);
  }

  int? _indexAt(Offset global) {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null) return null;
    final local = stack.globalToLocal(global);
    for (var i = 0; i < _tracker.keys.length; i++) {
      final r = _tracker.rectOf(i, stack);
      if (r != null && local.dx >= r.left && local.dx <= r.right) return i;
    }
    return null;
  }

  void _scrubTo(Offset global) {
    final i = _indexAt(global);
    if (i != null && i != _scrub) {
      HapticFeedback.selectionClick();
      setState(() => _scrub = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    _tracker.resize(widget.destinations.length);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final c = AppTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (d) => _scrubTo(d.globalPosition),
      onHorizontalDragUpdate: (d) => _scrubTo(d.globalPosition),
      onHorizontalDragEnd: (_) {
        final i = _scrub;
        setState(() => _scrub = null);
        if (i != null && i != widget.selectedIndex) widget.onSelected(i);
      },
      onHorizontalDragCancel: () => setState(() => _scrub = null),
      child: SizedBox(
        height: 64,
        child: Stack(
          key: _stackKey,
          children: [
            LiquidIndicator(rect: _rect, decoration: litPill(c)),
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < widget.destinations.length; i++)
                    // The selected section gets room for its label; the lit
                    // pill flows from the old slot to the new one.
                    Expanded(
                      key: _tracker.keys[i],
                      flex: i == _shown ? 26 : 10,
                      child: _IslandItem(
                        dest: widget.destinations[i],
                        selected: i == _shown,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onSelected(i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IslandItem extends StatefulWidget {
  final IslandDestination dest;
  final bool selected;
  final VoidCallback onTap;
  const _IslandItem({
    required this.dest,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_IslandItem> createState() => _IslandItemState();
}

class _IslandItemState extends State<_IslandItem> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final motion = Motion.of(context);
    final color = widget.selected ? c.primary : c.textSecondary;
    return Tooltip(
      message: widget.dest.label,
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.dest.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? 0.9 : 1,
            duration: _down ? motion.d(90) : motion.d(380),
            curve: _down ? Curves.easeOut : motion.spring,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.selected ? widget.dest.selectedIcon : widget.dest.icon,
                  size: 22,
                  color: color,
                ),
                // The label slides out of the icon when selected.
                Flexible(
                  child: AnimatedSize(
                    duration: motion.d(320),
                    curve: motion.spring,
                    child: widget.selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              widget.dest.label,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
