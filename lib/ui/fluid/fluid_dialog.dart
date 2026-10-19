import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../motion/motion.dart';

/// Where the user last pressed, so a dialog can grow out of the button that
/// opened it. Fed by [TapOriginRecorder] at the top of the app.
class TapOrigin {
  TapOrigin._();
  static Offset? _position;
  static DateTime _at = DateTime.fromMillisecondsSinceEpoch(0);

  static void record(Offset globalPosition) {
    _position = globalPosition;
    _at = DateTime.now();
  }

  /// The last press, if it was recent enough to have opened what is opening
  /// now. Null (grow from the centre) for keyboard shortcuts and the like.
  static Offset? recent({Duration within = const Duration(milliseconds: 1500)}) {
    if (_position == null || DateTime.now().difference(_at) > within) return null;
    return _position;
  }
}

/// Records every pointer press anywhere in the app (without consuming it).
class TapOriginRecorder extends StatelessWidget {
  final Widget child;
  const TapOriginRecorder({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => TapOrigin.record(e.position),
        child: child,
      );
}

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
/// the dialog grows out of the button that was just tapped (its centre moves
/// from the tap point to the middle of the screen while it scales up on the
/// app's spring), and shrinks back into it on the way out. Opened from the
/// keyboard, it grows from the centre. Same arguments as [showDialog] for
/// everything the app uses.
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
  final origin = TapOrigin.recent();
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
          final size = MediaQuery.sizeOf(ctx);
          // From the tap point to the centre of the screen.
          final start = origin == null
              ? Offset.zero
              : origin - Offset(size.width / 2, size.height / 2);
          final fromScale = origin == null ? 0.92 : 0.5;
          body = AnimatedBuilder(
            animation: grow,
            child: body,
            builder: (context, child) {
              final t = grow.value;
              return Transform.translate(
                offset: start * (1 - t).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: fromScale + (1 - fromScale) * t,
                  child: child,
                ),
              );
            },
          );
        }
        return ModalBackdropBlur(animation: fade, child: body);
      },
    ),
  );
}
