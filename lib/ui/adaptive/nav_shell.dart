import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/ui_prefs_provider.dart';
import '../../theme/app_theme.dart';
import '../motion/motion.dart';
import '../shell/app_menu_bar.dart';
import '../widgets/voice_memo_modal.dart';
import 'breakpoints.dart';

/// One destination in the desktop rail. [branch] is the StatefulShellRoute
/// branch index; the list order is the visual order (BAMM sits after
/// Workbench in the rail but is branch 6).
class _RailDest {
  final int branch;
  final IconData icon;
  final String label;
  const _RailDest(this.branch, this.icon, this.label);
}

const _railDests = [
  _RailDest(0, Icons.dashboard_rounded, 'Dashboard'),
  _RailDest(1, Icons.assignment_outlined, 'Projects'),
  _RailDest(2, Icons.local_shipping_outlined, 'Open Orders'),
  _RailDest(3, Icons.handyman_rounded, 'Workbench Tools'),
  _RailDest(6, Icons.precision_manufacturing_rounded, 'BAMM Orders'),
  _RailDest(4, Icons.edit_note_rounded, 'Notes'),
  _RailDest(5, Icons.settings_suggest_rounded, 'Settings'),
];

const double _itemHeight = 44;
const double _itemGap = 4;
const double _railWide = 236;
const double _railNarrow = 76;

/// The app's single adaptive navigation shell: a collapsible navigation
/// rail (with a spring-animated selection highlight and a menu bar) on
/// [WindowSizeClass.expanded] windows, a bottom [NavigationBar] otherwise.
/// Every top-level branch route is wrapped in this one shell so the choice of
/// rail vs. bottom nav lives in exactly one place.
class AdaptiveNavShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AdaptiveNavShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AdaptiveNavShell> createState() => _AdaptiveNavShellState();
}

class _AdaptiveNavShellState extends ConsumerState<AdaptiveNavShell> {
  void _onTapNav(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final collapsed = ref.watch(uiPrefsProvider.select((p) => p.railCollapsed));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = Breakpoints.isExpanded(constraints.maxWidth);

        if (isDesktop) {
          final selectedVisual = _railDests
              .indexWhere((d) => d.branch == widget.navigationShell.currentIndex);
          return Scaffold(
            body: Column(
              children: [
                const AppMenuBar(),
                Expanded(
                  child: Row(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: collapsed ? _railNarrow : _railWide),
                        duration: motion.d(380),
                        curve: Curves.easeOutCubic,
                        builder: (context, width, _) => _Rail(
                          width: width,
                          showLabels: width > 170,
                          selectedVisual: selectedVisual,
                          motion: motion,
                          onSelect: _onTapNav,
                          onToggle: () => ref
                              .read(uiPrefsProvider.notifier)
                              .update((p) => p.copyWith(railCollapsed: !p.railCollapsed)),
                        ),
                      ),
                      Expanded(
                        child: _PageEnter(
                          index: widget.navigationShell.currentIndex,
                          motion: motion,
                          child: widget.navigationShell,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile Layout with Expressive NavigationBar (always present)
        return Scaffold(
          body: widget.navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: _onTapNav,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.of(context).primary),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment_rounded, color: AppTheme.of(context).primary),
                label: 'Projects',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping_rounded, color: AppTheme.of(context).primary),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.handyman_outlined),
                selectedIcon: Icon(Icons.handyman_rounded, color: AppTheme.of(context).primary),
                label: 'Tools',
              ),
              NavigationDestination(
                icon: Icon(Icons.note_alt_outlined),
                selectedIcon: Icon(Icons.edit_note_rounded, color: AppTheme.of(context).primary),
                label: 'Notes',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.of(context).primary),
                label: 'Settings',
              ),
              // Keep this list in branch order: selectedIndex IS the branch index.
              NavigationDestination(
                icon: Icon(Icons.precision_manufacturing_outlined),
                selectedIcon:
                    Icon(Icons.precision_manufacturing_rounded, color: AppTheme.of(context).primary),
                label: 'BAMM',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Re-plays a short rise-and-fade each time the selected branch changes. The
/// child is never rebuilt with a new key, so every branch keeps its state.
class _PageEnter extends StatefulWidget {
  final int index;
  final Motion motion;
  final Widget child;
  const _PageEnter({required this.index, required this.motion, required this.child});

  @override
  State<_PageEnter> createState() => _PageEnterState();
}

class _PageEnterState extends State<_PageEnter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, value: 1);

  @override
  void didUpdateWidget(_PageEnter old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && widget.motion.enabled) {
      _c.duration = widget.motion.page;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = widget.motion.spring;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = curve.transform(_c.value);
        return Opacity(
          opacity: Curves.easeOut.transform((_c.value * 1.6).clamp(0.0, 1.0)),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 18),
            child: Transform.scale(scale: 0.985 + 0.015 * t, child: child),
          ),
        );
      },
    );
  }
}

class _Rail extends StatelessWidget {
  final double width;
  final bool showLabels;
  final int selectedVisual;
  final Motion motion;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggle;

  const _Rail({
    required this.width,
    required this.showLabels,
    required this.selectedVisual,
    required this.motion,
    required this.onSelect,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height: _railDests.length * (_itemHeight + _itemGap),
                child: Stack(
                  children: [
                    // The selection highlight slides (and overshoots a little)
                    // between destinations.
                    if (selectedVisual >= 0)
                      AnimatedPositioned(
                        duration: motion.nav,
                        curve: motion.spring,
                        top: selectedVisual * (_itemHeight + _itemGap),
                        left: 0,
                        right: 0,
                        height: _itemHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: colors.primary.withValues(alpha: 0.14),
                            border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
                          ),
                        ),
                      ),
                    Column(
                      children: [
                        for (var i = 0; i < _railDests.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: _itemGap),
                            child: _RailItem(
                              dest: _railDests[i],
                              selected: i == selectedVisual,
                              showLabel: showLabels,
                              motion: motion,
                              onTap: () => onSelect(_railDests[i].branch),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _DictateButton(showLabel: showLabels),
          const SizedBox(height: 8),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 8),
          Tooltip(
            message: showLabels ? 'Collapse sidebar' : 'Expand sidebar',
            child: _Bounce(
              motion: motion,
              onTap: onToggle,
              child: SizedBox(
                height: _itemHeight,
                child: Row(
                  mainAxisAlignment:
                      showLabels ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    if (showLabels) const SizedBox(width: 14),
                    Icon(
                      showLabels ? Icons.menu_open_rounded : Icons.menu_rounded,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    if (showLabels) ...[
                      const SizedBox(width: 12),
                      Text('Collapse',
                          style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final _RailDest dest;
  final bool selected;
  final bool showLabel;
  final Motion motion;
  final VoidCallback onTap;

  const _RailItem({
    required this.dest,
    required this.selected,
    required this.showLabel,
    required this.motion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final color = selected ? colors.primary : colors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: dest.label,
      child: Tooltip(
        message: showLabel ? '' : dest.label,
        child: _Bounce(
          motion: motion,
          onTap: onTap,
          child: SizedBox(
            height: _itemHeight,
            child: Row(
              mainAxisAlignment:
                  showLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                if (showLabel) const SizedBox(width: 14),
                // The icon hops up slightly when its destination is selected.
                AnimatedSlide(
                  duration: motion.pop,
                  curve: motion.spring,
                  offset: selected ? const Offset(0, -0.06) : Offset.zero,
                  child: Icon(dest.icon, size: 20, color: color),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dest.label,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? colors.primary : colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DictateButton extends StatelessWidget {
  final bool showLabel;
  const _DictateButton({required this.showLabel});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    if (!showLabel) {
      return IconButton(
        tooltip: 'Dictate Note',
        onPressed: () => VoiceMemoModal.show(context),
        icon: Icon(Icons.mic, color: colors.amber),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => VoiceMemoModal.show(context),
      icon: Icon(Icons.mic, color: colors.amber, size: 18),
      label: const Text('Dictate Note'),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: colors.amber.withValues(alpha: 0.6)),
        minimumSize: const Size.fromHeight(40),
      ),
    );
  }
}

/// Press feedback: shrinks slightly while pressed and springs back on release.
class _Bounce extends StatefulWidget {
  final Motion motion;
  final VoidCallback onTap;
  final Widget child;
  const _Bounce({required this.motion, required this.onTap, required this.child});

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? 0.95 : 1,
            duration: _down ? widget.motion.quick : widget.motion.pop,
            curve: _down ? Curves.easeOut : widget.motion.spring,
            child: AnimatedContainer(
              duration: widget.motion.quick,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _hover ? colors.textPrimary.withValues(alpha: 0.05) : Colors.transparent,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
