import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/theme_provider.dart';
import 'voice_memo_modal.dart';

class ResponsiveScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ResponsiveScaffold({
    super.key,
    required this.navigationShell,
  });

  void _onTapNav(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          // Desktop & Tablet Navigation Rail Layout
          return Scaffold(
            body: Row(
              children: [
                // Custom Expressive Navigation Rail
                Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                    border: Border(
                      right: BorderSide(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      // App Brand & Logo
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.primaryCyan,
                                    AppTheme.primaryBlue,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: const Icon(
                                Icons.precision_manufacturing_rounded,
                                color: Colors.black87,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'JOKARZ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      color: AppTheme.primaryCyan,
                                    ),
                                  ),
                                  Text(
                                    'ENGINEERING',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Navigation Items
                      _buildDesktopNavItem(
                        context,
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        isSelected: navigationShell.currentIndex == 0,
                        onTap: () => _onTapNav(0),
                      ),
                      _buildDesktopNavItem(
                        context,
                        icon: Icons.folder_special_rounded,
                        label: 'Projects & BOM',
                        isSelected: navigationShell.currentIndex == 1,
                        onTap: () => _onTapNav(1),
                      ),
                      _buildDesktopNavItem(
                        context,
                        icon: Icons.handyman_rounded,
                        label: 'Workbench Tools',
                        isSelected: navigationShell.currentIndex == 2,
                        onTap: () => _onTapNav(2),
                      ),
                      _buildDesktopNavItem(
                        context,
                        icon: Icons.mic_external_on_rounded,
                        label: 'Voice Lab Notes',
                        isSelected: navigationShell.currentIndex == 3,
                        onTap: () => _onTapNav(3),
                      ),
                      _buildDesktopNavItem(
                        context,
                        icon: Icons.settings_suggest_rounded,
                        label: 'Workshop Settings',
                        isSelected: navigationShell.currentIndex == 4,
                        onTap: () => _onTapNav(4),
                      ),

                      const Spacer(),

                      // Quick Voice Record FAB
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: OutlinedButton.icon(
                          onPressed: () => VoiceMemoModal.show(context),
                          icon: const Icon(Icons.mic, color: AppTheme.accentAmber, size: 18),
                          label: const Text(
                            'Quick Voice Memo',
                            style: TextStyle(color: AppTheme.accentAmber, fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.accentAmber),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      // Theme Mode Switcher
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isDark ? 'Dark Mode' : 'Light Mode',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            IconButton(
                              icon: Icon(
                                themeMode == ThemeMode.dark
                                    ? Icons.dark_mode_rounded
                                    : Icons.light_mode_rounded,
                                color: AppTheme.primaryCyan,
                                size: 20,
                              ),
                              onPressed: () =>
                                  ref.read(themeModeProvider.notifier).toggleTheme(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content Body
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        // Mobile Layout with Expressive NavigationBar
        return Scaffold(
          body: navigationShell,
          floatingActionButton: FloatingActionButton(
            onPressed: () => VoiceMemoModal.show(context),
            backgroundColor: AppTheme.primaryCyan,
            foregroundColor: Colors.black87,
            child: const Icon(Icons.mic_rounded),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTapNav,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_special_rounded),
                label: 'Projects',
              ),
              NavigationDestination(
                icon: Icon(Icons.handyman_outlined),
                selectedIcon: Icon(Icons.handyman_rounded),
                label: 'Workbench',
              ),
              NavigationDestination(
                icon: Icon(Icons.mic_none_rounded),
                selectedIcon: Icon(Icons.mic_external_on_rounded),
                label: 'Voice Logs',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_suggest_rounded),
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
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Material(
        color: isSelected
            ? AppTheme.primaryCyan.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: isSelected
                  ? Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.4))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppTheme.primaryCyan
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? (isDark ? Colors.white : AppTheme.primaryBlue)
                          : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
