import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';

/// The user-selected app-wide theme family (Bridgestone Dark/Light, Vibes Dark/White, Material
/// Light/Dark, Bridgestone Brutalist).
final themeProvider =
    NotifierProvider<ThemeNotifier, AppThemeFamily>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<AppThemeFamily> {
  @override
  AppThemeFamily build() => AppThemeFamily.bridgestoneDark;

  void setTheme(AppThemeFamily family) {
    state = family;
  }
}
