import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../motion/motion.dart';

/// Blurs (and lets the barrier tint) everything behind a modal while it is
/// up, so a translucent glass dialog reads as frosted glass. Fades with
/// [animation]; does nothing when reduce transparency is on.
class ModalBackdropBlur extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const ModalBackdropBlur({super.key, required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!AppTheme.of(context).blurGlass) return child;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final sigma = 10 * animation.value.clamp(0.0, 1.0);
                if (sigma < 0.1) return const SizedBox.expand();
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// [showDialog] with the fluid look and motion: the content behind blurs, and
/// the dialog grows out of a slightly smaller, faded state with the app's
/// spring (0.92 -> 1), shrinking back on the way out. Same arguments as
/// [showDialog] for everything the app uses.
Future<T?> showFluidDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final motion = Motion.of(context);
  final theme = Theme.of(context);
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  // Like showDialog: the dialog keeps the themes of where it was opened.
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return navigator.push<T>(
    RawDialogRoute<T>(
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? theme.dialogTheme.barrierColor ?? Colors.black54,
      barrierLabel: barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      settings: routeSettings,
      transitionDuration: motion.enabled ? motion.d(420) : const Duration(milliseconds: 150),
      pageBuilder: (ctx, _, _) {
        Widget dialog = Builder(builder: builder);
        if (useSafeArea) dialog = SafeArea(child: dialog);
        return themes.wrap(MotionScope(motion: motion, child: dialog));
      },
      transitionBuilder: (ctx, animation, _, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.5, curve: Curves.easeOut),
          reverseCurve: Curves.easeIn,
        );
        Widget body = FadeTransition(opacity: fade, child: child);
        if (motion.enabled) {
          final grow = CurvedAnimation(
            parent: animation,
            curve: motion.spring,
            reverseCurve: motion.exit,
          );
          body = ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(grow),
            child: body,
          );
        }
        return ModalBackdropBlur(animation: fade, child: body);
      },
    ),
  );
}
