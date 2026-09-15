import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/models/order_item.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/services/storage_service.dart';

Future<void> _waitForLoad(ProjectNotifier n) async {
  while (n.state.isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BAMM Data Models', () {
    test('BammWorkOrder fromJson and toJson round trip', () {
      final now = DateTime.now();
      final wo = BammWorkOrder(
        worId: 1001,
        worNoSeq: '185586',
        description: 'Overhaul feed roll bearings on Line 4',
        status: 'In Progress',
        statusId: 2,
        step: 'Work in progress',
        stepId: 4,
        cell: 'LINE 4',
        machine: 'MILL-04',
        assetId: 'AST-401',
        priority: 'High',
        responsible: 'John Doe',
        requester: 'Jane Smith',
        issueDate: now,
        requiredDate: now.add(const Duration(days: 7)),
        laborHours: 4.5,
        requiredEmployees: 2,
        executionMode: 'Planned',
      );

      final json = wo.toJson();
      expect(json['worId'], 1001);
      expect(json['worNoSeq'], '185586');
      expect(json['description'], 'Overhaul feed roll bearings on Line 4');
      expect(json['laborHours'], 4.5);

      final restored = BammWorkOrder.fromJson(json);
      expect(restored.worId, wo.worId);
      expect(restored.worNoSeq, wo.worNoSeq);
      expect(restored.description, wo.description);
      expect(restored.status, wo.status);
      expect(restored.cell, wo.cell);
      expect(restored.machine, wo.machine);
      expect(restored.priority, wo.priority);
      expect(restored.laborHours, wo.laborHours);
    });

    test('BammWorkOrder.fromPropertyList unwraps Cogep GuideTi wrapped structure', () {
      final rawCogepRow = {
        'workOrderId': 554433,
        'propertyList': {
          'WOR_ID': 554433,
          'WOR_NO_SEQ': '190022',
          'WOR_TEXT': 'Hydraulic power unit valve replacement',
          'WOR_STATUS_DESC': 'Approved',
          'WOR_STATUS_ID': 3,
          'WOR_STEP_DESC': 'Awaiting Parts',
          'WOR_STEP_ID': 2,
          'WOR_EQUIPMENT_CODE': 'HPU-02',
          'WOR_DEPARTMENT_CODE': 'HYDRAULICS',
          'WOR_PRIORITY_DESC': 'Urgent',
          'WOR_RESPONSIBLE_NAME': 'Dave M',
          'WOR_REQUESTER_NAME': 'Alex R',
          'WOR_ISSUE_DATE': '2026-09-10T08:00:00.000Z',
          'WOR_REQUIRED_DATE': '2026-09-20T17:00:00.000Z',
          'WOR_EST_LABOR_HOURS': 8.0,
        },
      };

      final wo = BammWorkOrder.fromPropertyList(rawCogepRow);
      expect(wo.worId, 554433);
      expect(wo.worNoSeq, '190022');
      expect(wo.description, 'Hydraulic power unit valve replacement');
      expect(wo.status, 'Approved');
      expect(wo.step, 'Awaiting Parts');
      expect(wo.machine, 'HPU-02');
      expect(wo.cell, 'HYDRAULICS');
      expect(wo.priority, 'Urgent');
      expect(wo.responsible, 'Dave M');
      expect(wo.laborHours, 8.0);
    });

    test('BammSavedFilter serialization', () {
      const filter = BammSavedFilter(
        id: 'f-1',
        name: 'My Urgent Line 4',
        searchQuery: 'cylinder',
        status: 'Approved',
        step: 'Work in progress',
        cell: 'Line 4',
        responsible: 'John',
      );

      final json = filter.toJson();
      final restored = BammSavedFilter.fromJson(json);

      expect(restored.id, 'f-1');
      expect(restored.name, 'My Urgent Line 4');
      expect(restored.searchQuery, 'cylinder');
      expect(restored.status, 'Approved');
      expect(restored.step, 'Work in progress');
      expect(restored.cell, 'Line 4');
      expect(restored.responsible, 'John');
    });

    test('BammConnectionConfig copyWith and serialization', () {
      const cfg = BammConnectionConfig();
      expect(cfg.origin, 'http://app02-ao-plt:82');
      expect(cfg.companyId, 3);

      final updated = cfg.copyWith(
        origin: 'http://10.0.0.5:82',
        usercode: 'MAINT_ENG',
        password: 'secret',
      );
      expect(updated.origin, 'http://10.0.0.5:82');
      expect(updated.usercode, 'MAINT_ENG');
      expect(updated.password, 'secret');
      expect(updated.companyId, 3);

      final json = updated.toJson();
      final fromJson = BammConnectionConfig.fromJson(json);
      expect(fromJson.origin, 'http://10.0.0.5:82');
      expect(fromJson.usercode, 'MAINT_ENG');
      expect(fromJson.password, 'secret');
    });
  });

  group('BAMM Assignments in ProjectProvider', () {
    test('assignBammToProject and removeBammFromProject', () async {
      final notifier = ProjectNotifier(StorageService());
      await _waitForLoad(notifier);

      final project = Project(
        id: 'proj-bamm-1',
        title: 'Turbine Overhaul',
        machine: 'TURBINE-01',
      );
      await notifier.addProject(project);

      await notifier.assignBammToProject('proj-bamm-1', '185586');
      var updated = notifier.state.projects.firstWhere((p) => p.id == 'proj-bamm-1');
      expect(updated.bammWorkOrders, contains('185586'));

      // Duplicate assignment is idempotent
      await notifier.assignBammToProject('proj-bamm-1', '185586');
      updated = notifier.state.projects.firstWhere((p) => p.id == 'proj-bamm-1');
      expect(updated.bammWorkOrders.length, 1);

      // Add a second BAMM
      await notifier.assignBammToProject('proj-bamm-1', '190022');
      updated = notifier.state.projects.firstWhere((p) => p.id == 'proj-bamm-1');
      expect(updated.bammWorkOrders, containsAll(['185586', '190022']));

      // Remove BAMM
      await notifier.removeBammFromProject('proj-bamm-1', '185586');
      updated = notifier.state.projects.firstWhere((p) => p.id == 'proj-bamm-1');
      expect(updated.bammWorkOrders, isNot(contains('185586')));
      expect(updated.bammWorkOrders, contains('190022'));
    });

    test('assignBammToTask and removeBammFromTask', () async {
      final notifier = ProjectNotifier(StorageService());
      await _waitForLoad(notifier);

      final task = TaskItem(id: 'task-1', description: 'Replace seal');
      final project = Project(
        id: 'proj-bamm-2',
        title: 'Pump 3 Maintenance',
        tasks: [task],
      );
      await notifier.addProject(project);

      await notifier.assignBammToTask('proj-bamm-2', 'task-1', '185586');
      var proj = notifier.state.projects.firstWhere((p) => p.id == 'proj-bamm-2');
      expect(proj.tasks.first.bammWorkOrders, contains('185586'));

      await notifier.removeBammFromTask('proj-bamm-2', 'task-1', '185586');
      proj = notifier.state.projects.firstWhere((p) => p.id == 'proj-bamm-2');
      expect(proj.tasks.first.bammWorkOrders, isNot(contains('185586')));
    });

    test('assignBammToOrder and removeBammFromOrder', () async {
      final notifier = ProjectNotifier(StorageService());
      await _waitForLoad(notifier);

      final order = OrderItem(id: 'ord-1', description: 'Seal kit');
      final project = Project(
        id: 'proj-bamm-3',
        title: 'Pump 3 Maintenance',
        orders: [order],
      );
      await notifier.addProject(project);

      await notifier.assignBammToOrder('proj-bamm-3', 'ord-1', '185586');
      var proj = notifier.state.projects.firstWhere((p) => p.id == 'proj-bamm-3');
      expect(proj.orders.first.bammWorkOrders, contains('185586'));

      await notifier.removeBammFromOrder('proj-bamm-3', 'ord-1', '185586');
      proj = notifier.state.projects.firstWhere((p) => p.id == 'proj-bamm-3');
      expect(proj.orders.first.bammWorkOrders, isNot(contains('185586')));
    });

    test('assignBammToStandaloneOrder and removeBammFromStandaloneOrder', () async {
      final notifier = ProjectNotifier(StorageService());
      await _waitForLoad(notifier);

      final standalone = StandaloneOrder(id: 'std-1', description: 'Spare valves');
      await notifier.addStandaloneOrder(standalone);

      await notifier.assignBammToStandaloneOrder('std-1', '185586');
      var order = notifier.state.standaloneOrders.firstWhere((o) => o.id == 'std-1');
      expect(order.bammWorkOrders, contains('185586'));

      await notifier.removeBammFromStandaloneOrder('std-1', '185586');
      order = notifier.state.standaloneOrders.firstWhere((o) => o.id == 'std-1');
      expect(order.bammWorkOrders, isNot(contains('185586')));
    });

    test('findItemsLinkedToBamm finds cross-referenced projects, tasks, and orders', () async {
      final notifier = ProjectNotifier(StorageService());
      await _waitForLoad(notifier);

      final task = TaskItem(id: 't-10', description: 'Align gearbox', bammWorkOrders: ['185586']);
      final order = OrderItem(id: 'o-20', description: 'Coupling kit', bammWorkOrders: ['185586']);
      final project = Project(
        id: 'p-100',
        title: 'Extruder Drive Overhaul',
        bammWorkOrders: ['185586', '190022'],
        tasks: [task],
        orders: [order],
      );
      await notifier.addProject(project);

      final standalone = StandaloneOrder(
        id: 's-30',
        description: 'Bulk grease cartridges',
        bammWorkOrders: ['185586'],
      );
      await notifier.addStandaloneOrder(standalone);

      final linked = notifier.findItemsLinkedToBamm('185586');
      expect(linked.any((item) => item['type'] == 'project' && item['id'] == 'p-100'), isTrue);
      expect(linked.any((item) => item['type'] == 'task' && item['id'] == 't-10'), isTrue);
      expect(linked.any((item) => item['type'] == 'order' && item['id'] == 'o-20'), isTrue);
      expect(linked.any((item) => item['type'] == 'standalone_order' && item['id'] == 's-30'), isTrue);

      final linkedOther = notifier.findItemsLinkedToBamm('190022');
      expect(linkedOther.length, 1);
      expect(linkedOther.first['type'], 'project');
      expect(linkedOther.first['id'], 'p-100');
    });

    test('linkOrderToProject preserves bammWorkOrders when converting standalone order', () async {
      final notifier = ProjectNotifier(StorageService());
      await _waitForLoad(notifier);

      final project = Project(id: 'p-dest', title: 'Destination Project');
      await notifier.addProject(project);

      final standalone = StandaloneOrder(
        id: 's-to-link',
        description: 'Servo motor replacement',
        bammWorkOrders: ['185586'],
      );
      await notifier.addStandaloneOrder(standalone);

      await notifier.linkOrderToProject('s-to-link', 'p-dest');

      final updatedProj = notifier.state.projects.firstWhere((p) => p.id == 'p-dest');
      expect(updatedProj.orders.length, 1);
      expect(updatedProj.orders.first.bammWorkOrders, contains('185586'));
      expect(notifier.state.standaloneOrders.any((s) => s.id == 's-to-link'), isFalse);
    });
  });
}
