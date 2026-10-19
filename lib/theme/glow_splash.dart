import 'package:flutter/material.dart';

/// Touch glow: a soft radial light that blooms from the touch point, stays
/// while the finger is down, and fades out on release. Replaces the default
/// ink ripple app-wide (set as `ThemeData.splashFactory`).
class GlowSplash extends InteractiveInkFeature {
  static const InteractiveInkFeatureFactory splashFactory = _GlowSplashFactory();

  static const Duration _bloom = Duration(milliseconds: 180);
  static const Duration _fade = Duration(milliseconds: 250);

  final Offset _origin;
  final double _targetRadius;
  final BorderRadius _borderRadius;
  final ShapeBorder? _customBorder;
  final RectCallback? _rectCallback;
  final TextDirection _textDirection;
  late final AnimationController _radius;
  late final AnimationController _alpha;

  GlowSplash({
    required MaterialInkController controller,
    required super.referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    super.onRemoved,
  })  : _origin = position,
        _borderRadius = borderRadius ?? BorderRadius.zero,
        _customBorder = customBorder,
        _rectCallback = rectCallback,
        _textDirection = textDirection,
        _targetRadius = radius ?? _defaultRadius(referenceBox, rectCallback),
        super(controller: controller, color: color) {
    _radius = AnimationController(duration: _bloom, vsync: controller.vsync)
      ..addListener(controller.markNeedsPaint)
      ..forward();
    _alpha = AnimationController(duration: _fade, vsync: controller.vsync, value: 1)
      ..addListener(controller.markNeedsPaint)
      ..addStatusListener((s) {
        if (s == AnimationStatus.dismissed) dispose();
      });
    controller.addInkFeature(this);
  }

  /// About 1.2x the element's short side, so small buttons get a small glow.
  static double _defaultRadius(RenderBox box, RectCallback? rectCallback) {
    final size = rectCallback != null ? rectCallback().size : box.size;
    final short = size.shortestSide;
    final long = size.longestSide;
    return (short * 1.2).clamp(24.0, long * 0.9 < 24 ? 24.0 : long * 0.9);
  }

  @override
  void confirm() => _alpha.reverse();

  @override
  void cancel() => _alpha.reverse();

  @override
  void dispose() {
    _radius.dispose();
    _alpha.dispose();
    super.dispose();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final a = _alpha.value;
    if (a <= 0) return;
    final r = _targetRadius * Curves.easeOutCubic.transform(_radius.value.clamp(0.1, 1.0));
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: color.a * a),
          color.withValues(alpha: color.a * a * 0.45),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: _origin, radius: r));
    paintInkCircle(
      canvas: canvas,
      transform: transform,
      paint: paint,
      center: _origin,
      textDirection: _textDirection,
      radius: r,
      customBorder: _customBorder,
      borderRadius: _borderRadius,
      clipCallback: _rectCallback,
    );
  }
}

class _GlowSplashFactory extends InteractiveInkFeatureFactory {
  const _GlowSplashFactory();

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return GlowSplash(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      textDirection: textDirection,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
    );
  }
}
