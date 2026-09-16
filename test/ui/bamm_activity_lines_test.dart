// Tests for BAMM work order activity lines (WO_DETAIL):
// 1. Activity lines render from a fake DTO in BammDetailDialog.
// 2. Empty state renders when no activity lines exist.
// 3. The "Add Line" sheet builds the right payload and re-reads the updated lines.
// 4. Failures surface honestly (exception in addActivityLine or added == false).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/schema/lookups.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/providers/bamm_provider.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/services/bamm_adapter.dart';
import 'package:jokarz_engineering/services/bamm_service.dart';
import 'package:jokarz_engineering/services/storage_service.dart';
import 'package:jokarz_engineering/ui/widgets/bamm_detail_dialog.dart';

import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/models/filament_profile.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/inbox_item.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/models/project_template.dart';
import 'package:jokarz_engineering/models/activity_log.dart';
import 'package:jokarz_engineering/models/downtime_event.dart';

class _FakeStorageService extends StorageService {
  @override
  Future<Map<String, dynamic>> loadData() async => {
        'projects': <Project>[],
        'voiceNotes': <VoiceNote>[],
        'filaments': <FilamentProfile>[],
        'standaloneOrders': <StandaloneOrder>[],
        'inboxItems': <InboxItem>[],
        'vendors': <Vendor>[],
        'customTemplates': <ProjectTemplate>[],
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

class _FakeLookupsClient extends BammLookupsClient {
  _FakeLookupsClient()
      : super(
          BammHttpTransport(const BammConfig(usercode: 'mock')),
          const BammConfig(usercode: 'mock'),
        );

  @override
  Future<LookupResult> activities({
    String? stepId,
    String? assetId,
    String? componentTypeId,
  }) async {
    return const LookupResult(
      items: [
        LookupOption(id: '10', label: 'Mechanical Inspection', code: 'MECH', inactive: false),
        LookupOption(id: '11', label: 'Electrical Check', code: 'ELEC', inactive: false),
      ],
      total: 2,
    );
  }

  @override
  Future<LookupResult> subActivities({
    required String activityId,
    String? assetId,
    String? componentTypeId,
  }) async {
    return const LookupResult(
      items: [
        LookupOption(id: '20', label: 'Valve Check', code: 'VALVE', inactive: false),
        LookupOption(id: '21', label: 'Filter Replacement', code: 'FLTR', inactive: false),
      ],
      total: 2,
    );
  }
}

class _FakeBammService extends BammService {
  final BammLookupsClient _fakeLookups = _FakeLookupsClient();

  @override
  BammLookupsClient get lookups => _fakeLookups;
}

Map<String, dynamic> _makeWorkOrderDto({
  int id = 190022,
  String noSeq = '190022',
  List<Map<String, dynamic>> activityLines = const [],
}) {
  return {
    'typeName': 'Cogep.BusinessLogic.WORK_ORDER, Cogep.BusinessLogic',
    'properties': [
      {'name': 'WOR_ID', 'value': '$id', 'type': 4},
      {'name': 'WOR_NO_SEQ', 'value': noSeq, 'type': 6},
      {'name': 'WOR_DESCR', 'value': 'Valve replacement', 'type': 9},
      {'name': 'WOR_STATUS_DESC', 'value': 'Approved', 'type': 15},
      {'name': 'WOR_STEP_DESC', 'value': 'Awaiting Parts', 'type': 15},
      {'name': 'WOR_RESPONSIBLE_NAME', 'value': 'Dave M', 'type': 15},
      {'name': 'WSP_ID', 'value': '1', 'type': 4},
      {'name': 'FUN_ID', 'value': '700010290', 'type': 4},
    ],
    'childSets': [
      {
        'originProperty': 'WO_DETAIL',
        'items': activityLines.map((line) => {
          'typeName': 'Cogep.BusinessLogic.WO_DETAIL, Cogep.BusinessLogic',
          'properties': [
            {'name': 'WOD_ID', 'value': line['id'] ?? '101', 'type': 4},
            {'name': 'WOD_DESCR', 'value': line['description'] ?? '', 'type': 9},
            {'name': 'ACY_ID', 'value': line['activityId'] ?? '10', 'type': 4},
            {'name': 'SAC_ID', 'value': line['subActivityId'] ?? '20', 'type': 4},
            if (line['hours'] != null)
              {'name': 'WOD_ACT_LINE_HOUR_NB', 'value': '${line['hours']}', 'type': 3},
            if (line['memo'] != null)
              {'name': 'WOD_MEMO', 'value': line['memo'], 'type': 9},
          ],
        }).toList(),
      },
    ],
  };
}

class _ActivityLinesBammNotifier extends BammNotifier {
  final BammWorkOrder initialWo;
  final bool failWithException;
  final bool reportNotAdded;
  Map<String, dynamic>? capturedPayload;

  _ActivityLinesBammNotifier(
    this.initialWo, {
    this.failWithException = false,
    this.reportNotAdded = false,
  }) : super(BammService()) {
    state = BammState(workOrders: [initialWo]);
  }

  @override
  Future<void> init() async {}

  @override
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async =>
      state.workOrders.where((w) => w.worId == worId).firstOrNull;

  @override
  Future<BammAddActivityLineOutcome> addActivityLine({
    required int worId,
    required String activityId,
    required String subActivityId,
    String? description,
    double? hours,
    String? memo,
  }) async {
    capturedPayload = {
      'worId': worId,
      'activityId': activityId,
      'subActivityId': subActivityId,
      'description': description,
      'hours': hours,
      'memo': memo,
    };

    if (failWithException) {
      throw Exception('Server unreachable');
    }

    if (reportNotAdded) {
      return BammAddActivityLineOutcome(workOrder: initialWo, added: false);
    }

    // Append new line to initial rawDto
    final raw = initialWo.rawDto!;
    final childSets = (raw['childSets'] as List<dynamic>?) ?? [];
    final existingLines = <Map<String, dynamic>>[];
    for (final cs in childSets) {
      if (cs is Map && cs['originProperty'] == 'WO_DETAIL') {
        final items = (cs['items'] as List<dynamic>?) ?? [];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final props = (item['properties'] as List<dynamic>?) ?? [];
            String val(String name) {
              for (final p in props) {
                if (p is Map && p['name'] == name) return p['value']?.toString() ?? '';
              }
              return '';
            }
            existingLines.add({
              'id': val('WOD_ID'),
              'description': val('WOD_DESCR'),
              'activityId': val('ACY_ID'),
              'subActivityId': val('SAC_ID'),
              'hours': double.tryParse(val('WOD_ACT_LINE_HOUR_NB')),
              'memo': val('WOD_MEMO'),
            });
          }
        }
      }
    }

    existingLines.add({
      'id': '${100 + existingLines.length + 1}',
      'description': description ?? '',
      'activityId': activityId,
      'subActivityId': subActivityId,
      'hours': hours,
      'memo': memo ?? '',
    });

    final updatedDto = _makeWorkOrderDto(
      id: worId,
      noSeq: initialWo.worNoSeq,
      activityLines: existingLines,
    );
    final updatedWo = bammWorkOrderFromModel(updatedDto);
    return BammAddActivityLineOutcome(workOrder: updatedWo, added: true);
  }
}

void main() {
  setUp(() {});

  Widget buildDialogApp({
    required BammWorkOrder workOrder,
    required BammNotifier notifier,
    BammService? service,
  }) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(_FakeStorageService()),
        bammServiceProvider.overrideWithValue(service ?? _FakeBammService()),
        bammProvider.overrideWith((ref) => notifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: BammDetailDialog(workOrder: workOrder),
        ),
      ),
    );
  }

  testWidgets('activity lines render from a fake DTO in BammDetailDialog', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final dto = _makeWorkOrderDto(
      id: 190022,
      noSeq: '190022',
      activityLines: [
        {
          'id': '101',
          'description': 'Inspect hydraulic valve pressure',
          'activityId': '10',
          'subActivityId': '20',
          'hours': 2.5,
          'memo': 'Pressure nominal',
        },
        {
          'id': '102',
          'description': 'Replace filter cartridge',
          'activityId': '11',
          'subActivityId': '21',
          'hours': 1.0,
          'memo': 'Done',
        },
      ],
    );
    final wo = bammWorkOrderFromModel(dto);
    final notifier = _ActivityLinesBammNotifier(wo);

    await tester.pumpWidget(buildDialogApp(workOrder: wo, notifier: notifier));
    await tester.pumpAndSettle();

    // Verify activity lines header and items rendered
    expect(find.text('Activity Lines:'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Card),
        matching: find.text('Inspect hydraulic valve pressure'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Activity 10 - Sub-activity 20 - 2.5h'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Card),
        matching: find.text('Replace filter cartridge'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Activity 11 - Sub-activity 21 - 1.0h'), findsOneWidget);
    expect(find.text('No activity lines yet.'), findsNothing);
  });

  testWidgets('empty state renders when work order has no activity lines in DTO', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final dto = _makeWorkOrderDto(id: 190022, noSeq: '190022', activityLines: []);
    final wo = bammWorkOrderFromModel(dto);
    final notifier = _ActivityLinesBammNotifier(wo);

    await tester.pumpWidget(buildDialogApp(workOrder: wo, notifier: notifier));
    await tester.pumpAndSettle();

    expect(find.text('Activity Lines:'), findsOneWidget);
    expect(find.text('No activity lines yet.'), findsOneWidget);
  });

  testWidgets('the add sheet builds the right payload and re-reads after save', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final dto = _makeWorkOrderDto(id: 190022, noSeq: '190022', activityLines: []);
    final wo = bammWorkOrderFromModel(dto);
    final notifier = _ActivityLinesBammNotifier(wo);

    await tester.pumpWidget(buildDialogApp(workOrder: wo, notifier: notifier));
    await tester.pumpAndSettle();

    // Initial state: empty
    expect(find.text('No activity lines yet.'), findsOneWidget);

    // Open add activity line sheet
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Line'));
    await tester.pumpAndSettle();

    expect(find.text('Add activity line'), findsOneWidget);

    // Pick activity: tap 'Change' next to 'Activity *'
    final activityRow = find.ancestor(of: find.text('Activity *'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: activityRow, matching: find.text('Change')));
    await tester.pumpAndSettle();
    expect(find.text('Mechanical Inspection'), findsOneWidget);
    await tester.tap(find.text('Mechanical Inspection'));
    await tester.pumpAndSettle();

    // Pick sub-activity: tap 'Change' next to 'Sub-activity *'
    final subActivityRow = find.ancestor(of: find.text('Sub-activity *'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: subActivityRow, matching: find.text('Change')));
    await tester.pumpAndSettle();
    expect(find.text('Valve Check'), findsOneWidget);
    await tester.tap(find.text('Valve Check'));
    await tester.pumpAndSettle();

    // Fill in Description, Hours, Memo
    await tester.enterText(find.widgetWithText(TextField, 'Description'), 'Checked seal and flushed line');
    await tester.enterText(find.widgetWithText(TextField, 'Hours'), '1.75');
    await tester.enterText(find.widgetWithText(TextField, 'Memo'), 'Replaced O-ring');
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add line'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify payload captured by notifier
    expect(notifier.capturedPayload, isNotNull);
    expect(notifier.capturedPayload!['worId'], 190022);
    expect(notifier.capturedPayload!['activityId'], '10');
    expect(notifier.capturedPayload!['subActivityId'], '20');
    expect(notifier.capturedPayload!['description'], 'Checked seal and flushed line');
    expect(notifier.capturedPayload!['hours'], 1.75);
    expect(notifier.capturedPayload!['memo'], 'Replaced O-ring');

    // The dialog should re-read and render the new line. Scope the finder to the line's own
    // ListTile: the description legitimately appears inside the card, and the add sheet's TextField
    // (still finishing its exit animation) would otherwise also match a bare find.text().
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Checked seal and flushed line'),
      ),
      findsOneWidget,
      reason: 'the re-read activity line should render exactly once in the lines list',
    );
    expect(find.textContaining('Activity 10 - Sub-activity 20 - 1.75h'), findsOneWidget);
    expect(find.text('No activity lines yet.'), findsNothing);
    expect(find.text('Activity line added'), findsOneWidget);
  });

  testWidgets('failures surface: network exception shows error snackbar on sheet', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final dto = _makeWorkOrderDto(id: 190022, noSeq: '190022', activityLines: []);
    final wo = bammWorkOrderFromModel(dto);
    final notifier = _ActivityLinesBammNotifier(wo, failWithException: true);

    await tester.pumpWidget(buildDialogApp(workOrder: wo, notifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Line'));
    await tester.pumpAndSettle();

    // Pick activity & sub-activity to enable submit button
    final activityRow = find.ancestor(of: find.text('Activity *'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: activityRow, matching: find.text('Change')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mechanical Inspection'));
    await tester.pumpAndSettle();

    final subActivityRow = find.ancestor(of: find.text('Sub-activity *'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: subActivityRow, matching: find.text('Change')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valve Check'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add line'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to add line: Exception: Server unreachable'), findsOneWidget);
  });

  testWidgets('failures surface: server returned added == false surfaces nothing changed warning', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final dto = _makeWorkOrderDto(id: 190022, noSeq: '190022', activityLines: []);
    final wo = bammWorkOrderFromModel(dto);
    final notifier = _ActivityLinesBammNotifier(wo, reportNotAdded: true);

    await tester.pumpWidget(buildDialogApp(workOrder: wo, notifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Line'));
    await tester.pumpAndSettle();

    // Pick activity & sub-activity to enable submit button
    final activityRow2 = find.ancestor(of: find.text('Activity *'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: activityRow2, matching: find.text('Change')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mechanical Inspection'));
    await tester.pumpAndSettle();

    final subActivityRow2 = find.ancestor(of: find.text('Sub-activity *'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: subActivityRow2, matching: find.text('Change')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valve Check'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add line'));
    await tester.pumpAndSettle();

    expect(find.text('BAMM did not add the line - nothing changed'), findsOneWidget);
  });
}
