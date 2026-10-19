import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Each part of the app owns a hue: its icon tile, its selection pill, its
/// main buttons and its highlighted numbers use it. Dashboard follows the
/// accent picked in Settings.
enum AppSection {
  dashboard(null),
  projects(Color(0xFF6E4DF2)), // violet
  orders(Color(0xFFFF8A1F)), // orange
  tools(Color(0xFF12B5A6)), // teal
  bamm(Color(0xFF1AA7EC)), // sky
  fab(Color(0xFFFF4D8D)), // pink
  notes(Color(0xFFF5A623)), // amber
  calendar(Color(0xFF22B35E)), // green
  settings(Color(0xFF64748B)); // slate

  /// Null = the user's accent.
  final Color? fixedHue;
  const AppSection(this.fixedHue);

  Color hue(Color accent) => fixedHue ?? accent;
}

/// Re-themes [child] in [section]'s colour: the same light/dark look and
/// transparency, with the section hue as the accent.
class SectionTheme extends StatelessWidget {
  final AppSection section;
  final Widget child;
  const SectionTheme({super.key, required this.section, required this.child});

  /// The accent the app was built with (the Dashboard hue).
  static Color baseAccent(BuildContext context) =>
      _BaseAccent.maybeOf(context) ?? AppTheme.of(context).primaryFill;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final colors = AppTheme.of(context);
    final accent = baseAccent(context);
    final hue = section.hue(accent);
    if (hue == colors.primaryFill) return child;
    final family = base.brightness == Brightness.dark
        ? AppThemeFamily.dark
        : AppThemeFamily.light;
    final themed = AppTheme.themeFor(
      family,
      accent: hue,
      reduceTransparency: !colors.blurGlass,
      setActive: false,
    );
    // Keep the app's text styling (fonts) from the base theme.
    return _BaseAccent(
      accent: accent,
      child: Theme(data: themed.copyWith(textTheme: base.textTheme), child: child),
    );
  }
}

/// Remembers the user's accent below a section re-theme, so nested
/// sections and the navigation still know the Dashboard hue.
class _BaseAccent extends InheritedWidget {
  final Color accent;
  const _BaseAccent({required this.accent, required super.child});

  static Color? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BaseAccent>()?.accent;

  @override
  bool updateShouldNotify(_BaseAccent old) => old.accent != accent;
}

/// A colourful squircle app tile: the section hue, lighter at the top, with
/// a glyph in whichever of near-black or white reads on it.
class SectionTile extends StatelessWidget {
  final Color hue;
  final IconData icon;
  final double size;
  const SectionTile({super.key, required this.hue, required this.icon, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final top = Color.lerp(hue, Colors.white, 0.22)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.33),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, hue],
        ),
        boxShadow: [
          BoxShadow(color: hue.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Icon(icon, size: size * 0.58, color: AppTheme.onColor(hue)),
    );
  }
}

/// The full palette for [section] in the current mode: `primaryFill` is its
/// vivid hue, `primary` its readable text shade.
AppColors sectionColors(BuildContext context, AppSection section) {
  final colors = AppTheme.of(context);
  final hue = section.hue(SectionTheme.baseAccent(context));
  if (hue == colors.primaryFill) return colors;
  final family = Theme.of(context).brightness == Brightness.dark
      ? AppThemeFamily.dark
      : AppThemeFamily.light;
  return AppTheme.themeFor(
    family,
    accent: hue,
    reduceTransparency: !colors.blurGlass,
    setActive: false,
  ).extension<AppColors>()!;
}
