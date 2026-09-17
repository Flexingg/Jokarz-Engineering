// Item 5 (status): the detail dialog's Status picker must (a) fetch its
// options from the live GetWorkOrderStatus lookup, not a hardcoded list, (b)
// require explicit confirmation before accepting a closing-type status
// (Closed/Completed/Cancelled) and never send one without that confirmation,
// and (c) surface BAMM's own error message verbatim, not a generic failure,
// when the server rejects a status change.
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

const _fakeConfig = BammConfig(origin: 'http://fake-bamm.test', usercode: 'test-user');

/// Live GetWorkOrderStatus options - one ordinary status, one closing-type
/// status (`6` = Closed, per `~/repos/BAMM/docs/11-field-inventory.md`).
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

  // The other pickers' lookups aren't exercised by these tests but must not
  // throw if the dialog's background resolution reaches them.
  @override
  Future<LookupResult> responsible({String? search}) async => const LookupResult(items: [], total: 0);
  @override
  Future<LookupResult> categories() async => const LookupResult(items: [], total: 0);
  @override
  Future<LookupResult> skills() async => const LookupResult(items: [], total: 0);
  @override
  Future<LookupResult> classificationTables() async => const LookupResult(items: [], total: 0);
  @override
  Future<LookupResult> crewShifts() async => const LookupResult(items: [], total: 0);
  @override
  Future<LookupResult> steps() async => const LookupResult(items: [], total: 0);
  @override
  Future<LookupResult> maintenanceTypes() async => const LookupResult(items: [], total: 0);
  @override
  Future<LookupResult> executionModes() async => const LookupResult(items: [], total: 0);
}

class _FakeBammServiceWithLookups extends BammService {
  @override
  BammLookupsClient get lookups => _FakeLookupsClient();
}

BammWorkOrder _testWorkOrder() => BammWorkOrder(
      worId: 190022,
      worNoSeq: '190022',
      description: 'Hydraulic power unit valve replacement',
      status: 'Registered',
      statusId: 8,
    );

/// Captures exactly what [updateWorkOrder] was called with (in particular
/// `statusId`), and can be told to throw - to prove the dialog surfaces a
/// server rejection's message verbatim rather than a generic failure.
class _CapturingBammNotifier extends BammNotifier {
  final BammWorkOrder _detail;
  String? capturedStatusId;
  Object? throwOnSave;

  _CapturingBammNotifier(this._detail) : super(BammService()) {
    state = BammState(workOrders: [_detail]);
  }

  @override
  Future<void> init() async {}

  @override
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async => _detail;

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
    capturedStatusId = statusId;
    if (throwOnSave != null) throw throwOnSave!;
    return BammUpdateOutcome(
      workOrder: _detail.copyWith(description: description),
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

Future<void> _openEditMode(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.tap(find.byTooltip('Edit Work Order'));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picking a non-closing status needs no confirmation and is sent on save', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final wo = _testWorkOrder();
    final notifier = _CapturingBammNotifier(wo);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(_FakeStorageService()),
          bammServiceProvider.overrideWithValue(_FakeBammServiceWithLookups()),
          bammProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
      ),
    );
    await _openEditMode(tester);

    // Open the Status picker and choose the non-closing option.
    await tester.ensureVisible(find.widgetWithText(Row, 'Status').first);
    final statusChange = find.widgetWithText(TextButton, 'Change').at(0);
    await tester.tap(statusChange);
    await tester.pumpAndSettle();
    expect(find.text('Scheduled'), findsOneWidget);
    await tester.tap(find.text('Scheduled'));
    await tester.pumpAndSettle();

    // No confirmation dialog for a non-closing status.
    expect(find.text('Confirm status change'), findsNothing);
    expect(find.text('Scheduled'), findsOneWidget, reason: 'picker row should now show the chosen status');

    await tester.ensureVisible(find.text('Save to BAMM'));
    await tester.tap(find.text('Save to BAMM'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(notifier.capturedStatusId, '2');
  });

  testWidgets('picking a closing status requires confirmation and is discarded if cancelled', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final wo = _testWorkOrder();
    final notifier = _CapturingBammNotifier(wo);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(_FakeStorageService()),
          bammServiceProvider.overrideWithValue(_FakeBammServiceWithLookups()),
          bammProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
      ),
    );
    await _openEditMode(tester);

    await tester.ensureVisible(find.widgetWithText(Row, 'Status').first);
    final statusChange = find.widgetWithText(TextButton, 'Change').at(0);
    await tester.tap(statusChange);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Closed'));
    await tester.pumpAndSettle();

    // Closing-type status -> confirmation required.
    expect(find.text('Confirm status change'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();

    // Declined - the picker row must NOT show "Closed".
    expect(find.text('Closed'), findsNothing);

    await tester.ensureVisible(find.text('Save to BAMM'));
    await tester.tap(find.text('Save to BAMM'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Never sent - statusId must be null since the change was discarded.
    expect(notifier.capturedStatusId, isNull);
  });

  testWidgets('confirming a closing status sends it on save', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final wo = _testWorkOrder();
    final notifier = _CapturingBammNotifier(wo);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(_FakeStorageService()),
          bammServiceProvider.overrideWithValue(_FakeBammServiceWithLookups()),
          bammProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
      ),
    );
    await _openEditMode(tester);

    await tester.ensureVisible(find.widgetWithText(Row, 'Status').first);
    final statusChange = find.widgetWithText(TextButton, 'Change').at(0);
    await tester.tap(statusChange);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Closed'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm status change'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Closed'), findsOneWidget, reason: 'confirmed selection should now show in the picker row');

    await tester.ensureVisible(find.text('Save to BAMM'));
    await tester.tap(find.text('Save to BAMM'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(notifier.capturedStatusId, '6');
  });

  testWidgets('a BAMM rejection surfaces the server message verbatim, not a generic failure', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final wo = _testWorkOrder();
    final notifier = _CapturingBammNotifier(wo)
      ..throwOnSave = Exception('BAMM: work order 190022 cannot transition from Registered to Closed');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(_FakeStorageService()),
          bammServiceProvider.overrideWithValue(_FakeBammServiceWithLookups()),
          bammProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
      ),
    );
    await _openEditMode(tester);

    await tester.ensureVisible(find.text('Save to BAMM'));
    await tester.tap(find.text('Save to BAMM'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('cannot transition from Registered to Closed'),
      findsOneWidget,
      reason: 'the server message must reach the user verbatim, not a generic "failed to update" wrapper',
    );
  });
}
