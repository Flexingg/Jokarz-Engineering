import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/widgets/responsive_scaffold.dart';
import '../ui/screens/dashboard_screen.dart';
import '../ui/screens/projects_screen.dart';
import '../ui/screens/project_detail_screen.dart';
import '../ui/screens/project_edit_screen.dart';
import '../ui/screens/workbench_screen.dart';
import '../ui/screens/voice_notes_screen.dart';
import '../ui/screens/settings_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ResponsiveScaffold(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0: Dashboard
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DashboardScreen(),
              ),
            ),
          ],
        ),

        // Branch 1: Projects & BOM
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/projects',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ProjectsScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const ProjectEditScreen(),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return ProjectDetailScreen(projectId: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        return ProjectEditScreen(projectId: id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Branch 2: Workbench Tools
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/workbench',
              pageBuilder: (context, state) {
                final tabParam = state.uri.queryParameters['tab'];
                final tabIndex = int.tryParse(tabParam ?? '0') ?? 0;
                return NoTransitionPage(
                  child: WorkbenchScreen(initialTabIndex: tabIndex),
                );
              },
            ),
          ],
        ),

        // Branch 3: Voice Notes & Field Logs
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/voice-notes',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: VoiceNotesScreen(),
              ),
            ),
          ],
        ),

        // Branch 4: Settings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
