import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'ui_prefs_provider.dart';

/// The user-selected app-wide theme family. Persisted via [uiPrefsProvider].
final themeProvider =
    NotifierProvider<ThemeNotifier, AppThemeFamily>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<AppThemeFamily> {
  @override
  AppThemeFamily build() {
    final name = ref.watch(uiPrefsProvider.select((p) => p.themeName));
    return AppThemeFamily.values.firstWhere(
      (f) => f.name == name,
      orElse: () => AppThemeFamily.graphiteDark,
    );
  }

  void setTheme(AppThemeFamily family) {
    ref.read(uiPrefsProvider.notifier).update((p) => p.copyWith(themeName: family.name));
  }
}
