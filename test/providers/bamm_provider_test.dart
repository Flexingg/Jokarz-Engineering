// Provider-level coverage for the BAMM save/refresh regressions:
// - tapping a row after an edit must not clobber list-only display fields
//   (the exact regression the user hit - see bug report Bug 1),
// - a successful save re-runs the list query (Bug 1),
// - a superseded list response must be dropped, not win a race (Bug 2).
//
// Fakes are built at the BammService layer (never network/path_provider),
// so BammNotifier's own logic under test (merge, resolve, request-id guard)
// runs for real - the same pattern as bamm_activity_lines_test.dart.
import 'package:flutter_test/flutter_test.dart';

import 'package:jokarz_engineering/bamm/mutations/fields.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/providers/bamm_provider.dart';
import 'package:jokarz_engineering/services/bamm_service.dart';

class _TestNotifier extends BammNotifier {
  _TestNotifier(super.service, BammState seed) {
    state = seed;
  }

  @override
  Future<void> init() async {}
}

BammWorkOrder _listRow() => BammWorkOrder(
      worId: 700203512,
      worNoSeq: 'WO-143608.4',
      description: 'LR repair request',
      status: 'Registered',
      statusId: 8,
      step: 'Emergency',
      stepId: 3,
      area: 'Cell 1',
      machine: 'Filler A',
      responsible: 'Doe, Jane',
      requester: 'Sample, Person',
      priority: '6',
    );

class _DetailFakeService extends BammService {
  final BammWorkOrder detail;
  _DetailFakeService(this.detail);

  @override
  Future<BammWorkOrder?> fetchWorkOrderDetail(int worId) async => detail;
}

class _UpdateFakeService extends BammService {
  int listQueryCount = 0;
  BammFieldReadBackStatus fieldStatus = BammFieldReadBackStatus.saved;

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
    return BammUpdateOutcome(
      // Simulates the raw, unmerged/unresolved read-back: blank labels,
      // bare WOR_NO, no list-only display columns - exactly what
      // bammWorkOrderFromModel produces for a real GetById.
      workOrder: BammWorkOrder(
        worId: worId,
        worNoSeq: '143608',
        description: description,
        status: '',
        statusId: 8,
        step: '',
        stepId: 3,
      ),
      writeResult: BammWriteResult(
        workOrderId: '$worId',
        fields: [
          BammFieldReadBack(
            field: BammWritableField.description,
            sentValue: description,
            returnedValue: description,
            status: fieldStatus,
          ),
        ],
      ),
    );
  }

  @override
  Future<List<BammWorkOrder>> fetchWorkOrders({
    BammFilterCriteria? criteria,
    Map<String, dynamic>? customPayload,
    bool forceOffline = false,
    List<BammLookupItem> statusLookups = const [],
    List<BammLookupItem> stepLookups = const [],
  }) async {
    listQueryCount++;
    return const [];
  }
}

/// Each entry in [responses] answers one call to `fetchWorkOrders`, in call
/// order - used to make an OLDER request resolve AFTER a NEWER one, so the
/// request-id guard has something real to drop.
class _SequencedFakeService extends BammService {
  final List<Future<List<BammWorkOrder>> Function()> responses;
  int callIndex = 0;
  _SequencedFakeService(this.responses);

  @override
  Future<List<BammWorkOrder>> fetchWorkOrders({
    BammFilterCriteria? criteria,
    Map<String, dynamic>? customPayload,
    bool forceOffline = false,
    List<BammLookupItem> statusLookups = const [],
    List<BammLookupItem> stepLookups = const [],
  }) {
    final fn = responses[callIndex];
    callIndex++;
    return fn();
  }
}

void main() {
  group('BammNotifier.fetchWorkOrderDetail - detail merge', () {
    test('tapping a row after an edit keeps list-only fields and resolves real labels', () async {
      final listRow = _listRow();
      // What a raw GetById read-back actually looks like: blank labels
      // (GetById never carries WOR_STATUS_DESC/WOR_STEP_DESC), a bare WO
      // number, and none of the list-only display columns.
      final rawDetail = BammWorkOrder(
        worId: 700203512,
        worNoSeq: '143608',
        description: 'LR repair request (edited)',
        status: '',
        statusId: 8,
        step: '',
        stepId: 3,
        priority: '6',
      );

      final notifier = _TestNotifier(
        _DetailFakeService(rawDetail),
        BammState(
          workOrders: [listRow],
          statusLookups: const [BammLookupItem(id: 8, description: 'Registered')],
          stepLookups: const [BammLookupItem(id: 3, description: 'Emergency')],
        ),
      );

      final merged = await notifier.fetchWorkOrderDetail(listRow.worId);

      expect(merged, isNotNull);
      expect(merged!.worNoSeq, 'WO-143608.4', reason: 'must keep the list row\'s formatted WO#');
      expect(merged.status, 'Registered', reason: 'resolved from the live lookup, not a hardcoded default');
      expect(merged.step, 'Emergency', reason: 'resolved from the live lookup, not a hardcoded default');
      expect(merged.priority, '6');
      expect(merged.area, 'Cell 1', reason: 'GetById never carries area - must survive from the list row');
      expect(merged.machine, 'Filler A');
      expect(merged.responsible, 'Doe, Jane');
      expect(merged.requester, 'Sample, Person');
      expect(merged.description, 'LR repair request (edited)', reason: 'detail genuinely carries this - must patch through');

      // The row actually stored in state is the merged version, not the raw detail.
      final stored = notifier.state.workOrders.firstWhere((w) => w.worId == listRow.worId);
      expect(stored.worNoSeq, 'WO-143608.4');
      expect(stored.status, 'Registered');
    });

    test('an id with no lookup match shows the raw id, never a wrong hardcoded label', () async {
      final listRow = _listRow();
      final rawDetail = BammWorkOrder(worId: 700203512, worNoSeq: '143608', description: '', status: '', statusId: 99, step: '', stepId: 42);
      final notifier = _TestNotifier(
        _DetailFakeService(rawDetail),
        BammState(workOrders: [listRow], statusLookups: const [], stepLookups: const []),
      );

      final merged = await notifier.fetchWorkOrderDetail(listRow.worId);

      expect(merged!.status, '99');
      expect(merged.step, '42');
    });
  });

  group('BammNotifier.updateWorkOrder - re-query and merge', () {
    test('a successful save re-runs the list query', () async {
      final service = _UpdateFakeService();
      final notifier = _TestNotifier(service, BammState(workOrders: [_listRow()]));

      await notifier.updateWorkOrder(worId: 700203512, description: 'Updated description');

      expect(service.listQueryCount, greaterThanOrEqualTo(1), reason: 'refreshWorkOrders must run after a save');
    });

    test('the returned outcome and stored row are merged - list-only fields and labels survive', () async {
      final service = _UpdateFakeService();
      final listRow = _listRow();
      final notifier = _TestNotifier(
        service,
        BammState(
          workOrders: [listRow],
          statusLookups: const [BammLookupItem(id: 8, description: 'Registered')],
          stepLookups: const [BammLookupItem(id: 3, description: 'Emergency')],
        ),
      );

      final outcome = await notifier.updateWorkOrder(worId: 700203512, description: 'Updated description');

      expect(outcome.workOrder.worNoSeq, 'WO-143608.4');
      expect(outcome.workOrder.status, 'Registered');
      expect(outcome.workOrder.step, 'Emergency');
      expect(outcome.workOrder.area, 'Cell 1');
      expect(outcome.workOrder.description, 'Updated description');
    });
  });

  group('BammNotifier.refreshWorkOrders - superseded response guard', () {
    test('an older, slower response is dropped when a newer one already resolved', () async {
      final older = [BammWorkOrder(worId: 1, worNoSeq: '1', description: 'old')];
      final newer = [BammWorkOrder(worId: 2, worNoSeq: '2', description: 'new')];
      final service = _SequencedFakeService([
        () => Future.delayed(const Duration(milliseconds: 30), () => older),
        () => Future.value(newer),
      ]);
      final notifier = _TestNotifier(service, const BammState());

      final firstCall = notifier.refreshWorkOrders(); // slow, fires first
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final secondCall = notifier.refreshWorkOrders(); // fast, fires second, resolves first
      await Future.wait([firstCall, secondCall]);

      expect(notifier.state.workOrders, newer, reason: 'the newer request must win even though the older one resolves later');
    });
  });
}
