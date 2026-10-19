import 'package:flutter/material.dart';
import '../ui/motion/motion.dart';
import 'glow_splash.dart';

/// A semantic accent used by const data tables/dictionaries so they stay
/// theme-dynamic: store the [AccentKey] in const data, then resolve it to the
/// active theme's color with [AccentKeyX.resolve] in the build method.
enum AccentKey { primary, blue, amber, emerald, coral }

extension AccentKeyX on AccentKey {
  Color resolve(AppColors colors) => switch (this) {
        AccentKey.primary => colors.primary,
        AccentKey.blue => colors.primaryBlue,
        AccentKey.amber => colors.amber,
        AccentKey.emerald => colors.emerald,
        AccentKey.coral => colors.coral,
      };
}

/// Light or dark. The look itself is one design (soft gradient backgrounds,
/// frosted glass chrome, pill controls); the accent color is picked
/// separately.
enum AppThemeFamily {
  light('Light'),
  dark('Dark');

  final String label;
  const AppThemeFamily(this.label);

  Brightness get brightness =>
      this == AppThemeFamily.dark ? Brightness.dark : Brightness.light;

  /// Older builds stored one of ten named themes. Anything that was a light
  /// theme becomes [light]; everything else (and anything unknown) is [dark].
  static AppThemeFamily fromStored(String? name) {
    if (name == null) return AppThemeFamily.dark;
    for (final f in AppThemeFamily.values) {
      if (f.name == name) return f;
    }
    final n = name.toLowerCase();
    return n.contains('light') || n.contains('white')
        ? AppThemeFamily.light
        : AppThemeFamily.dark;
  }
}

/// Semantic color tokens read by the app's widgets.
///
/// Surfaces are translucent on purpose: content cards sit on a gentle
/// gradient and let a little of it through ("glass"), while staying opaque
/// enough that text contrast is measured and guaranteed (see the theme tests).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color primary; // main accent
  final Color primaryBlue; // secondary accent (same as primary in this design)
  final Color amber;
  final Color emerald;
  final Color coral; // alerts: orange, so a red accent never reads as an error
  final Color background; // gradient start (top-left)
  final Color backgroundEnd; // gradient end (bottom-right)
  final Color backgroundGlow; // soft accent light in the top-left corner
  final Color surface; // content cards (calm, mostly opaque glass)
  final Color surfaceCard;
  final Color surfaceSolid; // dialogs, menus, sheets, anything over content
  final Color surfaceHighlight; // hover / selected wash, works on any surface
  final Color surfaceVariant;
  final Color glass; // floating chrome fill (rail, nav island, panels)
  final Color glassThick; // dialogs and the command palette (over a blur)
  final Color scrim; // tint behind modals
  final Color glassEdgeTop; // contour glow, top of the stroke
  final Color glassEdgeBottom; // contour glow, bottom of the stroke
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// Amber for filled buttons: [amber] is a text color (dark in light
  /// mode), which reads as brown when used as a fill.
  Color get amberFill => const Color(0xFFF5B841);

  /// Blur behind floating chrome. Off when the user asks for reduced
  /// transparency (then [glass] is opaque as well).
  final bool blurGlass;

  const AppColors({
    required this.primary,
    required this.primaryBlue,
    required this.amber,
    required this.emerald,
    required this.coral,
    required this.background,
    required this.backgroundEnd,
    required this.backgroundGlow,
    required this.surface,
    required this.surfaceCard,
    required this.surfaceSolid,
    required this.surfaceHighlight,
    required this.surfaceVariant,
    required this.glass,
    required this.glassThick,
    required this.scrim,
    required this.glassEdgeTop,
    required this.glassEdgeBottom,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    this.blurGlass = true,
  });

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryBlue,
    Color? amber,
    Color? emerald,
    Color? coral,
    Color? background,
    Color? backgroundEnd,
    Color? backgroundGlow,
    Color? surface,
    Color? surfaceCard,
    Color? surfaceSolid,
    Color? surfaceHighlight,
    Color? surfaceVariant,
    Color? glass,
    Color? glassThick,
    Color? scrim,
    Color? glassEdgeTop,
    Color? glassEdgeBottom,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    bool? blurGlass,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryBlue: primaryBlue ?? this.primaryBlue,
      amber: amber ?? this.amber,
      emerald: emerald ?? this.emerald,
      coral: coral ?? this.coral,
      background: background ?? this.background,
      backgroundEnd: backgroundEnd ?? this.backgroundEnd,
      backgroundGlow: backgroundGlow ?? this.backgroundGlow,
      surface: surface ?? this.surface,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceSolid: surfaceSolid ?? this.surfaceSolid,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      glass: glass ?? this.glass,
      glassThick: glassThick ?? this.glassThick,
      scrim: scrim ?? this.scrim,
      glassEdgeTop: glassEdgeTop ?? this.glassEdgeTop,
      glassEdgeBottom: glassEdgeBottom ?? this.glassEdgeBottom,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      blurGlass: blurGlass ?? this.blurGlass,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      primary: l(primary, other.primary),
      primaryBlue: l(primaryBlue, other.primaryBlue),
      amber: l(amber, other.amber),
      emerald: l(emerald, other.emerald),
      coral: l(coral, other.coral),
      background: l(background, other.background),
      backgroundEnd: l(backgroundEnd, other.backgroundEnd),
      backgroundGlow: l(backgroundGlow, other.backgroundGlow),
      surface: l(surface, other.surface),
      surfaceCard: l(surfaceCard, other.surfaceCard),
      surfaceSolid: l(surfaceSolid, other.surfaceSolid),
      surfaceHighlight: l(surfaceHighlight, other.surfaceHighlight),
      surfaceVariant: l(surfaceVariant, other.surfaceVariant),
      glass: l(glass, other.glass),
      glassThick: l(glassThick, other.glassThick),
      scrim: l(scrim, other.scrim),
      glassEdgeTop: l(glassEdgeTop, other.glassEdgeTop),
      glassEdgeBottom: l(glassEdgeBottom, other.glassEdgeBottom),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      blurGlass: t < 0.5 ? blurGlass : other.blurGlass,
    );
  }

  /// The worst-case colors text can end up on: each gradient end, the glow
  /// corner, and a content card over each of those. Used by the contrast
  /// tests and by [AppTheme] to tune the accent.
  List<Color> get readableBackdrops {
    // Selected items (rail, segments, nav) put accent text on an accent wash.
    final wash = primary.withValues(alpha: 0.16);
    final base = baseBackdrops;
    return [
      ...base,
      for (final p in base) Color.alphaBlend(wash, p),
    ];
  }

  /// Every surface text sits on, without selection washes: the gradient
  /// ends and glow corner, then cards, glass panes, solid surfaces and
  /// dialogs over them.
  List<Color> get baseBackdrops {
    final ends = [
      background,
      backgroundEnd,
      Color.alphaBlend(backgroundGlow, background),
    ];
    // Dialogs are translucent over a blurred, tinted copy of whatever is
    // behind them, which can be anything: test pure white and pure black.
    return [
      ...ends,
      for (final e in ends) Color.alphaBlend(surface, e),
      for (final e in ends) Color.alphaBlend(glass, e),
      surfaceSolid,
      for (final behind in const [Color(0xFFFFFFFF), Color(0xFF000000)])
        Color.alphaBlend(glassThick, Color.alphaBlend(scrim, behind)),
    ];
  }
}

/// Design tokens: one corner family, one material scale, light and dark.
class AppTheme {
  // --- Corner radii: one continuous family, nested = outer - padding ---
  static const double radiusXs = 8.0; // tags, small inputs
  static const double radiusSm = 12.0; // chips, thumbnails
  static const double radiusMd = 16.0; // list items, small cards, text fields
  static const double radiusLg = 24.0; // cards, grouped lists, panels
  static const double radiusXl = 32.0; // dialogs, sheets
  static const double radiusFull = 999.0; // pills: buttons, nav island, search

  // --- Glass blur (logical px) ---
  static const double blurThin = 24; // nav island, chips over content
  static const double blurRegular = 32; // menus, panels, top bars
  static const double blurThick = 44; // dialogs, sheets

  // Legacy const accent colors — used only in const data tables/lists that
  // cannot be theme-reactive. Widgets should use `AppTheme.of(context)`.
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color primaryBlue = Color(0xFF0066FF);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color accentEmerald = Color(0xFF00E676);
  static const Color accentCoral = Color(0xFFFF3D71);
  static const Color bridgestoneRed = Color(0xFFE4002B);

  /// Default accent when the user has not picked one.
  static const Color defaultAccent = Color(0xFF4DA3FF);

  /// The active palette. Kept in sync with the built theme so widgets that
  /// read tokens without a [BuildContext] (helper/color methods) still resolve.
  static AppColors _active = _colors(Brightness.dark, defaultAccent, false);

  /// The theme's semantic colors. Pass a [BuildContext] from a build method so
  /// the widget correctly rebuilds on theme change; helper methods may call it
  /// with no argument and get the active palette.
  static AppColors of([BuildContext? context]) {
    if (context != null) {
      final colors = Theme.of(context).extension<AppColors>();
      if (colors != null) return colors;
    }
    return _active;
  }

  /// Text/icon color for something filled with [bg]: near-black or white,
  /// whichever reads better (accents and status colors flip between modes).
  static Color onColor(Color bg) {
    const ink = Color(0xFF081019);
    return contrast(bg, ink) >= contrast(bg, Colors.white) ? ink : Colors.white;
  }

  static double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Nudges [accent] (only as far as needed) until it reads at 4.5:1 as text
  /// on every backdrop it can appear over.
  static Color _accentFor(Brightness b, Color accent, List<Color> backdrops) {
    var hsl = HSLColor.fromColor(accent);
    var c = accent;
    final step = b == Brightness.dark ? 0.02 : -0.02;
    double worst(Color x) =>
        backdrops.map((d) => contrast(x, d)).reduce((a, b) => a < b ? a : b);
    while (worst(c) < 4.6 && hsl.lightness > 0.05 && hsl.lightness < 0.95) {
      hsl = hsl.withLightness((hsl.lightness + step).clamp(0.0, 1.0));
      c = hsl.toColor();
    }
    return c;
  }

  static AppColors _colors(Brightness b, Color accent, bool reduceTransparency) {
    final dark = b == Brightness.dark;
    final opaque = reduceTransparency;
    // Gradient ends stay close in luminance so text reads the same everywhere.
    final base = dark ? const Color(0xFF07080B) : const Color(0xFFF2F3F5);
    final start = Color.alphaBlend(
        accent.withValues(alpha: dark ? 0.10 : 0.05), base);
    final end = dark ? const Color(0xFF0C0A12) : const Color(0xFFF4F1F5);
    final glow = accent.withValues(alpha: dark ? 0.12 : 0.06);

    final surface = dark
        ? Color.fromRGBO(30, 30, 33, opaque ? 1 : 0.80)
        : Color.fromRGBO(255, 255, 255, opaque ? 1 : 0.80);
    final solid = dark ? const Color(0xFF1C1C1F) : const Color(0xFFFBFBFD);
    final glass = opaque
        ? solid
        : dark
            ? const Color.fromRGBO(34, 34, 38, 0.66)
            : const Color.fromRGBO(255, 255, 255, 0.62);

    final glassThick = opaque
        ? solid
        : dark
            // As translucent as legibility allows over a black or white
            // screen behind the blur (checked in the theme tests).
            ? const Color.fromRGBO(30, 30, 33, 0.93)
            : const Color.fromRGBO(251, 251, 253, 0.95);
    final scrim = dark ? const Color(0x66000000) : const Color(0x2E000000);

    final draft = AppColors(
      primary: accent,
      primaryBlue: accent,
      amber: dark ? const Color(0xFFF5B841) : const Color(0xFF6E4500),
      emerald: dark ? const Color(0xFF3DD68C) : const Color(0xFF07552D),
      coral: dark ? const Color(0xFFFFA066) : const Color(0xFF822F08),
      background: start,
      backgroundEnd: end,
      backgroundGlow: glow,
      surface: surface,
      surfaceCard: surface,
      surfaceSolid: solid,
      surfaceHighlight: dark
          ? const Color.fromRGBO(255, 255, 255, 0.07)
          : const Color.fromRGBO(0, 0, 0, 0.045),
      surfaceVariant: dark
          ? const Color.fromRGBO(255, 255, 255, 0.07)
          : const Color.fromRGBO(0, 0, 0, 0.045),
      glass: glass,
      glassThick: glassThick,
      scrim: scrim,
      glassEdgeTop: opaque
          ? (dark ? const Color(0x1FFFFFFF) : const Color(0x14000000))
          : (dark ? const Color(0x38FFFFFF) : const Color(0xCCFFFFFF)),
      glassEdgeBottom: opaque
          ? (dark ? const Color(0x1FFFFFFF) : const Color(0x14000000))
          : (dark ? const Color(0x0DFFFFFF) : const Color(0x33FFFFFF)),
      border: dark ? const Color(0x1FFFFFFF) : const Color(0x1A000000),
      textPrimary: dark ? const Color(0xFFECECEE) : const Color(0xFF15171B),
      textSecondary: dark ? const Color(0xFFB5B8C0) : const Color(0xFF4A505C),
      blurGlass: !opaque,
    );
    // The selection wash is made from the accent itself, so tune twice.
    var tuned = draft;
    for (var i = 0; i < 3; i++) {
      final a = _accentFor(b, accent, tuned.readableBackdrops);
      tuned = draft.copyWith(primary: a, primaryBlue: a);
    }
    return tuned;
  }

  /// The one theme builder. [reduceTransparency] swaps every glass surface
  /// for an opaque one and turns blur off.
  static ThemeData themeFor(
    AppThemeFamily family, {
    Color? accent,
    bool reduceTransparency = false,
  }) {
    final brightness = family.brightness;
    final c = _colors(brightness, accent ?? defaultAccent, reduceTransparency);
    _active = c;
    return _build(brightness, c);
  }

  static ThemeData _build(Brightness brightness, AppColors c) {
    final isDark = brightness == Brightness.dark;
    // Text on accent-filled buttons: whichever of dark/white reads better.
    const darkInk = Color(0xFF081019);
    final ink = contrast(c.primary, darkInk) >= contrast(c.primary, Colors.white)
        ? darkInk
        : Colors.white;
    final scheme = ColorScheme.fromSeed(seedColor: c.primary, brightness: brightness)
        .copyWith(
      primary: c.primary,
      onPrimary: ink,
      surface: c.surfaceSolid,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surfaceSolid,
      surfaceContainerLow: c.surfaceSolid,
      surfaceContainer: c.surfaceSolid,
      surfaceContainerHigh: c.surfaceSolid,
      surfaceContainerHighest: c.surfaceSolid,
      outline: c.border,
      outlineVariant: c.border,
      error: c.coral,
      surfaceTint: Colors.transparent,
    );

    const pill = StadiumBorder();
    const btnText = TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5);
    final edge = BorderSide(color: c.border);
    final strongEdge = BorderSide(
        color: isDark ? const Color(0x33FFFFFF) : const Color(0x29000000));
    final selectedWash = c.primary.withValues(alpha: isDark ? 0.16 : 0.12);
    final snackBg = isDark ? const Color(0xFF2A2A2E) : const Color(0xFF1C1D21);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c],
      // Every page paints the shared gradient behind a transparent scaffold.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: c.surfaceSolid,
      splashFactory: GlowSplash.splashFactory,
      highlightColor: c.textPrimary.withValues(alpha: 0.04),
      hoverColor: c.textPrimary.withValues(alpha: 0.04),
      splashColor: (isDark ? Colors.white : c.primary)
          .withValues(alpha: isDark ? 0.10 : 0.14),
      dividerColor: c.border,
    );

    return base.copyWith(
      // Segoe UI Variable on current Windows, Roboto on Android.
      textTheme: base.textTheme.apply(
        fontFamilyFallback: const ['Segoe UI Variable Text', 'Segoe UI', 'Roboto'],
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: edge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: ink,
          elevation: 0,
          shape: pill,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: btnText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: ink,
          shape: pill,
          minimumSize: const Size(0, 40),
          textStyle: btnText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          backgroundColor: c.surfaceHighlight,
          side: strongEdge,
          shape: pill,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: btnText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          shape: pill,
          textStyle: btnText,
        ),
      ),
      // Icon buttons are small round glass bubbles.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: c.surfaceHighlight,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(pill),
          side: WidgetStatePropertyAll(strongEdge),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? selectedWash : c.surfaceHighlight),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? c.primary : c.textPrimary),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: ink,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 1,
        shape: pill,
      ),
      dialogTheme: DialogThemeData(
        // Thick glass: dialogs open over a blur of the screen behind them.
        backgroundColor: c.glassThick,
        surfaceTintColor: Colors.transparent,
        barrierColor: c.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: BorderSide(color: c.glassEdgeTop),
        ),
        titleTextStyle: TextStyle(
            color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceSolid,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.scrim,
        dragHandleColor: c.textSecondary.withValues(alpha: 0.5),
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceSolid,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd + 4),
          side: BorderSide(color: c.glassEdgeTop),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surfaceSolid),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd + 4),
            side: BorderSide(color: c.glassEdgeTop),
          )),
        ),
      ),
      menuBarTheme: MenuBarThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(c.textPrimary),
          overlayColor: WidgetStatePropertyAll(selectedWash),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm))),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surfaceSolid),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            side: BorderSide(color: c.glassEdgeTop),
          )),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: snackBg,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? const Color.fromRGBO(255, 255, 255, 0.06)
            : const Color.fromRGBO(255, 255, 255, 0.72),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: strongEdge,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: strongEdge,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceHighlight,
        selectedColor: selectedWash,
        side: strongEdge,
        shape: pill,
        labelStyle: TextStyle(fontSize: 12, color: c.textPrimary),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        iconColor: c.textSecondary,
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? ink : c.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.primary : c.surfaceHighlight),
        trackOutlineColor: WidgetStatePropertyAll(strongEdge.color),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : Colors.transparent),
        checkColor: WidgetStatePropertyAll(ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: c.textSecondary, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : c.textSecondary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceHighlight,
        circularTrackColor: c.surfaceHighlight,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surfaceHighlight,
        thumbColor: c.primary,
        trackHeight: 6,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.textPrimary,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: c.primary,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: c.primary, width: 3),
          borderRadius: BorderRadius.circular(3),
        ),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: selectedWash,
        selectedIconTheme: IconThemeData(color: c.primary),
        unselectedIconTheme: IconThemeData(color: c.textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: selectedWash,
        indicatorShape: pill,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 11,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? c.primary : c.textSecondary,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? c.primary : c.textSecondary,
            )),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBg,
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: _accentOnDark(c.primary, snackBg),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd + 4)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: SpringPageTransitionsBuilder(),
        TargetPlatform.windows: SpringPageTransitionsBuilder(),
        TargetPlatform.linux: SpringPageTransitionsBuilder(),
        TargetPlatform.macOS: SpringPageTransitionsBuilder(),
        TargetPlatform.iOS: SpringPageTransitionsBuilder(),
      }),
    );
  }

  /// Snackbars and tooltips are dark in both modes; lift the accent there.
  static Color _accentOnDark(Color accent, Color bg) {
    var hsl = HSLColor.fromColor(accent);
    var c = accent;
    while (contrast(c, bg) < 4.6 && hsl.lightness < 0.95) {
      hsl = hsl.withLightness((hsl.lightness + 0.03).clamp(0.0, 1.0));
      c = hsl.toColor();
    }
    return c;
  }
}
