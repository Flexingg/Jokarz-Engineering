import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/ui_prefs.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/providers/theme_provider.dart';
import 'package:jokarz_engineering/providers/ui_prefs_provider.dart';
import 'package:jokarz_engineering/theme/app_theme.dart';
import 'package:jokarz_engineering/theme/sections.dart';
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
  test('defaults: dark, blue accent, bouncy motion, transparency on', () {
    const p = UiPrefs();
    expect(p.themeName, 'dark');
    expect(p.reduceTransparency, isFalse);
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
      reduceTransparency: true,
      panelWidths: {'orders': 512},
    );
    final back = UiPrefs.fromJson(p.toJson());
    expect(back.reduceTransparency, isTrue);
    expect(back.panelWidths, {'orders': 512.0});
    expect(back.themeName, 'vibesDark');
    expect(back.accentValue, 0xFFFFB020);
    expect(back.motion, MotionLevel.subtle);
    expect(back.railCollapsed, isTrue);
    expect(back.dashboardOrder, ['orders', 'summary']);
    expect(back.dashboardHidden, ['today']);

    final junk = UiPrefs.fromJson({'motion': 'warp', 'themeName': null});
    expect(junk.motion, MotionLevel.bouncy);
    expect(junk.themeName, 'dark');
  });

  test('saved prefs are loaded, and changes are written back', () async {
    final storage = MemoryStorage(
      prefs: const UiPrefs(themeName: 'vibesLight', railCollapsed: true),
    );
    final c = _container(storage);
    c.read(uiPrefsProvider);
    await _settle();
    expect(c.read(uiPrefsProvider).railCollapsed, isTrue);
    // An old named theme maps onto light/dark.
    expect(c.read(themeProvider), AppThemeFamily.light);

    c.read(themeProvider.notifier).setTheme(AppThemeFamily.dark);
    expect(c.read(themeProvider), AppThemeFamily.dark);
    expect(storage.prefs.themeName, 'dark');
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

  test('copyWith keeps panel widths (they used to be dropped)', () {
    const p = UiPrefs(panelWidths: {'notes': 480});
    expect(p.copyWith(motion: MotionLevel.off).panelWidths, {'notes': 480});
  });

  test('old theme names map onto light and dark', () {
    for (final n in ['graphiteLight', 'vibesLight', 'bridgestoneLight', 'materialLight', 'brutalistLight', 'light']) {
      expect(AppThemeFamily.fromStored(n), AppThemeFamily.light, reason: n);
    }
    for (final n in ['graphiteDark', 'vibesDark', 'brutalistDark', 'dark', 'nonsense', null]) {
      expect(AppThemeFamily.fromStored(n), AppThemeFamily.dark, reason: '$n');
    }
  });

  group('Fluid theme legibility', () {
    double contrast(Color a, Color b) => AppTheme.contrast(a, b);

    void eachTheme(void Function(String id, ThemeData t, AppColors c) body) {
      for (final family in AppThemeFamily.values) {
        for (final reduce in [false, true]) {
          // Every pickable accent and every section's own colour.
          final hues = [
            for (final a in graphiteAccents) (a.label, a.color),
            for (final sec in AppSection.values)
              if (sec.fixedHue != null) ('section ${sec.name}', sec.fixedHue!),
          ];
          for (final h in hues) {
            final t = AppTheme.themeFor(family, accent: h.$2, reduceTransparency: reduce);
            body('${family.name}${reduce ? ' (opaque)' : ''} / ${h.$1}', t, t.extension<AppColors>()!);
          }
        }
      }
    }

    test('text reads on every backdrop: both gradient ends, the glow, and cards over them', () {
      eachTheme((id, t, c) {
        for (final bg in c.readableBackdrops) {
          expect(contrast(c.textPrimary, bg), greaterThanOrEqualTo(7), reason: '$id primary');
          expect(contrast(c.textSecondary, bg), greaterThanOrEqualTo(4.5), reason: '$id secondary');
          expect(contrast(c.primary, bg), greaterThanOrEqualTo(4.5), reason: '$id accent as text');
          expect(contrast(c.amber, bg), greaterThanOrEqualTo(4.5), reason: '$id amber');
          expect(contrast(c.emerald, bg), greaterThanOrEqualTo(4.5), reason: '$id emerald');
          expect(contrast(c.coral, bg), greaterThanOrEqualTo(4.5), reason: '$id alert');
        }
      });
    });

    test('status badges: each color reads on its own tinted bubble', () {
      eachTheme((id, t, c) {
        final panes = c.baseBackdrops;
        for (final s in [c.primary, c.amber, c.emerald, c.coral]) {
          for (final p in panes) {
            final bubble = Color.alphaBlend(s.withValues(alpha: 0.16), p);
            expect(contrast(s, bubble), greaterThanOrEqualTo(4.5), reason: '$id $s');
          }
        }
      });
    });

    test('the background gradient is gentle: its ends stay close in brightness', () {
      eachTheme((id, t, c) {
        expect(contrast(c.background, c.backgroundEnd), lessThan(1.15), reason: id);
      });
    });

    test('red is offered, twice (a nice red and Bridgestone red)', () {
      final labels = graphiteAccents.map((a) => a.label).toList();
      expect(labels, containsAll(['Red', 'Bridgestone red']));
      expect(graphiteAccents.firstWhere((a) => a.label == 'Bridgestone red').color,
          const Color(0xFFE4002B));
    });

    test('alert color is orange, never the accent', () {
      eachTheme((id, t, c) {
        expect(HSLColor.fromColor(c.coral).hue, inInclusiveRange(15, 40), reason: id);
        expect(c.coral, isNot(c.primary), reason: id);
      });
    });

    test('buttons have readable text on the accent fill', () {
      eachTheme((id, t, c) {
        expect(contrast(c.primaryFill, AppTheme.onColor(c.primaryFill)),
            greaterThanOrEqualTo(4.5), reason: '$id fill');
        expect(t.elevatedButtonTheme.style!.backgroundColor!.resolve({}), c.primaryFill);
        expect(contrast(t.colorScheme.primary, t.colorScheme.onPrimary),
            greaterThanOrEqualTo(4.5), reason: '$id scheme');
      });
    });

    test('section cards: text reads on a card washed with the section colour', () {
      eachTheme((id, t, c) {
        for (final bg in c.baseBackdrops.take(8)) {
          final card = Color.alphaBlend(c.surface, bg);
          final washed = Color.alphaBlend(c.primaryFill.withValues(alpha: 0.20), card);
          expect(contrast(c.textSecondary, washed), greaterThanOrEqualTo(4.5), reason: '$id secondary');
          expect(contrast(c.primary, washed), greaterThanOrEqualTo(4.5), reason: '$id number');
        }
      });
    });

    test('snackbar actions read on the dark snackbar', () {
      eachTheme((id, t, c) {
        expect(contrast(t.snackBarTheme.actionTextColor!, t.snackBarTheme.backgroundColor!),
            greaterThanOrEqualTo(4.5), reason: id);
      });
    });

    test('reduce transparency makes surfaces opaque and turns blur off', () {
      final c = AppTheme.themeFor(AppThemeFamily.light, reduceTransparency: true)
          .extension<AppColors>()!;
      expect(c.surface.a, 1.0);
      expect(c.glass.a, 1.0);
      expect(c.blurGlass, isFalse);
      final g = AppTheme.themeFor(AppThemeFamily.light).extension<AppColors>()!;
      expect(g.surface.a, lessThan(1.0));
      expect(g.blurGlass, isTrue);
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
      // One visible overshoot of a few percent (3-6%), not a wobble.
      expect(bouncy, inInclusiveRange(1.03, 1.06));
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
