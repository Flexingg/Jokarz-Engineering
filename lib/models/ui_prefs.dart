import 'package:flutter/painting.dart';

/// How springy animations are. [off] also applies automatically when the OS
/// "reduce motion" accessibility setting is on.
enum MotionLevel {
  off('Off'),
  subtle('Subtle'),
  bouncy('Bouncy');

  final String label;
  const MotionLevel(this.label);
}

/// Accent colors offered for the Graphite themes.
const List<({String label, Color color})> graphiteAccents = [
  (label: 'Blue', color: Color(0xFF4DA3FF)),
  (label: 'Amber', color: Color(0xFFFFB020)),
  (label: 'Green', color: Color(0xFF2FD39A)),
  (label: 'Violet', color: Color(0xFFB48CFF)),
  (label: 'Red', color: Color(0xFFF2545B)),
  (label: 'Bridgestone red', color: Color(0xFFE4002B)),
];

/// Everything about the app's look and layout that the user can change and
/// that should survive a restart. Stored in `jokarz_ui_prefs.json`.
class UiPrefs {
  /// [AppThemeFamily.name] of the selected theme. Kept as a string so this
  /// file does not depend on the theme code.
  final String themeName;
  final int accentValue;
  final MotionLevel motion;
  final bool railCollapsed;

  /// Dashboard section ids in display order, and the ones the user hid.
  final List<String> dashboardOrder;
  final List<String> dashboardHidden;

  /// Width the user dragged each side panel to, by screen id ('orders', ...).
  final Map<String, double> panelWidths;

  const UiPrefs({
    this.themeName = 'graphiteDark',
    this.accentValue = 0xFF4DA3FF,
    this.motion = MotionLevel.bouncy,
    this.railCollapsed = false,
    this.dashboardOrder = const [],
    this.dashboardHidden = const [],
    this.panelWidths = const {},
  });

  Color get accent => Color(accentValue);

  UiPrefs copyWith({
    String? themeName,
    int? accentValue,
    MotionLevel? motion,
    bool? railCollapsed,
    List<String>? dashboardOrder,
    List<String>? dashboardHidden,
    Map<String, double>? panelWidths,
  }) => UiPrefs(
    themeName: themeName ?? this.themeName,
    accentValue: accentValue ?? this.accentValue,
    motion: motion ?? this.motion,
    railCollapsed: railCollapsed ?? this.railCollapsed,
    dashboardOrder: dashboardOrder ?? this.dashboardOrder,
    dashboardHidden: dashboardHidden ?? this.dashboardHidden,
  );

  Map<String, dynamic> toJson() => {
    'themeName': themeName,
    'accent': accentValue,
    'motion': motion.name,
    'railCollapsed': railCollapsed,
    'dashboardOrder': dashboardOrder,
    'dashboardHidden': dashboardHidden,
  };

  factory UiPrefs.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) =>
        (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];
    return UiPrefs(
      themeName: json['themeName'] as String? ?? 'graphiteDark',
      accentValue: (json['accent'] as num?)?.toInt() ?? 0xFF4DA3FF,
      motion: MotionLevel.values.firstWhere(
        (m) => m.name == json['motion'],
        orElse: () => MotionLevel.bouncy,
      ),
      railCollapsed: json['railCollapsed'] as bool? ?? false,
      dashboardOrder: strings(json['dashboardOrder']),
      dashboardHidden: strings(json['dashboardHidden']),
      panelWidths: {
        for (final e in ((json['panelWidths'] as Map<String, dynamic>?) ?? const {}).entries)
          if (e.value is num) e.key: (e.value as num).toDouble(),
      },
    );
  }
}
