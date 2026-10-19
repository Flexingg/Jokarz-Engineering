import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'app_theme.dart';

/// The app's backdrop: a gentle diagonal gradient with a soft accent light in
/// the top-left corner. Scaffolds are transparent, so this is what every
/// screen sits on.
///
/// The gradient is laid out against the whole window, not the widget's own
/// box, so a page painted beside the navigation rail (or a route rising in
/// on top of another) lines up with the gradient behind it: no seams.
class FluidBackground extends StatelessWidget {
  final Widget child;
  const FluidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return _ScreenGradient(
      screen: MediaQuery.sizeOf(context),
      start: c.background,
      end: c.backgroundEnd,
      glow: c.backgroundGlow,
      child: child,
    );
  }
}

class _ScreenGradient extends SingleChildRenderObjectWidget {
  final Size screen;
  final Color start, end, glow;
  const _ScreenGradient({
    required this.screen,
    required this.start,
    required this.end,
    required this.glow,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderScreenGradient(screen, start, end, glow);

  @override
  void updateRenderObject(BuildContext context, _RenderScreenGradient r) {
    r
      ..screen = screen
      ..start = start
      ..end = end
      ..glow = glow;
  }
}

class _RenderScreenGradient extends RenderProxyBox {
  _RenderScreenGradient(this._screen, this._start, this._end, this._glow);

  Size _screen;
  Color _start, _end, _glow;

  set screen(Size v) {
    if (v == _screen) return;
    _screen = v;
    markNeedsPaint();
  }

  set start(Color v) {
    if (v == _start) return;
    _start = v;
    markNeedsPaint();
  }

  set end(Color v) {
    if (v == _end) return;
    _end = v;
    markNeedsPaint();
  }

  set glow(Color v) {
    if (v == _glow) return;
    _glow = v;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final box = offset & size;
    // Where the window's top-left is, in this box's coordinates.
    final origin = localToGlobal(Offset.zero);
    final window = (offset - origin) &
        Size(
          _screen.width > 0 ? _screen.width : size.width,
          _screen.height > 0 ? _screen.height : size.height,
        );
    final mid = Color.lerp(_start, _end, 0.5)!;
    canvas.drawRect(
      box,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_start, mid, _end],
          stops: const [0, 0.55, 1],
        ).createShader(window),
    );
    canvas.drawRect(
      box,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.85, -0.95),
          radius: 0.9,
          colors: [_glow, _glow.withValues(alpha: 0)],
        ).createShader(window),
    );
    super.paint(context, offset);
  }
}

/// A go_router page with no transition that still paints the background, so
/// a top-level screen pushed this way never shows the page underneath.
class FluidNoTransitionPage<T> extends CustomTransitionPage<T> {
  const FluidNoTransitionPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: _build,
        );

  static Widget _build(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      FluidBackground(child: child);
}
