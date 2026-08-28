import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/widgets/responsive_scaffold.dart';
import '../ui/screens/dashboard_screen.dart';
import '../ui/screens/projects_screen.dart';
import '../ui/screens/project_detail_screen.dart';
import '../ui/screens/project_edit_screen.dart';
import '../ui/screens/open_orders_screen.dart';
import '../ui/screens/workbench_screen.dart';
import '../ui/screens/voice_notes_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/tasks_calendar_screen.dart';
import '../ui/screens/what_next_screen.dart';
import '../ui/screens/report_screen.dart';
import '../ui/screens/search_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
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
              path: '/',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DashboardScreen(),
              ),
            ),
          ],
        ),

        // Branch 1: Projects
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
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    final initialTitle = extra?['initialTitle'] as String?;
                    return ProjectEditScreen(initialTitle: initialTitle);
                  },
                ),
                GoRoute(
                  path: 'queue',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const WhatNextScreen(),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    final tab = state.uri.queryParameters['tab'];
                    return ProjectDetailScreen(projectId: id, initialTab: tab);
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

        // Branch 2: Open Orders
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/orders',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: OpenOrdersScreen(),
              ),
            ),
          ],
        ),

        // Branch 3: Workbench Tools
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/workbench',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: WorkbenchScreen(),
              ),
            ),
          ],
        ),

        // Branch 4: Voice Notes
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

        // Branch 5: Settings
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
    GoRoute(
      path: '/calendar',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TasksCalendarScreen(),
    ),
    GoRoute(
      path: '/report',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ReportScreen(),
    ),
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const NoTransitionPage(
        child: SearchScreen(),
      ),
    ),
  ],
);
