import 'package:flutter/material.dart';
import '../../models/ui_prefs.dart';

/// The one spring-like curve family the whole app animates on. A cubic with
/// its second control point above 1 overshoots the target a little and settles,
/// which reads as "bouncy" without a physics simulation.
///
/// Read it with [Motion.of]; widgets never hard-code a curve or duration.
@immutable
class Motion {
  final MotionLevel level;
  const Motion(this.level);

  static const Motion standard = Motion(MotionLevel.bouncy);

  /// Resolves the effective motion for a build context: [prefs] (what the user
  /// chose) unless the OS asks for reduced motion.
  static Motion resolve(MotionLevel prefs, {required bool disableAnimations}) =>
      Motion(disableAnimations ? MotionLevel.off : prefs);

  static Motion of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionScope>()?.motion ?? standard;

  bool get enabled => level != MotionLevel.off;

  /// The overshooting curve for movement the user just triggered.
  Curve get spring => switch (level) {
        MotionLevel.off => Curves.linear,
        MotionLevel.subtle => const Cubic(0.3, 1.25, 0.6, 1),
        MotionLevel.bouncy => const Cubic(0.34, 1.62, 0.5, 1),
      };

  /// A non-overshooting curve for things leaving the screen.
  Curve get exit => Curves.easeOutCubic;

  /// Scales a design duration: zero when motion is off.
  Duration d(int milliseconds) =>
      enabled ? Duration(milliseconds: milliseconds) : Duration.zero;

  Duration get nav => d(550);
  Duration get page => d(600);
  Duration get pop => d(320);
  Duration get sheet => d(480);
  Duration get quick => d(150);
}

/// Provides the resolved [Motion] to the widget tree (installed in the app's
/// `MaterialApp.builder`).
class MotionScope extends InheritedWidget {
  final Motion motion;
  const MotionScope({super.key, required this.motion, required super.child});

  @override
  bool updateShouldNotify(MotionScope old) => old.motion.level != motion.level;
}

/// Pushed routes (project detail, edit screens, ...) rise and fade in on the
/// shared spring instead of the platform default. Honors [Motion] (so it is a
/// plain fade when motion is off).
class SpringPageTransitionsBuilder extends PageTransitionsBuilder {
  const SpringPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final motion = Motion.of(context);
    final curved = CurvedAnimation(
      parent: animation,
      curve: motion.spring,
      reverseCurve: motion.exit,
    );
    if (!motion.enabled) {
      return FadeTransition(opacity: animation, child: child);
    }
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - curved.value) * 24),
          child: Transform.scale(scale: 0.985 + 0.015 * curved.value, child: child),
        ),
        child: child,
      ),
    );
  }
}
