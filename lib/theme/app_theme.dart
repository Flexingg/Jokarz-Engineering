import 'package:flutter/material.dart';

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

/// A theme family the user can select. Drives the whole app's palette.
enum AppThemeFamily {
  vibesDark('Vibes Dark'),
  vibesLight('Vibes White'),
  materialLight('Material Light'),
  materialDark('Material Dark'),
  brutalistLight('Bridgestone Brutalist Light'),
  brutalistDark('Bridgestone Brutalist Dark');

  final String label;
  const AppThemeFamily(this.label);
}

/// Semantic color tokens read by the app's widgets. Each theme supplies its own
/// values, so switching theme re-colors the entire UI (not just the shell).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color primary; // main accent
  final Color primaryBlue; // secondary blue accent
  final Color amber;
  final Color emerald;
  final Color coral;
  final Color background;
  final Color surface;
  final Color surfaceCard;
  final Color surfaceHighlight;
  final Color surfaceVariant;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const AppColors({
    required this.primary,
    required this.primaryBlue,
    required this.amber,
    required this.emerald,
    required this.coral,
    required this.background,
    required this.surface,
    required this.surfaceCard,
    required this.surfaceHighlight,
    required this.surfaceVariant,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryBlue,
    Color? amber,
    Color? emerald,
    Color? coral,
    Color? background,
    Color? surface,
    Color? surfaceCard,
    Color? surfaceHighlight,
    Color? surfaceVariant,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryBlue: primaryBlue ?? this.primaryBlue,
      amber: amber ?? this.amber,
      emerald: emerald ?? this.emerald,
      coral: coral ?? this.coral,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryBlue: Color.lerp(primaryBlue, other.primaryBlue, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceHighlight: Color.lerp(surfaceHighlight, other.surfaceHighlight, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

/// Industrial / Material Expressive inspired design tokens.
class AppTheme {
  // --- Corner radii (kept constant; themes set their own shapes) ---
  static const double radiusXs = 8.0;
  static const double radiusSm = 12.0;
  static const double radiusMd = 18.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;

  // Legacy const accent colors — used only in const data tables/lists that
  // cannot be theme-reactive. Widgets should use `AppTheme.of(context)`.
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color primaryBlue = Color(0xFF0066FF);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color accentEmerald = Color(0xFF00E676);
  static const Color accentCoral = Color(0xFFFF3D71);

  /// The active palette. Kept in sync with the selected theme so widgets that
  /// read tokens without a [BuildContext] (helper/color methods) still resolve.
  static AppColors _active = _vibesDark;

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

  // ==== PALETTES ====
  static const AppColors _vibesDark = AppColors(
    primary: Color(0xFF00E5FF),
    primaryBlue: Color(0xFF0066FF),
    amber: Color(0xFFFFB300),
    emerald: Color(0xFF00E676),
    coral: Color(0xFFFF3D71),
    background: Color(0xFF0B0F17),
    surface: Color(0xFF131A26),
    surfaceCard: Color(0xFF1A2332),
    surfaceHighlight: Color(0xFF233045),
    surfaceVariant: Color(0xFF233045),
    border: Color(0xFF2B3A52),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
  );

  static const AppColors _vibesLight = AppColors(
    primary: Color(0xFF0066FF),
    primaryBlue: Color(0xFF0066FF),
    amber: Color(0xFFFFB300),
    emerald: Color(0xFF008947),
    coral: Color(0xFFFF3D71),
    background: Color(0xFFF4F6FB),
    surface: Color(0xFFFFFFFF),
    surfaceCard: Color(0xFFF8FAFC),
    surfaceHighlight: Color(0xFFE2E8F0),
    surfaceVariant: Color(0xFFE2E8F0),
    border: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
  );

  // Bridgestone red — the pop accent of the Brutalist themes.
  static const Color bridgestoneRed = Color(0xFFE4002B);

  // Brutalist uses red for EVERY accent token: the app renders its accent
  // buttons with mixed hardcoded foregrounds (black AND white), and Bridgestone
  // red is the single color with enough contrast for both (~5:1 / ~4.2:1),
  // keeping surfaces monochrome with red as the unified action/pop color.
  static const AppColors _brutalistLight = AppColors(
    primary: bridgestoneRed,
    primaryBlue: bridgestoneRed,
    amber: bridgestoneRed,
    emerald: bridgestoneRed,
    coral: bridgestoneRed,
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceHighlight: Color(0xFFEDEDED),
    surfaceVariant: Color(0xFFEDEDED),
    border: Color(0xFF000000),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF444444),
  );

  static const AppColors _brutalistDark = AppColors(
    primary: bridgestoneRed,
    primaryBlue: bridgestoneRed,
    amber: bridgestoneRed,
    emerald: bridgestoneRed,
    coral: bridgestoneRed,
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF141414),
    surfaceCard: Color(0xFF1A1A1A),
    surfaceHighlight: Color(0xFF242424),
    surfaceVariant: Color(0xFF242424),
    border: Color(0xFF3A3A3A),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFA0A0A0),
  );

  static ThemeData themeFor(AppThemeFamily family) {
    switch (family) {
      case AppThemeFamily.vibesDark:
        return vibesDarkTheme;
      case AppThemeFamily.vibesLight:
        return vibesLightTheme;
      case AppThemeFamily.materialLight:
        return materialLightTheme;
      case AppThemeFamily.materialDark:
        return materialDarkTheme;
      case AppThemeFamily.brutalistLight:
        return brutalistLightTheme;
      case AppThemeFamily.brutalistDark:
        return brutalistDarkTheme;
    }
  }

  // ==== THEMES ====
  static ThemeData get vibesDarkTheme => darkTheme;
  static ThemeData get vibesLightTheme => lightTheme;

  static ThemeData get darkTheme {
    _active = _vibesDark;
    return _buildTheme(
        brightness: Brightness.dark,
        colors: _vibesDark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          onPrimary: Color(0xFF00363F),
          primaryContainer: Color(0xFF004E5B),
          onPrimaryContainer: Color(0xFFBBE9FF),
          secondary: Color(0xFFFFB300),
          onSecondary: Color(0xFF432C00),
          tertiary: Color(0xFF00E676),
          onTertiary: Color(0xFF00391A),
          error: Color(0xFFFF3D71),
        ),
        radius: radiusMd,
      );
  }

  static ThemeData get lightTheme {
    _active = _vibesLight;
    return _buildTheme(
        brightness: Brightness.light,
        colors: _vibesLight,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0066FF),
          onPrimary: Colors.white,
          secondary: Color(0xFFFFB300),
          tertiary: Color(0xFF008947),
          error: Color(0xFFFF3D71),
        ),
        radius: radiusMd,
      );
  }

  static ThemeData get materialLightTheme {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3D5AFE));
    final colors = AppColors(
      primary: scheme.primary,
      primaryBlue: scheme.secondary,
      amber: scheme.tertiary,
      emerald: scheme.tertiary,
      coral: scheme.error,
      background: scheme.surface,
      surface: scheme.surface,
      surfaceCard: scheme.surfaceContainerLow,
      surfaceHighlight: scheme.surfaceContainerHigh,
      surfaceVariant: scheme.surfaceContainerHighest,
      border: scheme.outlineVariant,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
    );
    _active = colors;
    return _buildTheme(
      brightness: Brightness.light,
      colors: colors,
      colorScheme: scheme,
      radius: radiusSm,
    );
  }

  static ThemeData get materialDarkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3D5AFE),
      brightness: Brightness.dark,
    );
    final colors = AppColors(
      primary: scheme.primary,
      primaryBlue: scheme.secondary,
      amber: scheme.tertiary,
      emerald: scheme.tertiary,
      coral: scheme.error,
      background: scheme.surface,
      surface: scheme.surface,
      surfaceCard: scheme.surfaceContainerLow,
      surfaceHighlight: scheme.surfaceContainerHigh,
      surfaceVariant: scheme.surfaceContainerHighest,
      border: scheme.outlineVariant,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
    );
    _active = colors;
    return _buildTheme(
      brightness: Brightness.dark,
      colors: colors,
      colorScheme: scheme,
      radius: radiusSm,
    );
  }

  /// Bridgestone Brutalist — Light variant: monochrome white/grey surfaces with
  /// Bridgestone red as the pop, sharp corners, thick borders, no elevation.
  static ThemeData get brutalistLightTheme =>
      _buildBrutalist(_brutalistLight, Brightness.light);

  /// Bridgestone Brutalist — Dark variant: near-black surfaces, light text,
  /// Bridgestone red pop.
  static ThemeData get brutalistDarkTheme =>
      _buildBrutalist(_brutalistDark, Brightness.dark);

  /// Builds a Bridgestone Brutalist theme. [c] selects the light/dark palette;
  /// [brightness] drives inverted button fills and text so contrast holds in
  /// both modes.
  static ThemeData _buildBrutalist(AppColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    _active = c;
    final scheme = ColorScheme.fromSeed(
      seedColor: bridgestoneRed,
      brightness: brightness,
      surface: c.background,
    ).copyWith(
      primary: bridgestoneRed,
      onPrimary: Colors.white,
      surface: c.background,
      onSurface: c.textPrimary,
      outline: c.border,
      error: bridgestoneRed,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      colorScheme: scheme,
      extensions: [c],
      // Sharp corners, thick borders, no elevation.
      cardTheme: CardThemeData(
        color: c.surfaceCard,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: c.border, width: 2),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          fontSize: 20,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 2,
        space: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: bridgestoneRed.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
                color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 12);
          }
          return TextStyle(color: c.textSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: bridgestoneRed);
          }
          return IconThemeData(color: c.textSecondary);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: bridgestoneRed.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: bridgestoneRed),
        unselectedIconTheme: IconThemeData(color: c.textSecondary),
        selectedLabelTextStyle: TextStyle(
            color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 12),
        unselectedLabelTextStyle:
            TextStyle(color: c.textSecondary, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: bridgestoneRed, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: c.border, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border, width: 2),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceCard,
        selectedColor: bridgestoneRed.withValues(alpha: 0.2),
        side: BorderSide(color: c.border, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        labelStyle: TextStyle(
            fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w600),
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary),
        titleLarge: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary),
        titleMedium: TextStyle(fontWeight: FontWeight.w800, color: c.textPrimary),
        bodyMedium: TextStyle(color: c.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.black,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppColors colors,
    required ColorScheme colorScheme,
    required double radius,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: colorScheme,
      extensions: [colors],
      cardTheme: CardThemeData(
        color: colors.surfaceCard,
        elevation: isDark ? 0 : 1,
        shadowColor: isDark ? null : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: colors.border, width: 1.0),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: isDark ? 2 : 1,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: isDark ? 0.2 : 0.15),
        selectedIconTheme: IconThemeData(color: colors.primary),
        unselectedIconTheme: IconThemeData(color: colors.textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: isDark ? 0.2 : 0.15),
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return TextStyle(color: colors.textSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.primary);
          }
          return IconThemeData(color: colors.textSecondary);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: isDark ? const Color(0xFF002B33) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceHighlight,
        selectedColor: colors.primary.withValues(alpha: 0.2),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        labelStyle: TextStyle(fontSize: 12, color: colors.textPrimary),
      ),
    );
  }
}
