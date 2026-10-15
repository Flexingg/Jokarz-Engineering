import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/ui_prefs.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/providers/theme_provider.dart';
import 'package:jokarz_engineering/providers/ui_prefs_provider.dart';
import 'package:jokarz_engineering/theme/app_theme.dart';
import 'package:jokarz_engineering/ui/motion/motion.dart';

import '../helpers/memory_storage.dart';

ProviderContainer _container(MemoryStorage storage) {
  final c = ProviderContainer(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('defaults: Graphite Dark, blue accent, bouncy motion', () {
    const p = UiPrefs();
    expect(p.themeName, 'graphiteDark');
    expect(p.accent, graphiteAccents.first.color);
    expect(p.motion, MotionLevel.bouncy);
  });

  test('JSON round trip; unknown values fall back to defaults', () {
    const p = UiPrefs(
      themeName: 'vibesDark',
      accentValue: 0xFFFFB020,
      motion: MotionLevel.subtle,
      railCollapsed: true,
      dashboardOrder: ['orders', 'summary'],
      dashboardHidden: ['today'],
    );
    final back = UiPrefs.fromJson(p.toJson());
    expect(back.themeName, 'vibesDark');
    expect(back.accentValue, 0xFFFFB020);
    expect(back.motion, MotionLevel.subtle);
    expect(back.railCollapsed, isTrue);
    expect(back.dashboardOrder, ['orders', 'summary']);
    expect(back.dashboardHidden, ['today']);

    final junk = UiPrefs.fromJson({'motion': 'warp', 'themeName': null});
    expect(junk.motion, MotionLevel.bouncy);
    expect(junk.themeName, 'graphiteDark');
  });

  test('saved prefs are loaded, and changes are written back', () async {
    final storage = MemoryStorage(
      prefs: const UiPrefs(themeName: 'vibesLight', railCollapsed: true),
    );
    final c = _container(storage);
    c.read(uiPrefsProvider);
    await _settle();
    expect(c.read(uiPrefsProvider).railCollapsed, isTrue);
    expect(c.read(themeProvider), AppThemeFamily.vibesLight);

    c.read(themeProvider.notifier).setTheme(AppThemeFamily.graphiteLight);
    expect(c.read(themeProvider), AppThemeFamily.graphiteLight);
    expect(storage.prefs.themeName, 'graphiteLight');
  });

  test(
    'a change made before the saved copy finishes loading is not overwritten',
    () async {
      final storage = MemoryStorage(prefs: const UiPrefs(railCollapsed: true));
      final c = _container(storage);
      c
          .read(uiPrefsProvider.notifier)
          .update((p) => p.copyWith(motion: MotionLevel.off));
      await _settle();
      expect(c.read(uiPrefsProvider).motion, MotionLevel.off);
    },
  );

  group('Graphite theme', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    test('every accent is readable as text on the surface in both modes', () {
      for (final family in [
        AppThemeFamily.graphiteDark,
        AppThemeFamily.graphiteLight,
      ]) {
        for (final a in graphiteAccents) {
          final theme = AppTheme.themeFor(family, accent: a.color);
          final colors = theme.extension<AppColors>()!;
          expect(
            contrast(colors.primary, colors.surface),
            greaterThanOrEqualTo(4.5),
            reason: '${family.name} / ${a.label}',
          );
          expect(
            contrast(colors.textPrimary, colors.surface),
            greaterThanOrEqualTo(7),
          );
          expect(
            contrast(colors.textSecondary, colors.surface),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    });

    test('red is offered, twice (a nice red and Bridgestone red)', () {
      final labels = graphiteAccents.map((a) => a.label).toList();
      expect(labels, containsAll(['Red', 'Bridgestone red']));
      expect(graphiteAccents.firstWhere((a) => a.label == 'Bridgestone red').color,
          const Color(0xFFE4002B));
    });

    test('alert color is never the accent, never red, and stays readable', () {
      for (final family in [AppThemeFamily.graphiteDark, AppThemeFamily.graphiteLight]) {
        for (final a in graphiteAccents) {
          final colors = AppTheme.themeFor(family, accent: a.color).extension<AppColors>()!;
          final hue = HSLColor.fromColor(colors.coral).hue;
          expect(hue, inInclusiveRange(15, 40), reason: 'orange family, ${family.name}');
          expect(contrast(colors.coral, colors.surface), greaterThanOrEqualTo(4.5),
              reason: 'alert text on surface, ${family.name}');
          expect(colors.coral, isNot(colors.primary), reason: '${family.name} / ${a.label}');
        }
      }
    });

    test('buttons have readable text on the accent fill', () {
      for (final family in [
        AppThemeFamily.graphiteDark,
        AppThemeFamily.graphiteLight,
      ]) {
        for (final a in graphiteAccents) {
          final theme = AppTheme.themeFor(family, accent: a.color);
          expect(
            contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
            greaterThanOrEqualTo(4.5),
            reason: '${family.name} / ${a.label}',
          );
        }
      }
    });
  });

  group('Motion', () {
    test('off disables durations and uses a plain curve', () {
      const m = Motion(MotionLevel.off);
      expect(m.enabled, isFalse);
      expect(m.page, Duration.zero);
      expect(m.spring, Curves.linear);
    });

    test('bouncy overshoots 1.0; subtle overshoots less', () {
      double peak(Curve c) {
        var best = 0.0;
        for (var t = 0.0; t <= 1.0; t += 0.01) {
          final v = c.transform(t);
          if (v > best) best = v;
        }
        return best;
      }

      final bouncy = peak(const Motion(MotionLevel.bouncy).spring);
      final subtle = peak(const Motion(MotionLevel.subtle).spring);
      expect(bouncy, greaterThan(1.05));
      expect(subtle, greaterThan(1.0));
      expect(subtle, lessThan(bouncy));
    });

    test('the OS reduce-motion setting wins over the user choice', () {
      expect(
        Motion.resolve(MotionLevel.bouncy, disableAnimations: true).level,
        MotionLevel.off,
      );
      expect(
        Motion.resolve(MotionLevel.bouncy, disableAnimations: false).level,
        MotionLevel.bouncy,
      );
    });
  });
}
