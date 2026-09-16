import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/mutations/exceptions.dart';
import 'package:jokarz_engineering/bamm/mutations/fields.dart';
import 'package:jokarz_engineering/bamm/mutations/model_ops.dart';
import 'package:jokarz_engineering/bamm/mutations/writer.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';

const _config = BammConfig(origin: 'http://fake-bamm.test', usercode: 'test-user');

/// A tiny in-process fake of just enough of BAMM's write endpoints
/// (`GetById`, `RecordLocking/Lock`, `Save`) to test the read-back reporting
/// in `WhitelistedFieldWriter` deterministically - in particular the
/// "silently dropped" and "returned differently" cases, which the real
/// `bamm-mock` service cannot be made to produce (it always keeps and
/// returns exactly what it was sent).
class _FakeBammServer {
  final Map<String, String?> stored;
  final Set<String> dropFields;
  final Map<String, String> forcedValues;

  int saveCalls = 0;
  int lockCalls = 0;
  Map<String, dynamic>? lastSaveBody;

  _FakeBammServer({
    Map<String, String?>? stored,
    this.dropFields = const {},
    this.forcedValues = const {},
  }) : stored = stored ?? {};

  Map<String, dynamic> _model() => {
        'typeName': 'Cogep.BusinessLogic.WORK_ORDER, Cogep.BusinessLogic, Version=6.9.4.12',
        'guid': 'fake-guid',
        'state': 1,
        'isNull': false,
        'forceEmpty': false,
        'properties': [
          {'name': 'WOR_ID', 'type': 3, 'value': '700100', 'state': 1},
          {'name': 'CanUserModify', 'type': 12, 'value': stored['CanUserModify'] ?? 'true', 'state': 1},
          {'name': 'WOR_DESCR', 'type': 9, 'value': stored['WOR_DESCR'], 'state': 1},
          {'name': 'WOR_TASK', 'type': 9, 'value': stored['WOR_TASK'], 'state': 1},
          {'name': 'RCP_ID', 'type': 4, 'value': stored['RCP_ID'], 'state': 1},
          {'name': 'WOR_REQUI_DATE', 'type': 28, 'value': stored['WOR_REQUI_DATE'], 'state': 1},
          {'name': 'WOR_PLAN_DATE', 'type': 28, 'value': stored['WOR_PLAN_DATE'], 'state': 1},
          {'name': 'WOR_END_PLAN_DATE', 'type': 28, 'value': stored['WOR_END_PLAN_DATE'], 'state': 1},
          {'name': 'CTG_ID', 'type': 4, 'value': stored['CTG_ID'], 'state': 1},
          {'name': 'WOR_NB_3', 'type': 15, 'value': stored['WOR_NB_3'], 'state': 1},
          {'name': 'FUN_ID', 'type': 4, 'value': stored['FUN_ID'], 'state': 1},
          {'name': 'Status', 'type': 18, 'value': '8', 'state': 1},
        ],
        'childSets': <dynamic>[],
        'childs': <dynamic>[],
      };

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/api/login/FinalizeLogInWeb')) {
      return http.Response(
        jsonEncode({
          'value': {'token': 'fake-access', 'sessionToken': 'fake-session'},
        }),
        200,
      );
    }
    if (path.endsWith('/api/WorkOrder/GetById')) {
      return http.Response(jsonEncode({'value': _model()}), 200);
    }
    if (path.endsWith('/api/RecordLocking/Lock')) {
      lockCalls++;
      return http.Response(jsonEncode({'value': true}), 200);
    }
    if (path.endsWith('/api/WorkOrder/Save')) {
      saveCalls++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      lastSaveBody = body;
      for (final p in (body['properties'] as List).cast<Map<String, dynamic>>()) {
        final name = p['name'] as String;
        if (p['state'] == stateChanged && !dropFields.contains(name)) {
          stored[name] = p['value']?.toString();
        }
      }
      forcedValues.forEach((name, value) => stored[name] = value);
      return http.Response(jsonEncode({'value': body}), 200);
    }
    return http.Response('not found', 404);
  }
}

Future<WhitelistedFieldWriter> _writerFor(_FakeBammServer server) async {
  final transport = BammHttpTransport(_config, client: MockClient(server.handle));
  return WhitelistedFieldWriter(BammWorkOrderWriter(transport, _config));
}

void main() {
  group('BammWritableField (structural whitelist)', () {
    test('is exactly the sixteen approved BAMM properties, nothing more', () {
      // Expanded from the original six (Batch A) to the fields/lookups batch's
      // requested set - see fields.dart's doc comment and
      // ~/repos/BAMM/docs/06-field-reference.md for the property types backing
      // each addition. Still a closed enum: this test is the structural proof
      // that adding a sixteenth requires touching this list too.
      expect(
        BammWritableField.values.map((f) => f.bammProperty).toSet(),
        {
          'WOR_DESCR',
          'WOR_TASK',
          'RCP_ID',
          'WOR_REQUI_DATE',
          'WOR_PLAN_DATE',
          'WOR_END_PLAN_DATE',
          'CTG_ID',
          'SKI_ID',
          'WG6_ID',
          'WG7_ID',
          'WOR_EST_NB_EMP',
          'WSP_ID',
          'MNT_ID',
          'EXM_ID',
          'WOR_NB_3',
          'FUN_ID',
        },
      );
    });

    test('a write only ever marks the touched whitelisted properties changed, never anything else', () async {
      final server = _FakeBammServer();
      final writer = await _writerFor(server);

      await writer.write(700100, [
        const BammFieldEdit(BammWritableField.description, 'New description'),
        const BammFieldEdit(BammWritableField.responsible, '55'),
      ]);

      final changed = changedPropertyNames(server.lastSaveBody!).toSet();
      expect(changed, {'WOR_DESCR', 'RCP_ID'});
      // In particular, the model's other real properties (Status, WOR_TASK,
      // CanUserModify, ...) were sent back but never marked as edited - there
      // is no code path in fields.dart that could mark them so, since
      // BammFieldEdit can only ever be constructed with a BammWritableField.
    });
  });

  group('validation happens before any network call', () {
    test('a non-numeric responsible id is rejected with no HTTP call attempted', () async {
      var calls = 0;
      final transport = BammHttpTransport(
        _config,
        client: MockClient((request) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final writer = WhitelistedFieldWriter(BammWorkOrderWriter(transport, _config));

      await expectLater(
        () => writer.write(700100, [const BammFieldEdit(BammWritableField.responsible, 'not-a-number')]),
        throwsA(isA<BammFieldValidationException>()),
      );
      expect(calls, 0, reason: 'a bad value must be refused before any HTTP call, including login');
    });

    test('an unparseable date is rejected with no HTTP call attempted', () async {
      var calls = 0;
      final transport = BammHttpTransport(
        _config,
        client: MockClient((request) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final writer = WhitelistedFieldWriter(BammWorkOrderWriter(transport, _config));

      await expectLater(
        () => writer.write(700100, [const BammFieldEdit(BammWritableField.installStart, 'next tuesday')]),
        throwsA(isA<BammFieldValidationException>()),
      );
      expect(calls, 0);
    });

    test('an empty edit list is rejected before any network call', () async {
      var calls = 0;
      final transport = BammHttpTransport(
        _config,
        client: MockClient((request) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final writer = WhitelistedFieldWriter(BammWorkOrderWriter(transport, _config));

      await expectLater(() => writer.write(700100, []), throwsA(isA<BammFieldValidationException>()));
      expect(calls, 0);
    });
  });

  group('read-back reporting', () {
    test('every field saved and read back verbatim reports success', () async {
      final server = _FakeBammServer();
      final writer = await _writerFor(server);

      final result = await writer.write(700100, [
        const BammFieldEdit(BammWritableField.description, 'Replace the bearing'),
        const BammFieldEdit(BammWritableField.requiredDate, '2026-03-08'),
      ]);

      expect(result.isSuccess, isTrue);
      expect(result.summary, 'success');
      expect(server.lockCalls, 1, reason: 'the record lock must be acquired before Save');
      expect(server.saveCalls, 1);
    });

    test('a silently dropped field yields a non-success status, not success', () async {
      // Regression guard for the exact bug the batch brief calls out: a
      // hardcoded "success" must never coexist with a field that BAMM's own
      // read-back shows was dropped.
      final server = _FakeBammServer(dropFields: {'WOR_DESCR'});
      final writer = await _writerFor(server);

      final result = await writer.write(700100, [
        const BammFieldEdit(BammWritableField.description, 'Replace the bearing'),
        const BammFieldEdit(BammWritableField.responsible, '42'),
      ]);

      expect(result.isSuccess, isFalse);
      expect(result.summary, contains('dropped'));

      final descr = result.fields.firstWhere((f) => f.field == BammWritableField.description);
      expect(descr.status, BammFieldReadBackStatus.silentlyDropped);
      expect(descr.returnedValue, anyOf(isNull, isEmpty));

      final responsible = result.fields.firstWhere((f) => f.field == BammWritableField.responsible);
      expect(responsible.status, BammFieldReadBackStatus.saved);
    });

    test('a field BAMM returns with a different value is reported, not swallowed as success', () async {
      final server = _FakeBammServer(forcedValues: {'RCP_ID': '999'});
      final writer = await _writerFor(server);

      final result = await writer.write(700100, [
        const BammFieldEdit(BammWritableField.responsible, '42'),
      ]);

      expect(result.isSuccess, isFalse);
      expect(result.summary, contains('returned differently'));
      final responsible = result.fields.single;
      expect(responsible.status, BammFieldReadBackStatus.returnedDifferent);
      expect(responsible.returnedValue, '999');
    });

    test('a newly-whitelisted lookup field (classification/CTG_ID) round-trips like the original six', () async {
      final server = _FakeBammServer();
      final writer = await _writerFor(server);

      final result = await writer.write(700100, [
        const BammFieldEdit(BammWritableField.classification, '4123'),
        const BammFieldEdit(BammWritableField.priorityEm, '12.5'),
      ]);

      expect(result.isSuccess, isTrue);
      expect(server.stored['CTG_ID'], '4123');
      expect(server.stored['WOR_NB_3'], '12.5');
    });

    test('a newly-whitelisted lookup field BAMM silently drops is reported, not swallowed - proves the read-back guard has teeth on the new fields too', () async {
      final server = _FakeBammServer(dropFields: {'CTG_ID'});
      final writer = await _writerFor(server);

      final result = await writer.write(700100, [
        const BammFieldEdit(BammWritableField.classification, '4123'),
      ]);

      expect(result.isSuccess, isFalse);
      expect(result.fields.single.status, BammFieldReadBackStatus.silentlyDropped);
    });

    test('BAMM reporting the work order as not modifiable is refused before any write', () async {
      final server = _FakeBammServer(stored: {'CanUserModify': 'false'});
      final writer = await _writerFor(server);

      await expectLater(
        () => writer.write(700100, [const BammFieldEdit(BammWritableField.description, 'x')]),
        throwsA(isA<BammModelException>()),
      );
      expect(server.saveCalls, 0);
    });
  });
}
