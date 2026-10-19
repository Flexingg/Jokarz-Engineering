import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../motion/motion.dart';
import 'context_menu.dart';

class ExpressiveCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool isGlowing;
  final Color? glowColor;

  /// Right-click (desktop) menu. Cards with an [onTap] also lift on hover.
  final List<MenuAction>? contextActions;

  const ExpressiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = AppTheme.radiusLg,
    this.onTap,
    this.isGlowing = false,
    this.glowColor,
    this.contextActions,
  });

  @override
  State<ExpressiveCard> createState() => _ExpressiveCardState();
}

class _ExpressiveCardState extends State<ExpressiveCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final onTap = w.onTap;
    final isGlowing = w.isGlowing;
    final borderRadius = w.borderRadius;
    final child = w.child;
    final colors = AppTheme.of(context);
    final motion = Motion.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = w.backgroundColor ?? colors.surfaceCard;
    final hoverable = onTap != null;
    // Calm glass: a soft lift instead of a hard outline; hover and "glowing"
    // light the edge with the accent (light as a signal, not decoration).
    final border = w.borderColor ??
        (hoverable && _hover
            ? colors.primary.withValues(alpha: 0.55)
            : (dark ? colors.glassEdgeTop.withValues(alpha: 0.14) : colors.border));
    final glow = w.glowColor ?? colors.primary;

    Widget content = AnimatedContainer(
      duration: motion.quick,
      margin: w.margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isGlowing ? glow.withValues(alpha: 0.7) : border,
          width: isGlowing ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isGlowing)
            BoxShadow(color: glow.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: 1)
          else if (!dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.07 : 0.04),
              blurRadius: _hover ? 18 : 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: w.padding ?? const EdgeInsets.all(16.0),
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
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          onHover: (h) => setState(() => _hover = h),
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          splashColor: glow.withValues(alpha: 0.1),
          highlightColor: glow.withValues(alpha: 0.05),
          child: AnimatedScale(
            scale: _down ? 0.98 : 1,
            duration: _down ? motion.quick : motion.pop,
            curve: _down ? Curves.easeOut : motion.spring,
            child: content,
          ),
        ),
      );
    }

    final actions = w.contextActions;
    if (actions != null && actions.isNotEmpty) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (d) => showContextMenu(context, d.globalPosition, actions),
        child: content,
      );
    }
    return content;
  }
}
