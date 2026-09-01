import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import 'voice_memo_modal.dart';

class ResponsiveScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ResponsiveScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends ConsumerState<ResponsiveScaffold> {
  bool _collapsed = false;

  void _onTapNav(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          final railWidth = _collapsed ? 68.0 : 230.0;
          // Desktop & Tablet Navigation Rail Layout
          return Scaffold(
            body: Row(
              children: [
                // Custom Expressive Navigation Rail
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: railWidth,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.of(context).surface : AppTheme.of(context).surface,
                    border: Border(
                      right: BorderSide(
                        color: isDark ? AppTheme.of(context).border : AppTheme.of(context).border,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Navigation Header
                      if (_collapsed)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.of(context).primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Icon(
                              Icons.precision_manufacturing_rounded,
                              color: AppTheme.of(context).primary,
                              size: 18,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppTheme.of(context).primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                ),
                                child: Icon(
                                  Icons.precision_manufacturing_rounded,
                                  color: AppTheme.of(context).primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'WORKSPACE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: AppTheme.of(context).primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Navigation Items
                      _buildDesktopNavItem(
                        context,
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        collapsed: _collapsed,
                        isSelected: widget.navigationShell.currentIndex == 0,
                        onTap: () => _onTapNav(0),
                      ),
                      _buildDesktopNavItem(
                        context,
                        icon: Icons.assignment_outlined,
                        label: 'Projects',
                        collapsed: _collapsed,
                        isSelected: widget.navigationShell.currentIndex == 1,
                        onTap: () => _onTapNav(1),
                      ),
                      _buildDesktopNavItem(
                        context,
                        icon: Icons.local_shipping_outlined,
                        label: 'Open Orders',
                        collapsed: _collapsed,
                        isSelected: widget.navigationShell.currentIndex == 2,
                        onTap: () => _onTapNav(2),
                      ),
                      _buildDesktopNavItem(
                        context,
                        icon: Icons.handyman_rounded,
                        label: 'Workbench Tools',
                        collapsed: _collapsed,
                        isSelected: widget.navigationShell.currentIndex == 3,
                        onTap: () => _onTapNav(3),
                      ),
                      _buildDesktopNavItem(
                        context,
                        icon: Icons.edit_note_rounded,
                        label: 'Notes',
                        collapsed: _collapsed,
                        isSelected: widget.navigationShell.currentIndex == 4,
                        onTap: () => _onTapNav(4),
                      ),
                      _buildDesktopNavItem(
                        context,
                        icon: Icons.settings_suggest_rounded,
                        label: 'Settings',
                        collapsed: _collapsed,
                        isSelected: widget.navigationShell.currentIndex == 5,
                        onTap: () => _onTapNav(5),
                      ),

                      const Spacer(),

                      // Quick Voice Record
                      if (_collapsed)
                        IconButton(
                          tooltip: 'Dictate Note',
                          onPressed: () => VoiceMemoModal.show(context),
                          icon: Icon(Icons.mic, color: AppTheme.of(context).amber),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: OutlinedButton.icon(
                            onPressed: () => VoiceMemoModal.show(context),
                            icon: Icon(Icons.mic, color: AppTheme.of(context).amber, size: 18),
                            label: const Text(
                              'Dictate Note',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.of(context).amber),
                              minimumSize: Size.fromHeight(40),
                            ),
                          ),
                        ),

                        // Theme — managed in Settings
                        _buildDesktopNavItem(
                          context,
                          icon: Icons.palette_outlined,
                          label: 'Theme',
                          collapsed: _collapsed,
                          isSelected: false,
                          onTap: () => context.push('/settings'),
                        ),

                      const Divider(height: 1),
                      // Collapse / Expand Toggle
                      Tooltip(
                        message: _collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                        child: IconButton(
                          onPressed: () => setState(() => _collapsed = !_collapsed),
                          icon: Icon(
                            _collapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
                            color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                ),

                // Main Content Area
                Expanded(child: widget.navigationShell),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool collapsed,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Material(
        color: isSelected
            ? AppTheme.of(context).primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: onTap,
          child: Tooltip(
            message: collapsed ? label : '',
            child: Container(
              padding: collapsed
                  ? const EdgeInsets.symmetric(vertical: 12)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: isSelected
                    ? Border.all(color: AppTheme.of(context).primary.withValues(alpha: 0.4))
                    : null,
              ),
              child: collapsed
                  ? Center(
                      child: Icon(
                        icon,
                        size: 20,
                        color: isSelected
                            ? AppTheme.of(context).primary
                            : (isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary),
                      ),
                    )
                  : Row(
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: isSelected
                              ? AppTheme.of(context).primary
                              : (isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? (isDark ? Colors.white : AppTheme.of(context).primaryBlue)
                                  : (isDark ? AppTheme.of(context).textPrimary : AppTheme.of(context).textPrimary),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
