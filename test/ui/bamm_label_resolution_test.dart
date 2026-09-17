// Item 1: the detail dialog's edit-mode picker rows (Responsible,
// Classification, Required skill, Classification table, Crew/Shift, Step,
// Maintenance type, Machine status) must show the real label resolved from
// the live lookup the app already fetches for that field's picker - never a
// bare numeric id when a label is resolvable, and never a wrong label when
// it is not (id-labelled fallback instead).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/schema/lookups.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/providers/bamm_provider.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/services/bamm_adapter.dart' show bammWorkOrderFromModel, resolveWorkOrderLabels;
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

/// Every lookup method the dialog calls to resolve a picker row's label -
/// canned, in-memory answers, no HTTP transport ever invoked. Classification
/// table (`WG6_ID`) deliberately returns no matching option, to prove the
/// unresolvable-id fallback.
class _FakeLookupsClient extends BammLookupsClient {
  _FakeLookupsClient() : super(BammHttpTransport(_fakeConfig), _fakeConfig);

  @override
  Future<LookupResult> status() async => const LookupResult(items: [], total: 0);

  @override
  Future<LookupResult> responsible({String? search}) async =>
      const LookupResult(items: [LookupOption(id: '55', label: 'Dave M', code: '', inactive: false)], total: 1);

  @override
  Future<LookupResult> categories() async =>
      const LookupResult(items: [LookupOption(id: '4123', label: 'Electrical', code: '', inactive: false)], total: 1);

  @override
  Future<LookupResult> skills() async =>
      const LookupResult(items: [LookupOption(id: '9', label: 'Millwright', code: '', inactive: false)], total: 1);

  @override
  Future<LookupResult> classificationTables() async => const LookupResult(items: [], total: 0);

  @override
  Future<LookupResult> crewShifts() async =>
      const LookupResult(items: [LookupOption(id: '2', label: 'Night Crew', code: '', inactive: false)], total: 1);

  @override
  Future<LookupResult> steps() async =>
      const LookupResult(items: [LookupOption(id: '3', label: 'Emergency', code: '', inactive: false)], total: 1);

  @override
  Future<LookupResult> maintenanceTypes() async => const LookupResult(
        items: [LookupOption(id: '107', label: 'Planned - Corrective Maint.', code: '', inactive: false)],
        total: 1,
      );

  @override
  Future<LookupResult> executionModes() async =>
      const LookupResult(items: [LookupOption(id: '1', label: 'Down', code: '2.00', inactive: false)], total: 1);
}

class _FakeBammServiceWithLookups extends BammService {
  @override
  BammLookupsClient get lookups => _FakeLookupsClient();
}

Map<String, dynamic> _rawDto() => {
      'typeName': 'Cogep.BusinessLogic.WORK_ORDER, Cogep.BusinessLogic',
      'properties': [
        {'name': 'WOR_ID', 'value': '190022', 'type': 3},
        {'name': 'WOR_DESCR', 'value': 'Hydraulic power unit valve replacement', 'type': 9},
        {'name': 'RCP_ID', 'value': '55', 'type': 4},
        {'name': 'CTG_ID', 'value': '4123', 'type': 4},
        {'name': 'SKI_ID', 'value': '9', 'type': 4},
        {'name': 'WG6_ID', 'value': '700000099', 'type': 4}, // unresolvable - no match in _FakeLookupsClient
        {'name': 'WG7_ID', 'value': '2', 'type': 4},
        {'name': 'WSP_ID', 'value': '3', 'type': 4},
        {'name': 'MNT_ID', 'value': '107', 'type': 4},
        {'name': 'EXM_ID', 'value': '1', 'type': 4},
        {'name': 'FUN_ID', 'value': '700012596', 'type': 4},
        {'name': 'WOR_NB_3', 'value': '6.0000000', 'type': 15},
      ],
      'childSets': <dynamic>[],
    };

/// Simulates the real app's flow (`BammNotifier._resolveAndMerge`): the list
/// row already carries the asset's real description
/// (`funCodeLevelNiv3Description`, from `GetListData`, which `GetById` can
/// never carry - see `BammWorkOrder.fromDynamicDto`'s doc comment), and
/// `fetchWorkOrderDetail` merges the freshly-fetched detail onto it so the
/// Machine field shows that real description rather than a bare id. Calls
/// the same real `resolveWorkOrderLabels`/`mergeDetail` the production
/// notifier calls - not a reimplementation of that logic.
class _FakeBammNotifier extends BammNotifier {
  final BammWorkOrder _listRow;
  final Map<String, dynamic> _detailRawDto;
  _FakeBammNotifier(this._listRow, this._detailRawDto) : super(BammService()) {
    state = BammState(workOrders: [_listRow]);
  }

  @override
  Future<void> init() async {}

  @override
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async {
    final detail = bammWorkOrderFromModel(_detailRawDto);
    final resolved = resolveWorkOrderLabels(detail, statusLookups: const [], stepLookups: const []);
    return _listRow.mergeDetail(resolved);
  }
}

void main() {
  testWidgets('every id-only picker field - including asset - renders the real description, and an unresolvable id renders the id-labelled fallback', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final rawDto = _rawDto();
    final listRow = bammWorkOrderFromModel(rawDto).copyWith(machine: 'Press 12', assetId: '700012596');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(_FakeStorageService()),
          bammServiceProvider.overrideWithValue(_FakeBammServiceWithLookups()),
          bammProvider.overrideWith((ref) => _FakeBammNotifier(listRow, rawDto)),
        ],
        child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: listRow))),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Edit Work Order'));
    await tester.pump();
    // Let the parallel Future.wait of lookup fetches resolve.
    await tester.pumpAndSettle();

    expect(find.text('Dave M'), findsOneWidget, reason: 'Responsible (RCP_ID) should show the resolved name');
    expect(find.text('Electrical'), findsOneWidget, reason: 'Classification (CTG_ID)');
    expect(find.text('Millwright'), findsOneWidget, reason: 'Required skill (SKI_ID)');
    expect(find.text('Night Crew'), findsOneWidget, reason: 'Crew/Shift (WG7_ID)');
    expect(find.text('Emergency'), findsOneWidget, reason: 'Step (WSP_ID)');
    expect(find.text('Planned - Corrective Maint.'), findsOneWidget, reason: 'Maintenance type (MNT_ID)');
    expect(find.text('Down'), findsOneWidget, reason: 'Machine status / execution mode (EXM_ID)');
    expect(find.textContaining('Press 12'), findsWidgets, reason: 'Asset/Machine (FUN_ID) should show the real description, not the bare id 700012596');
    expect(find.text('700012596'), findsNothing, reason: 'the bare asset id must never be shown on its own');

    // Classification table (WG6_ID = 700000099) has no match in the fake
    // lookup - must show the id, labelled as such, never a wrong label and
    // never a bare number.
    expect(find.text('id 700000099'), findsOneWidget);
    expect(find.text('700000099'), findsNothing, reason: 'a bare numeric id must never be shown on its own');
  });
}
