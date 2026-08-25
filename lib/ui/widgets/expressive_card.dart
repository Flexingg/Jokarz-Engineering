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
  final Color glowColor;

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
    this.glowColor = AppTheme.primaryCyan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ??
        (isDark ? AppTheme.darkSurfaceCard : AppTheme.lightSurface);
    final border = borderColor ??
        (isDark ? AppTheme.darkBorder : AppTheme.lightBorder.withValues(alpha: 0.7));

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isGlowing ? glowColor : border,
          width: isGlowing ? 1.5 : 1.0,
        ),
        boxShadow: isGlowing
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          splashColor: glowColor.withValues(alpha: 0.1),
          highlightColor: glowColor.withValues(alpha: 0.05),
          child: content,
        ),
      );
    }

    return content;
  }
}
