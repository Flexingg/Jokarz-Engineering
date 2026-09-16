import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/mutations/fields.dart';
import 'package:jokarz_engineering/bamm/mutations/model_ops.dart';
import 'package:jokarz_engineering/bamm/mutations/writer.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';

/// Exercises the real write path over HTTP against the live `bamm-mock`
/// systemd service (`~/repos/BAMM/tools/mock_bamm.py`) on 127.0.0.1:5099 -
/// the counterpart to `live_mock_integration_test.dart` (reads) for
/// `GetNew`, `RecordLocking/Lock`, `Save` and the write -> read-back round
/// trip. The mock persists what it is told to save (keyed by work order id)
/// and returns it on a subsequent read, so this is a real round trip, not a
/// mocked one.
///
/// Skipped cleanly (not failed) when the mock is unreachable.
const _mockOrigin = 'http://127.0.0.1:5099';

const _config = BammConfig(
  origin: _mockOrigin,
  usercode: 'mock-test-user',
  companyId: 3,
  spwId: 700000027,
);

Future<bool> _mockReachable() async {
  try {
    final socket = await Socket.connect('127.0.0.1', 5099, timeout: const Duration(milliseconds: 800));
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

/// Forgets everything a previous run wrote, so each test starts from the
/// canned baseline fixture (see `tools/mock_bamm.py`'s `/__reset`).
Future<void> _resetMock() async {
  await http.get(Uri.parse('$_mockOrigin/__reset'));
}

void main() {
  group('live mock write path (127.0.0.1:5099)', () {
    late bool reachable;

    setUpAll(() async {
      reachable = await _mockReachable();
    });

    setUp(() async {
      if (reachable) await _resetMock();
    });

    test('GetNew against the real endpoint returns a fresh, unsaved model', () async {
      if (!reachable) {
        markTestSkipped('bamm-mock is not reachable on 127.0.0.1:5099');
        return;
      }
      final transport = BammHttpTransport(_config);
      addTearDown(transport.close);
      final writer = BammWorkOrderWriter(transport, _config);

      final model = await writer.getNew();

      expect(model['typeName'], contains('WORK_ORDER'));
      expect(propertyValue(model, 'WOR_ID'), '0');
    });

    test('the record lock endpoint responds over real HTTP', () async {
      if (!reachable) {
        markTestSkipped('bamm-mock is not reachable on 127.0.0.1:5099');
        return;
      }
      final transport = BammHttpTransport(_config);
      addTearDown(transport.close);
      final writer = BammWorkOrderWriter(transport, _config);

      await expectLater(writer.lockWorkOrder(700555001), completes);
    });

    test('a full whitelisted write -> Save -> read-back round trip reports success', () async {
      if (!reachable) {
        markTestSkipped('bamm-mock is not reachable on 127.0.0.1:5099');
        return;
      }
      final transport = BammHttpTransport(_config);
      addTearDown(transport.close);
      final fieldWriter = WhitelistedFieldWriter(BammWorkOrderWriter(transport, _config));

      final result = await fieldWriter.write(700555001, const [
        BammFieldEdit(BammWritableField.description, 'Live mock round trip'),
        BammFieldEdit(BammWritableField.responsible, '4242'),
        BammFieldEdit(BammWritableField.requiredDate, '2026-05-01'),
      ]);

      expect(
        result.isSuccess,
        isTrue,
        reason: result.fields.map((f) => f.describe()).join('; '),
      );
      expect(result.summary, 'success');
    });

    test('a value written in one call is still there on an independent later read', () async {
      if (!reachable) {
        markTestSkipped('bamm-mock is not reachable on 127.0.0.1:5099');
        return;
      }
      final transport = BammHttpTransport(_config);
      addTearDown(transport.close);
      final writer = BammWorkOrderWriter(transport, _config);
      final fieldWriter = WhitelistedFieldWriter(writer);

      await fieldWriter.write(700555002, const [
        BammFieldEdit(BammWritableField.workDone, 'Inspected and lubricated'),
      ]);

      final reread = await writer.getById(700555002);
      expect(propertyValue(reread, 'WOR_TASK'), 'Inspected and lubricated');
    });

    test('the date fields round-trip as the same UTC-pinned epoch millis they were sent as', () async {
      if (!reachable) {
        markTestSkipped('bamm-mock is not reachable on 127.0.0.1:5099');
        return;
      }
      final transport = BammHttpTransport(_config);
      addTearDown(transport.close);
      final writer = BammWorkOrderWriter(transport, _config);
      final fieldWriter = WhitelistedFieldWriter(writer);

      await fieldWriter.write(700555003, const [
        BammFieldEdit(BammWritableField.installStart, '2026-03-08'),
        BammFieldEdit(BammWritableField.installEnd, '2026-03-09'),
      ]);

      final reread = await writer.getById(700555003);
      final start = int.parse(propertyValue(reread, 'WOR_PLAN_DATE')!);
      final end = int.parse(propertyValue(reread, 'WOR_END_PLAN_DATE')!);
      expect(end - start, Duration.millisecondsPerDay);
    });
  });
}
