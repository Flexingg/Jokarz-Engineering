import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../motion/motion.dart';

/// Frosted glass for floating chrome (the nav island and rail, side panels,
/// the bulk-action bar): a blur of whatever is behind, a translucent fill, a
/// thin luminous edge that is brighter at the top ("contour glow"), and a
/// soft shadow. With reduce transparency on, it is a plain opaque surface.
///
/// Keep it to floating chrome: content cards use the calm card fill instead,
/// and lists never get one blur per row.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool shadow;

  /// Accent edge and glow, for a selected/active element.
  final bool selected;

  /// Override the fill (e.g. a tinted glass).
  final Color? fill;

  const Glass({
    super.key,
    required this.child,
    this.radius = AppTheme.radiusLg,
    this.blur = AppTheme.blurRegular,
    this.padding,
    this.margin,
    this.shadow = true,
    this.selected = false,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(color: fill ?? c.glass, borderRadius: shape),
      child: CustomPaint(
        foregroundPainter: _ContourPainter(
          radius: radius,
          top: selected ? c.primary.withValues(alpha: 0.6) : c.glassEdgeTop,
          bottom: selected ? c.primary.withValues(alpha: 0.35) : c.glassEdgeBottom,
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
    if (c.blurGlass && blur > 0) {
      body = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2),
        child: body,
      );
    }
    body = ClipRRect(borderRadius: shape, child: body);
    final shadows = <BoxShadow>[
      if (shadow)
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.40 : 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      if (selected)
        BoxShadow(
          color: c.primary.withValues(alpha: dark ? 0.18 : 0.25),
          blurRadius: 12,
        ),
    ];
    return Container(
      margin: margin,
      decoration: shadows.isEmpty
          ? null
          : BoxDecoration(borderRadius: shape, boxShadow: shadows),
      child: Material(type: MaterialType.transparency, child: body),
    );
  }
}

/// A 1px stroke whose color runs from [top] to [bottom]: light catching the
/// upper edge of a glass pane.
class _ContourPainter extends CustomPainter {
  final double radius;
  final Color top, bottom;
  const _ContourPainter({required this.radius, required this.top, required this.bottom});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final r = radius.clamp(0.0, size.shortestSide / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ContourPainter old) =>
      old.top != top || old.bottom != bottom || old.radius != radius;
}

/// The contour edge as a [BoxDecoration] border for content cards, which
/// get the calm card fill rather than blur.
Border contourBorder(AppColors c) => Border.all(color: c.border);

/// Physical press feedback: compresses while held and springs back with a
/// little overshoot on release. Wrap any tappable thing that is not already a
/// themed button.
class PressScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  const PressScale({super.key, required this.child, this.pressedScale = 0.96});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: _down ? motion.d(90) : motion.d(380),
        curve: _down ? Curves.easeOut : motion.spring,
        child: widget.child,
      ),
    );
  }
}
