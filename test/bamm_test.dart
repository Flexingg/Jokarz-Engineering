import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/models/order_item.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/services/bamm_service.dart';
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
        requester: 'Jane',
        machine: 'MILL-04',
        maintenanceType: 'Preventive',
        executionMode: 'Running',
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
      expect(restored.requester, 'Jane');
      expect(restored.machine, 'MILL-04');
      expect(restored.maintenanceType, 'Preventive');
      expect(restored.executionMode, 'Running');

      final criteria = restored.toCriteria();
      expect(criteria.searchQuery, 'cylinder');
      expect(criteria.status, 'Approved');
      expect(criteria.cell, 'Line 4');
      expect(criteria.responsible, 'John');

      final backToFilter = BammSavedFilter.fromCriteria(id: 'f-2', name: 'Rebuilt', criteria: criteria);
      expect(backToFilter.id, 'f-2');
      expect(backToFilter.name, 'Rebuilt');
      expect(backToFilter.status, 'Approved');
      expect(backToFilter.responsible, 'John');
    });

    test('BammWorkOrder handles workDone field and DynamicDTO parsing', () {
      final dto = {
        'properties': [
          {'name': 'WOR_ID', 'value': 195001},
          {'name': 'WOR_NO_SEQ', 'value': '195001'},
          {'name': 'WOR_DESCR', 'value': 'Gearbox oil change and inspection'},
          {'name': 'WOR_STATUS_DESC', 'value': 'Closed'},
          {'name': 'WOR_STEP_DESC', 'value': 'Completed'},
          {'name': 'WOR_RESPONSIBLE_NAME', 'value': 'Maint Tech'},
          {'name': 'WOR_REQUESTER_NAME', 'value': 'Supervisor'},
          {'name': 'WOR_DEPARTMENT_CODE', 'value': 'PACK-LINE-2'},
          {'name': 'WOR_EQUIPMENT_CODE', 'value': 'CONV-MOTOR-01'},
          {'name': 'WOR_ISSUE_DATE', 'value': '2026-09-12T07:30:00.000Z'},
          {'name': 'WOR_REQUI_DATE', 'value': '2026-09-12T16:00:00.000Z'},
          {'name': 'WOR_EST_LABOR_HOURS', 'value': 2.5},
        ],
        'childSets': [
          {
            'originProperty': 'WO_DETAIL',
            'items': [
              {
                'properties': [
                  {
                    'name': 'WOD_DESCR',
                    'value': 'Drained oil, flushed gearbox, refilled with ISO VG 220 synthetic. Replaced seal.'
                  }
                ]
              }
            ]
          }
        ]
      };

      final parsed = BammWorkOrder.fromDynamicDto(dto);
      expect(parsed.worId, 195001);
      expect(parsed.worNoSeq, '195001');
      expect(parsed.description, 'Gearbox oil change and inspection');
      expect(parsed.workDone, contains('Drained oil, flushed gearbox'));
      expect(parsed.status, 'Closed');
      expect(parsed.step, 'Completed');
      expect(parsed.responsible, 'Maint Tech');
      expect(parsed.requester, 'Supervisor');
      expect(parsed.cell, 'PACK-LINE-2');
      expect(parsed.machine, 'CONV-MOTOR-01');
      expect(parsed.laborHours, 2.5);

      final json = parsed.toJson();
      final roundTrip = BammWorkOrder.fromJson(json);
      expect(roundTrip.workDone, parsed.workDone);
      expect(roundTrip.worNoSeq, '195001');
    });

    test('BammFilterCriteria tracking and counting', () {
      const emptyCriteria = BammFilterCriteria();
      expect(emptyCriteria.isEmpty, isTrue);
      expect(emptyCriteria.activeFilterCount, 0);

      final criteria = const BammFilterCriteria().copyWith(
        searchQuery: 'leak',
        status: 'In Progress',
        cell: 'CELL-1',
      );
      expect(criteria.isEmpty, isFalse);
      expect(criteria.activeFilterCount, 3);
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

    test('BammService.buildFilterPayload creates correct GuideTi query structure with woIssueDate descending', () {
      final service = BammService();
      final criteria = const BammFilterCriteria(
        status: 'In preparation',
        step: 'Emergency',
        area: '100',
        maintenanceType: 'Planned - Corrective Maint.',
        responsible: 'John Tech',
        requester: 'Operator Dan',
        machine: 'PRESS-01',
        executionMode: 'Down',
        searchQuery: '198440',
      );

      final payload = service.buildFilterPayload(criteria);

      // Verify server-side sorting: latest 2000 descending by woIssueDate
      final listFormat = payload['listFormat'] as Map<String, dynamic>;
      expect(listFormat['topCount'], 2000);
      final orderBy = (listFormat['orderByFields'] as List).first as Map<String, dynamic>;
      expect(orderBy['name'], 'woIssueDate');
      expect(orderBy['ascending'], isFalse);

      // Verify major fields requested including Area (regrouping1Description)
      final fields = (listFormat['fields'] as List).map((f) => f['name']).toList();
      expect(fields, containsAll([
        'worNoSeq',
        'woIssueDate',
        'recipientName',
        'requesterName',
        'woTask',
        'woDescription',
        'regrouping1Description',
        'funCodeLevelNiv3Description',
        'woStatusDescription',
        'woStepDescription',
      ]));

      // Verify filters mapped to GuideTi block structure
      final filters = payload['filters'] as List;
      expect(filters.any((f) => f['searchFieldKey'] == 'woStatusId'), isTrue);
      expect(filters.any((f) => f['searchFieldKey'] == 'woStepId'), isTrue);
      expect(filters.any((f) => f['searchFieldKey'] == 'maintenanceTypeId'), isTrue);
      expect(filters.any((f) => f['searchFieldKey'] == 'regrouping1Id'), isTrue); // Area filter
      expect(filters.any((f) => f['searchFieldKey'] == 'recipientName'), isTrue);
      expect(filters.any((f) => f['searchFieldKey'] == 'requesterName'), isTrue);
      expect(filters.any((f) => f['searchFieldKey'] == 'funCodeLevelNiv3Description'), isTrue); // Machine filter
      expect(filters.any((f) => f['searchFieldKey'] == 'executionModeId'), isTrue);
      expect(filters.any((f) => f['searchFieldKey'] == 'worNoSeq'), isTrue); // Recognized as WO sequence number
    });

    test('BammService defaults to open statuses filter (excluding completed, closed, cancelled, declined)', () {
      final service = BammService();
      // When criteria is empty or status is 'All Open'
      final defaultPayload = service.buildFilterPayload(const BammFilterCriteria());
      final filters = defaultPayload['filters'] as List;
      final statusFilter = filters.firstWhere((f) => f['searchFieldKey'] == 'woStatusId');
      final values = (statusFilter['values'] as List).first;
      final listValues = (values['listValues'] as List).map((v) => v['id']).toList();
      // Should include open statuses: 1, 2, 7, 8, 9
      expect(listValues, containsAll([1, 2, 7, 8, 9]));
      expect(listValues, isNot(contains(3))); // Completed excluded
      expect(listValues, isNot(contains(4))); // Cancelled excluded
      expect(listValues, isNot(contains(5))); // Declined excluded
      expect(listValues, isNot(contains(6))); // Closed excluded
    });

    test('BammService standard lookups have pure API options (25 maint types, 3 exec modes, 15 areas)', () async {
      final service = BammService();
      final maint = await service.fetchLookup('GetMaintenanceType');
      expect(maint.length, 25);

      final exec = await service.fetchLookup('GetExecutionMode');
      expect(exec.length, 3);
      expect(exec.map((e) => e.description), containsAll(['Down', 'Limping', 'Running']));

      final areas = await service.fetchLookup('GetGrouping1');
      expect(areas.length, 15);
      expect(areas.map((a) => a.description), containsAll(['100', '200', 'Carts', 'Cell 1', 'Mobile Power']));
    });

    test('Zero dummy data guarantee: offline returns empty list when no cache', () async {
      final service = BammService();
      // forceOffline with an empty/unseeded state
      final orders = await service.fetchWorkOrders(forceOffline: true);
      // Must be empty list, NOT synthetic or dummy data
      expect(orders, isEmpty);
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
