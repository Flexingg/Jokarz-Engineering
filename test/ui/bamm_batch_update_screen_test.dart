// Coverage for the batch update screen: ticking/unticking selection,
// select-all/deselect-all, the applied-change payload sent to
// BammService.updateWorkOrder (proving the closed write whitelist is
// respected - only status/step/workDone/description are ever sent, never
// an unrelated field), the closing-status confirmation gate applied once
// for the whole batch, and honest per-work-order failure reporting.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/mutations/fields.dart';
import 'package:jokarz_engineering/bamm/schema/lookups.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/providers/bamm_provider.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/services/bamm_service.dart';
import 'package:jokarz_engineering/services/storage_service.dart';
import 'package:jokarz_engineering/ui/screens/bamm_batch_update_screen.dart';

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

const _fakeConfig = BammConfig(origin: 'http://fake-bamm.test', usercode: 'test-user');

/// Live GetWorkOrderStatus/GetWorkOrderStep options - '2' Scheduled
/// (non-closing) and '6' Closed (closing, per
/// `~/repos/BAMM/docs/11-field-inventory.md`), matching
/// `bamm_status_field_test.dart`'s fixture.
class _FakeLookupsClient extends BammLookupsClient {
  _FakeLookupsClient() : super(BammHttpTransport(_fakeConfig), _fakeConfig);

  @override
  Future<LookupResult> status() async => const LookupResult(
        items: [
          LookupOption(id: '2', label: 'Scheduled', code: '', inactive: false),
          LookupOption(id: '6', label: 'Closed', code: '', inactive: false),
        ],
        total: 2,
      );

  @override
  Future<LookupResult> steps() async => const LookupResult(
        items: [LookupOption(id: '4', label: 'Corrective', code: '', inactive: false)],
        total: 1,
      );
}

class _FakeBammServiceWithLookups extends BammService {
  @override
  BammLookupsClient get lookups => _FakeLookupsClient();
}

/// One recorded call to `updateWorkOrder`, capturing every named parameter
/// so a test can assert the closed-whitelist guard: only status/step/
/// workDone/description may ever be non-null from this screen.
class _RecordedUpdateCall {
  final int worId;
  final String description;
  final String? workDone;
  final String? responsible;
  final String? stepId;
  final String? maintenanceTypeId;
  final String? executionModeId;
  final String? assetId;
  final double? estimatedLaborHours;
  final String? statusId;

  const _RecordedUpdateCall({
    required this.worId,
    required this.description,
    this.workDone,
    this.responsible,
    this.stepId,
    this.maintenanceTypeId,
    this.executionModeId,
    this.assetId,
    this.estimatedLaborHours,
    this.statusId,
  });
}

/// Records every `updateWorkOrder` call instead of hitting the network -
/// [throwFor] optionally makes one worId fail, to prove failures are
/// reported honestly rather than swallowed into a blanket success message.
class _RecordingBammService extends BammService {
  final List<_RecordedUpdateCall> calls = [];
  final Set<int> throwFor;
  _RecordingBammService({this.throwFor = const {}});

  @override
  BammLookupsClient get lookups => _FakeLookupsClient();

  @override
  Future<BammUpdateOutcome> updateWorkOrder({
    required int worId,
    required String description,
    String? workDone,
    String? responsible,
    DateTime? requiredDate,
    DateTime? installStart,
    DateTime? installEnd,
    String? classificationId,
    String? skillId,
    String? classificationTableId,
    String? crewShiftId,
    int? requiredEmployees,
    String? stepId,
    String? maintenanceTypeId,
    String? executionModeId,
    double? priorityEm,
    String? assetId,
    double? estimatedLaborHours,
    String? statusId,
  }) async {
    calls.add(_RecordedUpdateCall(
      worId: worId,
      description: description,
      workDone: workDone,
      responsible: responsible,
      stepId: stepId,
      maintenanceTypeId: maintenanceTypeId,
      executionModeId: executionModeId,
      assetId: assetId,
      estimatedLaborHours: estimatedLaborHours,
      statusId: statusId,
    ));
    if (throwFor.contains(worId)) {
      throw Exception('BAMM rejected work order #$worId');
    }
    return BammUpdateOutcome(
      workOrder: BammWorkOrder(worId: worId, worNoSeq: '$worId', description: description),
      writeResult: BammWriteResult(
        workOrderId: '$worId',
        fields: [
          BammFieldReadBack(
            field: BammWritableField.description,
            sentValue: description,
            returnedValue: description,
            status: BammFieldReadBackStatus.saved,
          ),
        ],
      ),
    );
  }
}

class _FakeBammNotifier extends BammNotifier {
  int refreshCalls = 0;
  _FakeBammNotifier(super.service, List<BammWorkOrder> seed) {
    state = BammState(workOrders: seed);
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> refreshWorkOrders() async {
    refreshCalls++;
  }
}

List<BammWorkOrder> _seedRows() => [
      BammWorkOrder(worId: 1, worNoSeq: '185610', description: 'Motor replacement', status: 'Registered', step: 'Emergency'),
      BammWorkOrder(worId: 2, worNoSeq: '185611', description: 'Belt inspection', status: 'Registered', step: 'Normal'),
      BammWorkOrder(worId: 3, worNoSeq: '185612', description: 'Sensor calibration', status: 'Scheduled', step: 'Normal'),
    ];

List<Override> _overrides(BammNotifier notifier) => [
      storageServiceProvider.overrideWithValue(_FakeStorageService()),
      projectProvider.overrideWith((ref) => ProjectNotifier(_FakeStorageService())),
      bammServiceProvider.overrideWithValue(_FakeBammServiceWithLookups()),
      bammProvider.overrideWith((ref) => notifier),
    ];

Future<void> _pump(WidgetTester tester, BammNotifier notifier) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(notifier),
      child: const MaterialApp(home: BammBatchUpdateScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('selection', () {
    testWidgets('ticking and unticking rows updates the Apply button count', (tester) async {
      final notifier = _FakeBammNotifier(_RecordingBammService(), _seedRows());
      await _pump(tester, notifier);

      expect(find.text('Apply to 1 selected'), findsNothing);

      await tester.tap(find.byKey(const Key('batch_row_1')));
      await tester.pump();
      expect(find.text('Apply to 1 selected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('batch_row_2')));
      await tester.pump();
      expect(find.text('Apply to 2 selected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('batch_row_1')));
      await tester.pump();
      expect(find.text('Apply to 1 selected'), findsOneWidget);
    });

    testWidgets('select all / deselect all toggles every row', (tester) async {
      final notifier = _FakeBammNotifier(_RecordingBammService(), _seedRows());
      await _pump(tester, notifier);

      await tester.tap(find.byKey(const Key('batch_select_all')));
      await tester.pump();
      expect(find.text('Apply to 3 selected'), findsOneWidget);
      expect(find.text('Deselect all'), findsOneWidget);

      await tester.tap(find.byKey(const Key('batch_select_all')));
      await tester.pump();
      expect(find.text('Apply to 3 selected'), findsNothing, reason: 'the Apply bar disappears once nothing is selected');
    });
  });

  group('applied change payload (closed whitelist)', () {
    testWidgets('status/step/note apply to every selected row, description preserved per-row, nothing else touched', (tester) async {
      final service = _RecordingBammService();
      final notifier = _FakeBammNotifier(service, _seedRows());
      await _pump(tester, notifier);

      await tester.tap(find.byKey(const Key('batch_row_1')));
      await tester.tap(find.byKey(const Key('batch_row_2')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('batch_apply_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('batch_pick_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scheduled'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('batch_pick_step')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Corrective'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('batch_note_field')), 'Checked during walk-around');
      await tester.tap(find.byKey(const Key('batch_change_apply')));
      await tester.pumpAndSettle();

      expect(service.calls, hasLength(2), reason: 'one updateWorkOrder call per selected row');
      final byId = {for (final c in service.calls) c.worId: c};

      // Closed-whitelist guard: only these four fields may ever be sent from
      // this screen - everything else must stay null.
      for (final call in service.calls) {
        expect(call.statusId, '2');
        expect(call.stepId, '4');
        expect(call.workDone, 'Checked during walk-around');
        expect(call.responsible, isNull);
        expect(call.maintenanceTypeId, isNull);
        expect(call.executionModeId, isNull);
        expect(call.assetId, isNull);
        expect(call.estimatedLaborHours, isNull);
      }
      // Each row's own current description is preserved, not clobbered
      // with a shared value.
      expect(byId[1]!.description, 'Motor replacement');
      expect(byId[2]!.description, 'Belt inspection');

      expect(notifier.refreshCalls, 1, reason: 'exactly one list refresh after the whole batch, not once per row');
    });

    testWidgets('a guard-less send would fail this test: an unselected row must never be updated', (tester) async {
      final service = _RecordingBammService();
      final notifier = _FakeBammNotifier(service, _seedRows());
      await _pump(tester, notifier);

      await tester.tap(find.byKey(const Key('batch_row_1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('batch_apply_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('batch_pick_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scheduled'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('batch_change_apply')));
      await tester.pumpAndSettle();

      expect(service.calls, hasLength(1));
      expect(service.calls.single.worId, 1);
    });
  });

  group('closing status confirmation', () {
    testWidgets('choosing a closing status prompts once for the whole batch, and Cancel sends nothing', (tester) async {
      final service = _RecordingBammService();
      final notifier = _FakeBammNotifier(service, _seedRows());
      await _pump(tester, notifier);

      await tester.tap(find.byKey(const Key('batch_row_1')));
      await tester.tap(find.byKey(const Key('batch_row_2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('batch_apply_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('batch_pick_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Closed'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('batch_change_apply')));
      await tester.pumpAndSettle();

      expect(find.text('Confirm status change'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.calls, isEmpty, reason: 'cancelling the confirmation must send nothing');
    });

    testWidgets('confirming a closing status applies it to every selected row', (tester) async {
      final service = _RecordingBammService();
      final notifier = _FakeBammNotifier(service, _seedRows());
      await _pump(tester, notifier);

      await tester.tap(find.byKey(const Key('batch_row_1')));
      await tester.tap(find.byKey(const Key('batch_row_2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('batch_apply_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('batch_pick_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Closed'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('batch_change_apply')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(service.calls, hasLength(2));
      expect(service.calls.every((c) => c.statusId == '6'), isTrue);
    });
  });

  group('honest failure reporting', () {
    testWidgets('a failure on one of N rows is reported by work-order number, not swallowed', (tester) async {
      final service = _RecordingBammService(throwFor: {2});
      final notifier = _FakeBammNotifier(service, _seedRows());
      await _pump(tester, notifier);

      await tester.tap(find.byKey(const Key('batch_row_1')));
      await tester.tap(find.byKey(const Key('batch_row_2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('batch_apply_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('batch_pick_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scheduled'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('batch_change_apply')));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 updated'), findsOneWidget);
      expect(find.textContaining('#185611: Exception'), findsOneWidget, reason: 'the failing WO number and real error must be named, not hidden');
    });
  });
}
