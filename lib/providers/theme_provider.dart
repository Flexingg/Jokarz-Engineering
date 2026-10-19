import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'ui_prefs_provider.dart';

/// Light or dark, as the user picked it. Persisted via [uiPrefsProvider].
final themeProvider =
    NotifierProvider<ThemeNotifier, AppThemeFamily>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<AppThemeFamily> {
  @override
  AppThemeFamily build() {
    final name = ref.watch(uiPrefsProvider.select((p) => p.themeName));
    return AppThemeFamily.fromStored(name);
  }

  void setTheme(AppThemeFamily family) {
    ref.read(uiPrefsProvider.notifier).update((p) => p.copyWith(themeName: family.name));
  }
}
