// A3: the per-field save verdict must be VISIBLE to the user, not merely
// computed. Drives BammDetailDialog end-to-end through a fake
// BammNotifier.updateWorkOrder that returns a MIXED verdict (one field
// saved, one silently dropped by BAMM) and asserts the rendered SnackBar
// actually shows both outcomes - not just that BammFieldReadBack.describe()
// produces the right string in isolation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jokarz_engineering/bamm/mutations/fields.dart';
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

BammWorkOrder _testWorkOrder() => BammWorkOrder(
      worId: 190022,
      worNoSeq: '190022',
      description: 'Hydraulic power unit valve replacement',
      status: 'Approved',
      step: 'Awaiting Parts',
      responsible: 'Dave M',
    );

/// Simulates a real, honest BAMM save where the server accepted the
/// description but silently dropped the work-done edit - exactly the
/// scenario A3 exists to surface rather than hide behind "success".
class _MixedVerdictBammNotifier extends BammNotifier {
  _MixedVerdictBammNotifier(BammWorkOrder seed) : super(BammService()) {
    state = BammState(workOrders: [seed]);
  }

  @override
  Future<void> init() async {}

  @override
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async =>
      state.workOrders.where((w) => w.worId == worId).firstOrNull;

  @override
  Future<BammUpdateOutcome> updateWorkOrder({
    required int worId,
    required String description,
    String? workDone,
    String? responsible,
    DateTime? requiredDate,
    DateTime? installStart,
    DateTime? installEnd,
  }) async {
    final updated = _testWorkOrder().copyWith(description: description);
    return BammUpdateOutcome(
      workOrder: updated,
      writeResult: BammWriteResult(
        workOrderId: '$worId',
        fields: [
          BammFieldReadBack(
            field: BammWritableField.description,
            sentValue: description,
            returnedValue: description,
            status: BammFieldReadBackStatus.saved,
          ),
          BammFieldReadBack(
            field: BammWritableField.workDone,
            sentValue: workDone ?? '',
            returnedValue: null,
            status: BammFieldReadBackStatus.silentlyDropped,
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('a partial save shows which fields landed and which did not, and never claims success', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final wo = _testWorkOrder();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(_FakeStorageService()),
          bammProvider.overrideWith((ref) => _MixedVerdictBammNotifier(wo)),
        ],
        child: MaterialApp(home: Scaffold(body: BammDetailDialog(workOrder: wo))),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Enter edit mode and save.
    await tester.tap(find.byTooltip('Edit Work Order'));
    await tester.pump();
    await tester.tap(find.text('Save to BAMM'));
    await tester.pump(); // start the save
    await tester.pumpAndSettle();

    // The write is only ever reported honest, never a blanket "success" -
    // BammWriteResult.isSuccess requires every sent field unchanged, and one
    // field here came back null (silently dropped).
    expect(find.textContaining('BAMM save incomplete'), findsOneWidget);
    expect(find.textContaining('WOR_DESCR: saved'), findsOneWidget, reason: 'the field that landed should say so');
    expect(
      find.textContaining('WOR_TASK: silently dropped'),
      findsOneWidget,
      reason: 'the field BAMM did not keep must be visibly reported, not hidden behind a generic success message',
    );
    expect(find.textContaining('BAMM Work Order updated successfully'), findsNothing,
        reason: 'a partial save must never be reported as a plain success');
  });
}
