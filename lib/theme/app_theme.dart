import 'package:flutter/material.dart';

/// Jetpack Compose / Material Expressive Inspired Design Tokens & Palette
class AppTheme {
  // Industrial & Cyber Palette
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color primaryBlue = Color(0xFF0066FF);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color accentEmerald = Color(0xFF00E676);
  static const Color accentCoral = Color(0xFFFF3D71);
  static const Color accentPurple = Color(0xFF9D4EDD);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0B0F17);
  static const Color darkSurface = Color(0xFF131A26);
  static const Color darkSurfaceCard = Color(0xFF1A2332);
  static const Color darkSurfaceHighlight = Color(0xFF233045);
  static const Color darkSurfaceVariant = Color(0xFF233045);
  static const Color darkBorder = Color(0xFF2B3A52);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF4F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceCard = Color(0xFFF8FAFC);
  static const Color lightSurfaceHighlight = Color(0xFFE2E8F0);
  static const Color lightSurfaceVariant = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFCBD5E1);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Material Expressive Corner Radii
  static const double radiusXs = 8.0;
  static const double radiusSm = 12.0;
  static const double radiusMd = 18.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        onPrimary: Color(0xFF00363F),
        primaryContainer: Color(0xFF004E5B),
        onPrimaryContainer: Color(0xFFBBE9FF),
        secondary: accentAmber,
        onSecondary: Color(0xFF432C00),
        secondaryContainer: Color(0xFF5F4100),
        onSecondaryContainer: Color(0xFFFFDEA3),
        tertiary: accentEmerald,
        onTertiary: Color(0xFF00391A),
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceContainer: darkSurfaceCard,
        surfaceContainerHigh: darkSurfaceHighlight,
        outline: darkBorder,
        error: accentCoral,
      ),
      cardTheme: CardThemeData(
        color: darkSurfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: darkBorder, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: darkSurface,
        indicatorColor: primaryCyan.withValues(alpha: 0.2),
        selectedIconTheme: const IconThemeData(color: primaryCyan),
        unselectedIconTheme: const IconThemeData(color: darkTextSecondary),
        selectedLabelTextStyle: const TextStyle(
          color: primaryCyan,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: darkTextSecondary,
          fontSize: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: primaryCyan.withValues(alpha: 0.2),
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryCyan, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return const TextStyle(color: darkTextSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryCyan);
          }
          return const IconThemeData(color: darkTextSecondary);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primaryCyan, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: const Color(0xFF002B33),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryCyan,
          side: const BorderSide(color: primaryCyan),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceHighlight,
        selectedColor: primaryCyan.withValues(alpha: 0.2),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        labelStyle: const TextStyle(fontSize: 12, color: darkTextPrimary),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFD6E4FF),
        onPrimaryContainer: Color(0xFF001B3E),
        secondary: accentAmber,
        onSecondary: Colors.black,
        secondaryContainer: Color(0xFFFFDEA3),
        onSecondaryContainer: Color(0xFF261900),
        tertiary: Color(0xFF008947),
        surface: lightSurface,
        onSurface: lightTextPrimary,
        surfaceContainer: lightSurfaceCard,
        surfaceContainerHigh: lightSurfaceHighlight,
        outline: lightBorder,
        error: accentCoral,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: lightBorder, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: lightSurface,
        indicatorColor: primaryBlue.withValues(alpha: 0.15),
        selectedIconTheme: const IconThemeData(color: primaryBlue),
        unselectedIconTheme: const IconThemeData(color: lightTextSecondary),
        selectedLabelTextStyle: const TextStyle(
          color: primaryBlue,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: lightTextSecondary,
          fontSize: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: primaryBlue.withValues(alpha: 0.15),
        elevation: 3,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceHighlight,
        side: const BorderSide(color: lightBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }
}
