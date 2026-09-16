import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ExpressiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool isGlowing;
  final Color? glowColor;

  const ExpressiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = AppTheme.radiusMd,
    this.onTap,
    this.isGlowing = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final bg = backgroundColor ??
        (colors.surfaceCard);
    final border =
        borderColor ?? colors.border.withValues(alpha: 0.7);
    final glow = glowColor ?? colors.primary;

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isGlowing ? glow : border,
          width: isGlowing ? 1.5 : 1.0,
        ),
        boxShadow: isGlowing
            ? [
                BoxShadow(
                  color: glow.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        // Cards without their own onTap can still contain interactive
        // children (e.g. a ListTile with its own onTap) that need a Material
        // ancestor to paint background/ink correctly. That Material must sit
        // *inside* this decorated Container - Flutter asserts in debug mode
        // if an opaque DecoratedBox sits between a ListTile and the nearest
        // Material, since the box would then paint over the ink layer.
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          splashColor: glow.withValues(alpha: 0.1),
          highlightColor: glow.withValues(alpha: 0.05),
          child: content,
        ),
      );
    }

    return content;
  }
}
