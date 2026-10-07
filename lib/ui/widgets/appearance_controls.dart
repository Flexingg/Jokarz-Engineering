import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ui_prefs.dart';
import '../../providers/theme_provider.dart';
import '../../providers/ui_prefs_provider.dart';
import '../../theme/app_theme.dart';

/// Accent picker (Graphite themes) and animation level, shown in Settings >
/// Appearance under the theme dropdown.
class AppearanceControls extends ConsumerWidget {
  const AppearanceControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppTheme.of(context);
    final prefs = ref.watch(uiPrefsProvider);
    final family = ref.watch(themeProvider);
    final isGraphite = family == AppThemeFamily.graphiteDark ||
        family == AppThemeFamily.graphiteLight;
    final notifier = ref.read(uiPrefsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text('Accent color', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(
          isGraphite ? 'Used for selection and primary buttons.' : 'Available on the Graphite themes.',
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in graphiteAccents)
              Tooltip(
                message: a.label,
                child: Semantics(
                  button: true,
                  selected: prefs.accentValue == a.color.toARGB32(),
                  label: '${a.label} accent',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: isGraphite
                        ? () => notifier.update((p) => p.copyWith(accentValue: a.color.toARGB32()))
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: a.color.withValues(alpha: isGraphite ? 1 : 0.35),
                        border: Border.all(
                          color: prefs.accentValue == a.color.toARGB32()
                              ? colors.textPrimary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: prefs.accentValue == a.color.toARGB32()
                          ? const Icon(Icons.check_rounded, color: Color(0xFF081019), size: 20)
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Animations', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(
          'Bouncy overshoots slightly. Off follows the system "reduce motion" setting too.',
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
        const SizedBox(height: 10),
        SegmentedButton<MotionLevel>(
          showSelectedIcon: false,
          segments: [
            for (final m in MotionLevel.values)
              ButtonSegment(value: m, label: Text(m.label)),
          ],
          selected: {prefs.motion},
          onSelectionChanged: (s) =>
              notifier.update((p) => p.copyWith(motion: s.first)),
        ),
      ],
    );
  }
}
