import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';

/// The user-selected app-wide theme family (Vibes Dark/White, Material
/// Light/Dark, Bridgestone Brutalist).
final themeProvider =
    StateNotifierProvider<ThemeNotifier, AppThemeFamily>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeFamily> {
  ThemeNotifier() : super(AppThemeFamily.vibesDark);

  void setTheme(AppThemeFamily family) {
    state = family;
  }
}
