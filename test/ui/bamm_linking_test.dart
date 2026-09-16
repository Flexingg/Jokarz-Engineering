// Tests for BAMM linking in BammDetailDialog:
// 1. Search box in link sheet filters projects, tasks, and orders as you type.
// 2. Create-then-link inline for Project (blank and from template), Task, and Order:
//    pre-fills from the work order and calls the right provider ops.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jokarz_engineering/models/activity_log.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/models/downtime_event.dart';
import 'package:jokarz_engineering/models/filament_profile.dart';
import 'package:jokarz_engineering/models/inbox_item.dart';
import 'package:jokarz_engineering/models/order_item.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/project_template.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/providers/bamm_provider.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/services/bamm_service.dart';
import 'package:jokarz_engineering/services/storage_service.dart';
import 'package:jokarz_engineering/ui/widgets/bamm_detail_dialog.dart';

class _FakeStorageService extends StorageService {
  final List<Project> seedProjects;
  final List<ProjectTemplate> seedTemplates;

  _FakeStorageService({
    this.seedProjects = const [],
    this.seedTemplates = const [],
  });

  @override
  Future<Map<String, dynamic>> loadData() async => {
        'projects': [...seedProjects],
        'voiceNotes': <VoiceNote>[],
        'filaments': <FilamentProfile>[],
        'standaloneOrders': <StandaloneOrder>[],
        'inboxItems': <InboxItem>[],
        'vendors': <Vendor>[],
        'customTemplates': [...seedTemplates],
        'snoozedProjects': <String, String>{},
      };

  @override
  Future<List<ActivityLog>> loadActivityLog() async => [];

  @override
  Future<List<DowntimeEvent>> loadDowntimes() async => [];

  @override
  Future<void> saveActivityLog(List<ActivityLog> logs) async {}

  @override
  Future<void> saveDowntimes(List<DowntimeEvent> downtimes) async {}

  @override
  Future<Map<String, String>> loadKeyBindings() async => {};

  @override
  Future<void> saveKeyBindings(Map<String, String> bindings) async {}

  @override
  Future<void> saveData({
    required List<Project> projects,
    required List<VoiceNote> voiceNotes,
    required List<FilamentProfile> customFilaments,
    List<StandaloneOrder> standaloneOrders = const [],
    List<InboxItem> inboxItems = const [],
    List<Vendor> vendors = const [],
    List<ProjectTemplate> customTemplates = const [],
    Map<String, String> snoozedProjects = const {},
  }) async {}
}

class _TrackingProjectNotifier extends ProjectNotifier {
  final List<String> recordedOps = [];

  _TrackingProjectNotifier(
    super.storage, {
    List<Project>? seedProjects,
    List<ProjectTemplate>? seedTemplates,
  }) {
    state = EngineeringState(
      projects: seedProjects ?? [],
      customTemplates: seedTemplates ?? [],
    );
  }

  @override
  Future<void> addProject(Project project) async {
    recordedOps.add('addProject:${project.id}:${project.title}');
    await super.addProject(project);
  }

  @override
  Future<Project> createProjectFromTemplate(
    ProjectTemplate template, {
    String? customTitle,
    String? customMachine,
    DateTime? startDate,
  }) async {
    recordedOps.add('createProjectFromTemplate:${template.id}:$customTitle');
    return await super.createProjectFromTemplate(
      template,
      customTitle: customTitle,
      customMachine: customMachine,
      startDate: startDate,
    );
  }

  @override
  Future<void> addTask(String projectId, TaskItem task) async {
    recordedOps.add('addTask:$projectId:${task.id}:${task.description}');
    await super.addTask(projectId, task);
  }

  @override
  Future<void> addOrder(String projectId, OrderItem order) async {
    recordedOps.add('addOrder:$projectId:${order.id}:${order.description}');
    await super.addOrder(projectId, order);
  }

  @override
  Future<void> assignBammToProject(String projectId, String bammWo) async {
    recordedOps.add('assignBammToProject:$projectId:$bammWo');
    await super.assignBammToProject(projectId, bammWo);
  }

  @override
  Future<void> assignBammToTask(String projectId, String taskId, String bammWo) async {
    recordedOps.add('assignBammToTask:$projectId:$taskId:$bammWo');
    await super.assignBammToTask(projectId, taskId, bammWo);
  }

  @override
  Future<void> assignBammToOrder(String projectId, String orderId, String bammWo) async {
    recordedOps.add('assignBammToOrder:$projectId:$orderId:$bammWo');
    await super.assignBammToOrder(projectId, orderId, bammWo);
  }
}

class _FakeBammNotifier extends BammNotifier {
  _FakeBammNotifier(BammWorkOrder seed) : super(BammService()) {
    state = BammState(workOrders: [seed]);
  }

  @override
  Future<void> init() async {}

  @override
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async =>
      state.workOrders.where((w) => w.worId == worId).firstOrNull;
}

BammWorkOrder _sampleWorkOrder() => BammWorkOrder(
      worId: 190022,
      worNoSeq: '190022',
      description: 'Hydraulic valve overhaul',
      status: 'Approved',
      step: 'Normal',
      machine: 'Line 2 Hydraulic Unit',
      responsible: 'Dave M',
    );

void main() {
  group('BAMM linking search box', () {
    testWidgets('filters projects, tasks, and orders as user types, and restores on clear', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final proj1 = Project(
        id: 'proj-1',
        title: 'Turbine Overhaul',
        description: 'Main generator turbine',
        machine: 'TURBINE-01',
        tasks: [
          TaskItem(id: 'task-1a', description: 'Replace high-pressure seal'),
          TaskItem(id: 'task-1b', description: 'Calibrate speed governor'),
        ],
        orders: [
          OrderItem(id: 'ord-1a', description: 'Seal kit', po: 'PO-9911'),
        ],
      );

      final proj2 = Project(
        id: 'proj-2',
        title: 'Packer Conveyor Line',
        description: 'Secondary conveyor system',
        machine: 'PACKER-02',
        tasks: [
          TaskItem(id: 'task-2a', description: 'Align belt rollers'),
        ],
        orders: [
          OrderItem(id: 'ord-2a', description: 'Roller bearings', po: 'PO-8822'),
        ],
      );

      final proj3 = Project(
        id: 'proj-3',
        title: 'Safety Gate Sensor',
        description: 'Interlock upgrade',
        machine: 'GATE-01',
      );

      final fakeStorage = _FakeStorageService(
        seedProjects: [proj1, proj2, proj3],
      );
      final trackingNotifier = _TrackingProjectNotifier(
        fakeStorage,
        seedProjects: [proj1, proj2, proj3],
      );
      final wo = _sampleWorkOrder();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            bammProvider.overrideWith((ref) => _FakeBammNotifier(wo)),
            projectProvider.overrideWith((ref) => trackingNotifier),
          ],
          child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
        ),
      );
      await tester.pumpAndSettle();

      // Open the link sheet
      await tester.tap(find.text('Link Item'));
      await tester.pumpAndSettle();

      // Verify all 3 projects are initially visible
      expect(find.text('Turbine Overhaul'), findsOneWidget);
      expect(find.text('Packer Conveyor Line'), findsOneWidget);
      expect(find.text('Safety Gate Sensor'), findsOneWidget);

      final searchFinder = find.byKey(const Key('bamm_link_search_input'));
      expect(searchFinder, findsOneWidget);

      // 1. Search by project title ("Turbine")
      await tester.enterText(searchFinder, 'Turbine');
      await tester.pumpAndSettle();

      expect(find.text('Turbine Overhaul'), findsOneWidget);
      expect(find.text('Packer Conveyor Line'), findsNothing);
      expect(find.text('Safety Gate Sensor'), findsNothing);

      // 2. Search by task description ("belt rollers" which is only in proj2)
      await tester.enterText(searchFinder, 'belt rollers');
      await tester.pumpAndSettle();

      expect(find.text('Turbine Overhaul'), findsNothing);
      expect(find.text('Packer Conveyor Line'), findsOneWidget);
      expect(find.text('Safety Gate Sensor'), findsNothing);
      expect(find.text('Align belt rollers'), findsOneWidget);

      // 3. Search by order PO ("PO-9911" which is only in proj1)
      await tester.enterText(searchFinder, 'PO-9911');
      await tester.pumpAndSettle();

      expect(find.text('Turbine Overhaul'), findsOneWidget);
      expect(find.text('Packer Conveyor Line'), findsNothing);
      expect(find.text('Safety Gate Sensor'), findsNothing);
      expect(find.text('Seal kit'), findsOneWidget);

      // 4. Search matching nothing
      await tester.enterText(searchFinder, 'nonexistent query 123');
      await tester.pumpAndSettle();

      expect(find.textContaining('No projects, tasks, or orders match'), findsOneWidget);
      expect(find.text('Turbine Overhaul'), findsNothing);
      expect(find.text('Packer Conveyor Line'), findsNothing);

      // 5. Clear search restores all 3 projects
      await tester.enterText(searchFinder, '');
      await tester.pumpAndSettle();

      expect(find.text('Turbine Overhaul'), findsOneWidget);
      expect(find.text('Packer Conveyor Line'), findsOneWidget);
      expect(find.text('Safety Gate Sensor'), findsOneWidget);
    });
  });

  group('BAMM create-then-link inline', () {
    testWidgets('creates a new blank project pre-filled from work order and links it', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeStorage = _FakeStorageService(seedProjects: []);
      final trackingNotifier = _TrackingProjectNotifier(fakeStorage, seedProjects: []);
      final wo = _sampleWorkOrder();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            bammProvider.overrideWith((ref) => _FakeBammNotifier(wo)),
            projectProvider.overrideWith((ref) => trackingNotifier),
          ],
          child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
        ),
      );
      await tester.pumpAndSettle();

      // Open the link sheet
      await tester.tap(find.text('Link Item'));
      await tester.pumpAndSettle();

      // Tap "+ New Project" button
      await tester.tap(find.byKey(const Key('bamm_create_project_btn')));
      await tester.pumpAndSettle();

      // Verify the dialog opened with pre-filled fields
      expect(find.text('Create & Link Project'), findsOneWidget);
      expect(find.widgetWithText(TextField, wo.displayTitle), findsOneWidget);
      expect(find.widgetWithText(TextField, wo.machine), findsOneWidget);

      // Tap "Create & Link"
      await tester.tap(find.byKey(const Key('confirm_create_project_btn')));
      await tester.pumpAndSettle();

      // Verify both provider operations were called in sequence
      expect(trackingNotifier.recordedOps.any((op) => op.startsWith('addProject:')), isTrue);
      expect(trackingNotifier.recordedOps.any((op) => op.startsWith('assignBammToProject:') && op.endsWith(':190022')), isTrue);

      // Verify the dialog closed and the project is linked in BammDetailDialog
      expect(find.text('Linked in AOR Engineering:'), findsOneWidget);
      expect(find.text('Project: ${wo.displayTitle}'), findsOneWidget);
    });

    testWidgets('creates a project from template pre-filled and links it', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final customTemplate = ProjectTemplate(
        id: 'tmpl-pm-valve',
        name: 'Valve PM Template',
        description: 'Standard overhaul template',
        tasks: const [
          TaskTemplate(description: 'Inspect valve seats'),
        ],
      );

      final fakeStorage = _FakeStorageService(
        seedProjects: [],
        seedTemplates: [customTemplate],
      );
      final trackingNotifier = _TrackingProjectNotifier(
        fakeStorage,
        seedProjects: [],
        seedTemplates: [customTemplate],
      );
      final wo = _sampleWorkOrder();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            bammProvider.overrideWith((ref) => _FakeBammNotifier(wo)),
            projectProvider.overrideWith((ref) => trackingNotifier),
          ],
          child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
        ),
      );
      await tester.pumpAndSettle();

      // Open link sheet
      await tester.tap(find.text('Link Item'));
      await tester.pumpAndSettle();

      // Tap "+ New Project"
      await tester.tap(find.byKey(const Key('bamm_create_project_btn')));
      await tester.pumpAndSettle();

      // Select the template from dropdown
      await tester.tap(find.byKey(const Key('create_project_template_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valve PM Template').last);
      await tester.pumpAndSettle();

      // Tap "Create & Link"
      await tester.tap(find.byKey(const Key('confirm_create_project_btn')));
      await tester.pumpAndSettle();

      // Verify createProjectFromTemplate and assignBammToProject were called
      expect(
        trackingNotifier.recordedOps.any((op) => op.startsWith('createProjectFromTemplate:tmpl-pm-valve:')),
        isTrue,
      );
      expect(
        trackingNotifier.recordedOps.any((op) => op.startsWith('assignBammToProject:') && op.endsWith(':190022')),
        isTrue,
      );

      // Verify linked in UI
      expect(find.text('Linked in AOR Engineering:'), findsOneWidget);
    });

    testWidgets('creates a new task pre-filled from work order and links it', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final existingProject = Project(
        id: 'proj-hydraulics',
        title: 'Hydraulic Systems 2026',
      );

      final fakeStorage = _FakeStorageService(
        seedProjects: [existingProject],
      );
      final trackingNotifier = _TrackingProjectNotifier(
        fakeStorage,
        seedProjects: [existingProject],
      );
      final wo = _sampleWorkOrder();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            bammProvider.overrideWith((ref) => _FakeBammNotifier(wo)),
            projectProvider.overrideWith((ref) => trackingNotifier),
          ],
          child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
        ),
      );
      await tester.pumpAndSettle();

      // Open link sheet
      await tester.tap(find.text('Link Item'));
      await tester.pumpAndSettle();

      // Tap "+ New Task"
      await tester.tap(find.byKey(const Key('bamm_create_task_btn')));
      await tester.pumpAndSettle();

      // Verify pre-filled description
      expect(find.text('Create & Link Task'), findsOneWidget);
      expect(find.widgetWithText(TextField, wo.displayTitle), findsOneWidget);

      // Tap "Create & Link"
      await tester.tap(find.byKey(const Key('confirm_create_task_btn')));
      await tester.pumpAndSettle();

      // Verify addTask and assignBammToTask were called
      expect(
        trackingNotifier.recordedOps.any((op) => op.startsWith('addTask:proj-hydraulics:')),
        isTrue,
      );
      expect(
        trackingNotifier.recordedOps.any((op) => op.startsWith('assignBammToTask:proj-hydraulics:') && op.endsWith(':190022')),
        isTrue,
      );

      // Verify linked in UI
      expect(find.text('Linked in AOR Engineering:'), findsOneWidget);
      expect(find.textContaining('Task: ${wo.displayTitle}'), findsOneWidget);
    });

    testWidgets('creates a new order pre-filled from work order and links it', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final existingProject = Project(
        id: 'proj-hydraulics',
        title: 'Hydraulic Systems 2026',
      );

      final fakeStorage = _FakeStorageService(
        seedProjects: [existingProject],
      );
      final trackingNotifier = _TrackingProjectNotifier(
        fakeStorage,
        seedProjects: [existingProject],
      );
      final wo = _sampleWorkOrder();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            bammProvider.overrideWith((ref) => _FakeBammNotifier(wo)),
            projectProvider.overrideWith((ref) => trackingNotifier),
          ],
          child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
        ),
      );
      await tester.pumpAndSettle();

      // Open link sheet
      await tester.tap(find.text('Link Item'));
      await tester.pumpAndSettle();

      // Tap "+ New Order"
      await tester.tap(find.byKey(const Key('bamm_create_order_btn')));
      await tester.pumpAndSettle();

      // Verify pre-filled description
      expect(find.text('Create & Link Order'), findsOneWidget);
      expect(find.widgetWithText(TextField, wo.displayTitle), findsOneWidget);

      // Tap "Create & Link"
      await tester.tap(find.byKey(const Key('confirm_create_order_btn')));
      await tester.pumpAndSettle();

      // Verify addOrder and assignBammToOrder were called
      expect(
        trackingNotifier.recordedOps.any((op) => op.startsWith('addOrder:proj-hydraulics:')),
        isTrue,
      );
      expect(
        trackingNotifier.recordedOps.any((op) => op.startsWith('assignBammToOrder:proj-hydraulics:') && op.endsWith(':190022')),
        isTrue,
      );

      // Verify linked in UI
      expect(find.text('Linked in AOR Engineering:'), findsOneWidget);
      expect(find.textContaining('Order: ${wo.displayTitle}'), findsOneWidget);
    });

    testWidgets('creates a new task inline from an expanded project tile', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final existingProject = Project(
        id: 'proj-hydraulics',
        title: 'Hydraulic Systems 2026',
      );

      final fakeStorage = _FakeStorageService(
        seedProjects: [existingProject],
      );
      final trackingNotifier = _TrackingProjectNotifier(
        fakeStorage,
        seedProjects: [existingProject],
      );
      final wo = _sampleWorkOrder();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            bammProvider.overrideWith((ref) => _FakeBammNotifier(wo)),
            projectProvider.overrideWith((ref) => trackingNotifier),
          ],
          child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
        ),
      );
      await tester.pumpAndSettle();

      // Open link sheet
      await tester.tap(find.text('Link Item'));
      await tester.pumpAndSettle();

      // Expand the project tile
      await tester.tap(find.text('Hydraulic Systems 2026'));
      await tester.pumpAndSettle();

      // Tap the "New Task" button inside the expanded tile
      await tester.tap(find.byKey(const Key('project_new_task_proj-hydraulics')));
      await tester.pumpAndSettle();

      expect(find.text('Create & Link Task'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_create_task_btn')));
      await tester.pumpAndSettle();

      expect(
        trackingNotifier.recordedOps.any((op) => op.startsWith('addTask:proj-hydraulics:')),
        isTrue,
      );
      expect(
        trackingNotifier.recordedOps.any((op) => op.startsWith('assignBammToTask:proj-hydraulics:') && op.endsWith(':190022')),
        isTrue,
      );
    });

    testWidgets('creates a new order inline from an expanded project tile', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final existingProject = Project(
        id: 'proj-hydraulics',
        title: 'Hydraulic Systems 2026',
      );

      final fakeStorage = _FakeStorageService(
        seedProjects: [existingProject],
      );
      final trackingNotifier = _TrackingProjectNotifier(
        fakeStorage,
        seedProjects: [existingProject],
      );
      final wo = _sampleWorkOrder();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            bammProvider.overrideWith((ref) => _FakeBammNotifier(wo)),
            projectProvider.overrideWith((ref) => trackingNotifier),
          ],
          child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
        ),
      );
      await tester.pumpAndSettle();

      // Open link sheet
      await tester.tap(find.text('Link Item'));
      await tester.pumpAndSettle();

      // Expand the project tile
      await tester.tap(find.text('Hydraulic Systems 2026'));
      await tester.pumpAndSettle();

      // Tap the "New Order" button inside the expanded tile
      await tester.tap(find.byKey(const Key('project_new_order_proj-hydraulics')));
      await tester.pumpAndSettle();

      expect(find.text('Create & Link Order'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_create_order_btn')));
      await tester.pumpAndSettle();

      expect(
        trackingNotifier.recordedOps.any((op) => op.startsWith('addOrder:proj-hydraulics:')),
        isTrue,
      );
      expect(
        trackingNotifier.recordedOps.any((op) => op.startsWith('assignBammToOrder:proj-hydraulics:') && op.endsWith(':190022')),
        isTrue,
      );
    });
  });
}
