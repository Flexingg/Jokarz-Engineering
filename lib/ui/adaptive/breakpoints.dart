import 'package:flutter/widgets.dart';

/// The three named window-size classes the app lays out for, following the
/// Material 3 window size class scale. Every screen that branches on width
/// should read from here rather than hard-coding a pixel threshold.
enum WindowSizeClass {
  /// Phones in portrait. Single-column, drill-down navigation, bottom nav.
  compact,

  /// Phones in landscape, small tablets. Still single-pane but roomier.
  medium,

  /// Tablets in landscape, desktop windows. Two-pane layouts, nav rail.
  expanded,
}

/// Named width thresholds, in logical pixels, for [WindowSizeClass].
///
/// These are the only magic numbers for layout breakpoints in the app;
/// every screen and shell widget should go through [Breakpoints.of] (or the
/// static classifiers below) instead of comparing `constraints.maxWidth`
/// against a literal.
class Breakpoints {
  const Breakpoints._();

  static const double compactMax = 600;
  static const double mediumMax = 840;

  static WindowSizeClass classify(double width) {
    if (width < compactMax) return WindowSizeClass.compact;
    if (width < mediumMax) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  /// The window size class for the current [BuildContext], based on the
  /// nearest [MediaQuery].
  static WindowSizeClass of(BuildContext context) =>
      classify(MediaQuery.sizeOf(context).width);

  static bool isCompact(double width) => classify(width) == WindowSizeClass.compact;
  static bool isMedium(double width) => classify(width) == WindowSizeClass.medium;
  static bool isExpanded(double width) => classify(width) == WindowSizeClass.expanded;

  /// True for [WindowSizeClass.medium] or [WindowSizeClass.expanded] - the
  /// "wide enough for a two-column layout" check screens reach for most.
  static bool isAtLeastMedium(double width) => width >= compactMax;
}
