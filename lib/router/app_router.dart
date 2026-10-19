import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/fluid_background.dart';
import '../theme/sections.dart';
import '../ui/adaptive/nav_shell.dart';
import '../ui/screens/dashboard_screen.dart';
import '../ui/screens/projects_screen.dart';
import '../ui/screens/project_detail_screen.dart';
import '../ui/screens/project_edit_screen.dart';
import '../ui/screens/open_orders_screen.dart';
import '../ui/screens/workbench_screen.dart';
import '../ui/screens/voice_notes_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/tasks_calendar_screen.dart';
import '../ui/screens/overdue_tasks_screen.dart';
import '../ui/screens/what_next_screen.dart';
import '../ui/screens/report_screen.dart';
import '../ui/screens/photo_note_editor_screen.dart';
import '../ui/screens/inbox_screen.dart';
import '../ui/screens/vendors_screen.dart';
import '../ui/screens/machines_screen.dart';
import '../ui/screens/machine_detail_screen.dart';
import '../ui/screens/bamm_screen.dart';
import '../ui/screens/bamm_batch_update_screen.dart';
import '../ui/screens/day_schedule_screen.dart';
import '../ui/screens/fab_list_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AdaptiveNavShell(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0: Dashboard
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) =>
                  const FluidNoTransitionPage(child: DashboardScreen()),
            ),
          ],
        ),

        // Branch 1: Projects
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/projects',
              pageBuilder: (context, state) => const FluidNoTransitionPage(
                child: SectionTheme(
                  section: AppSection.projects,
                  child: ProjectsScreen(),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    final initialTitle = extra?['initialTitle'] as String?;
                    return SectionTheme(
                      section: AppSection.projects,
                      child: ProjectEditScreen(initialTitle: initialTitle),
                    );
                  },
                ),
                GoRoute(
                  path: 'queue',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const SectionTheme(
                    section: AppSection.projects,
                    child: WhatNextScreen(),
                  ),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    final tab = state.uri.queryParameters['tab'];
                    final orderId = state.uri.queryParameters['orderId'];
                    final taskId = state.uri.queryParameters['taskId'];
                    return SectionTheme(
                      section: AppSection.projects,
                      child: ProjectDetailScreen(
                        projectId: id,
                        initialTab: tab,
                        targetOrderId: orderId,
                        targetTaskId: taskId,
                      ),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        return SectionTheme(
                          section: AppSection.projects,
                          child: ProjectEditScreen(projectId: id),
                        );
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
              pageBuilder: (context, state) => FluidNoTransitionPage(
                child: SectionTheme(
                  section: AppSection.orders,
                  child: OpenOrdersScreen(
                    targetOrderId: state.uri.queryParameters['orderId'],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Branch 3: Workbench Tools
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/workbench',
              pageBuilder: (context, state) => const FluidNoTransitionPage(
                child: SectionTheme(
                  section: AppSection.tools,
                  child: WorkbenchScreen(),
                ),
              ),
            ),
          ],
        ),

        // Branch 4: Voice Notes
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/voice-notes',
              pageBuilder: (context, state) => FluidNoTransitionPage(
                child: SectionTheme(
                  section: AppSection.notes,
                  child: VoiceNotesScreen(
                    targetNoteId: state.uri.queryParameters['noteId'],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Branch 5: Settings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => const FluidNoTransitionPage(
                child: SectionTheme(
                  section: AppSection.settings,
                  child: SettingsScreen(),
                ),
              ),
            ),
          ],
        ),

        // Branch 6: BAMM Orders
        // Lives INSIDE the shell on purpose: as a root-navigator route it rendered
        // without shell chrome, which is why the sidebar disappeared on this screen.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bamm',
              pageBuilder: (context, state) => FluidNoTransitionPage(
                child: SectionTheme(
                  section: AppSection.bamm,
                  child: BammScreen(
                    targetWo: state.uri.queryParameters['wo'],
                    initialFilter: state.uri.queryParameters['filter'],
                    snapshotHash: state.uri.queryParameters['h'],
                    printedAtEpochMs: state.uri.queryParameters['t'],
                  ),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'batch',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const SectionTheme(
                    section: AppSection.bamm,
                    child: BammBatchUpdateScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/calendar',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SectionTheme(
        section: AppSection.calendar,
        child: TasksCalendarScreen(),
      ),
    ),
    GoRoute(
      path: '/schedule',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SectionTheme(
        section: AppSection.calendar,
        child: DayScheduleScreen(),
      ),
    ),
    GoRoute(
      path: '/overdue',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SectionTheme(
        section: AppSection.calendar,
        child: OverdueTasksScreen(),
      ),
    ),
    GoRoute(
      path: '/report',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ReportScreen(),
    ),
    GoRoute(
      path: '/photo-note',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => FluidNoTransitionPage(
        child: SectionTheme(
          section: AppSection.notes,
          child: PhotoNoteEditorScreen(
            imagePath: state.uri.queryParameters['path'] ?? '',
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/inbox',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const FluidNoTransitionPage(
        child: SectionTheme(section: AppSection.notes, child: InboxScreen()),
      ),
    ),
    GoRoute(
      path: '/fab',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const FluidNoTransitionPage(
        child: SectionTheme(section: AppSection.fab, child: FabListScreen()),
      ),
    ),
    GoRoute(
      path: '/vendors',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const FluidNoTransitionPage(
        child: SectionTheme(section: AppSection.orders, child: VendorsScreen()),
      ),
    ),
    GoRoute(
      path: '/machines',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const FluidNoTransitionPage(
        child: SectionTheme(section: AppSection.tools, child: MachinesScreen()),
      ),
      routes: [
        GoRoute(
          path: ':name',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final name = Uri.decodeComponent(state.pathParameters['name']!);
            return SectionTheme(
              section: AppSection.tools,
              child: MachineDetailScreen(machineName: name),
            );
          },
        ),
      ],
    ),
  ],
);

/// The root navigator's BuildContext, used by global shortcuts to show dialogs.
BuildContext? get appRootContext => _rootNavigatorKey.currentContext;
