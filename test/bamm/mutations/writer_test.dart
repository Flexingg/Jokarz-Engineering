import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/mutations/exceptions.dart';
import 'package:jokarz_engineering/bamm/mutations/model_ops.dart';
import 'package:jokarz_engineering/bamm/mutations/writer.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';

const _config = BammConfig(origin: 'http://fake-bamm.test', usercode: 'test-user');

http.Response _json(Object body, {int status = 200}) => http.Response(jsonEncode(body), status);

Map<String, dynamic> _blankModel({String worId = '0'}) => {
      'typeName': 'Cogep.BusinessLogic.WORK_ORDER, Cogep.BusinessLogic, Version=6.9.4.12',
      'guid': 'writer-test-guid',
      'state': 3,
      'isNull': false,
      'forceEmpty': false,
      'properties': [
        {'name': 'WOR_ID', 'type': 3, 'value': worId},
        {'name': 'WOR_DESCR', 'type': 9, 'value': ''},
        {'name': 'FUN_ID', 'type': 4, 'value': ''},
      ],
      'childSets': [
        {
          'originProperty': 'WO_DETAIL',
          'itemKeyProperty': 'WOD_ID',
          'itemPrototype': {
            'typeName': 'Cogep.BusinessLogic.WO_DETAIL, Cogep.BusinessLogic',
            'properties': [
              {'name': 'WOD_ID', 'type': 3, 'value': '0'},
              {'name': 'ACY_ID', 'type': 4},
              {'name': 'WOD_DESCR', 'type': 9},
            ],
          },
          'items': <dynamic>[],
          'deletedItems': <dynamic>[],
        },
      ],
      'childs': <dynamic>[],
    };

BammHttpTransport _loggedInTransport(Future<http.Response> Function(http.Request) handler) =>
    BammHttpTransport(_config, client: MockClient(handler));

void main() {
  group('getNew / getById', () {
    test('getNew returns the value object from GetNew', () async {
      var loggedIn = false;
      final transport = _loggedInTransport((request) async {
        if (request.url.path.endsWith('FinalizeLogInWeb')) {
          loggedIn = true;
          return _json({
            'value': {'token': 't', 'sessionToken': 's'},
          });
        }
        expect(request.url.path, endsWith('/api/WorkOrder/GetNew'));
        return _json({'value': _blankModel()});
      });
      final writer = BammWorkOrderWriter(transport, _config);

      final model = await writer.getNew();

      expect(loggedIn, isTrue);
      expect(propertyValue(model, 'WOR_ID'), '0');
    });

    test('getById throws when the returned model belongs to a different work order', () async {
      final transport = _loggedInTransport((request) async {
        if (request.url.path.endsWith('FinalizeLogInWeb')) {
          return _json({
            'value': {'token': 't', 'sessionToken': 's'},
          });
        }
        return _json({'value': _blankModel(worId: '999')});
      });
      final writer = BammWorkOrderWriter(transport, _config);

      await expectLater(() => writer.getById(700100), throwsA(isA<BammModelException>()));
    });
  });

  group('Change* calls adopt the replacement model', () {
    test('validateSelectedAsset adopts the server response as the new working model', () async {
      final transport = _loggedInTransport((request) async {
        if (request.url.path.endsWith('FinalizeLogInWeb')) {
          return _json({
            'value': {'token': 't', 'sessionToken': 's'},
          });
        }
        if (request.url.path.endsWith('ValidateSelectedAsset')) {
          final sent = jsonDecode(request.body) as Map<String, dynamic>;
          setProperty(sent, 'FUN_ID', '700002757');
          return _json({'value': sent});
        }
        return _json({'value': {}});
      });
      final writer = BammWorkOrderWriter(transport, _config);

      final result = await writer.validateSelectedAsset(700002757, _blankModel());

      expect(propertyValue(result, 'FUN_ID'), '700002757');
    });

    test('falls back to the original model when the response has no usable value', () async {
      final transport = _loggedInTransport((request) async {
        if (request.url.path.endsWith('FinalizeLogInWeb')) {
          return _json({
            'value': {'token': 't', 'sessionToken': 's'},
          });
        }
        return _json({'value': null});
      });
      final writer = BammWorkOrderWriter(transport, _config);
      final original = _blankModel();

      final result = await writer.changeModel(1, original);

      expect(identical(result, original), isTrue);
    });
  });

  group('addActivityLine', () {
    test('appends a filled line to the WO_DETAIL child set with a negative temp id', () async {
      final transport = _loggedInTransport((request) async {
        if (request.url.path.endsWith('FinalizeLogInWeb')) {
          return _json({
            'value': {'token': 't', 'sessionToken': 's'},
          });
        }
        // The mock's AddActivityLine returns a blank WO_DETAIL prototype item.
        return _json({
          'value': {
            'typeName': 'Cogep.BusinessLogic.WO_DETAIL, Cogep.BusinessLogic',
            'properties': [
              {'name': 'WOD_ID', 'type': 3, 'value': '0'},
              {'name': 'ACY_ID', 'type': 4},
              {'name': 'WOD_DESCR', 'type': 9},
            ],
          },
        });
      });
      final writer = BammWorkOrderWriter(transport, _config);
      final model = _blankModel();

      final line = await writer.addActivityLine(model, fields: {'ACY_ID': 16, 'WOD_DESCR': 'inspect'});

      expect(propertyValue(line, 'ACY_ID'), '16');
      expect(propertyValue(line, 'WOD_DESCR'), 'inspect');
      expect(propertyValue(line, 'WOD_ID'), '-1');
      expect(childItems(model, 'WO_DETAIL'), hasLength(1));
    });

    test('throws for an unknown activity-line field name', () async {
      final transport = _loggedInTransport((request) async {
        if (request.url.path.endsWith('FinalizeLogInWeb')) {
          return _json({
            'value': {'token': 't', 'sessionToken': 's'},
          });
        }
        return _json({
          'value': {
            'typeName': 'Cogep.BusinessLogic.WO_DETAIL, Cogep.BusinessLogic',
            'properties': [
              {'name': 'WOD_ID', 'type': 3, 'value': '0'},
            ],
          },
        });
      });
      final writer = BammWorkOrderWriter(transport, _config);

      await expectLater(
        () => writer.addActivityLine(_blankModel(), fields: {'NOT_A_FIELD': 'x'}),
        throwsA(isA<BammModelException>()),
      );
    });
  });

  group('save', () {
    test('sends the dynamicdtoV1 content type and returns the saved value', () async {
      String? sentContentType;
      final transport = _loggedInTransport((request) async {
        if (request.url.path.endsWith('FinalizeLogInWeb')) {
          return _json({
            'value': {'token': 't', 'sessionToken': 's'},
          });
        }
        sentContentType = request.headers['Content-Type'];
        return _json({'value': jsonDecode(request.body)});
      });
      final writer = BammWorkOrderWriter(transport, _config);

      final result = await writer.save(_blankModel(worId: '700100'), 700100);

      expect(sentContentType, kBammContentTypeDto);
      expect(propertyValue(result, 'WOR_ID'), '700100');
    });

    test('a 599 application error surfaces BAMM\'s own message', () async {
      final transport = _loggedInTransport((request) async {
        if (request.url.path.endsWith('FinalizeLogInWeb')) {
          return _json({
            'value': {'token': 't', 'sessionToken': 's'},
          });
        }
        return _json({'exceptionMessage': 'a child model has no originProperty'}, status: 599);
      });
      final writer = BammWorkOrderWriter(transport, _config);

      try {
        await writer.save(_blankModel(worId: '700100'), 700100);
        fail('expected a BammApplicationException');
      } on BammApplicationException catch (e) {
        expect(e.message, 'a child model has no originProperty');
      }
    });

    test('buildSaveBody refuses a model whose WOR_ID does not match the target work order', () {
      final model = _blankModel(worId: '1');
      final writer = BammWorkOrderWriter(_loggedInTransport((_) async => _json({})), _config);
      expect(() => writer.buildSaveBody(model, 2), throwsA(isA<BammModelException>()));
    });
  });

  group('createWorkOrder', () {
    test('refuses a missing description before any HTTP call', () async {
      var calls = 0;
      final transport = _loggedInTransport((request) async {
        calls++;
        return _json({'value': {}});
      });
      final writer = BammWorkOrderWriter(transport, _config);

      await expectLater(
        () => writer.createWorkOrder(fields: const {}),
        throwsA(isA<BammFieldValidationException>()),
      );
      expect(calls, 0);
    });

    test('rejects an unknown or protected field without sending it', () async {
      final transport = _loggedInTransport((request) async {
        if (request.url.path.endsWith('FinalizeLogInWeb')) {
          return _json({
            'value': {'token': 't', 'sessionToken': 's'},
          });
        }
        return _json({'value': _blankModel()});
      });
      final writer = BammWorkOrderWriter(transport, _config);

      await expectLater(
        () => writer.createWorkOrder(fields: const {'WOR_DESCR': 'x', 'WOR_ID': '5'}),
        throwsA(isA<BammModelException>()),
      );
    });

    test('the full create sequence saves and reads back the new id', () async {
      final transport = _loggedInTransport((request) async {
        final path = request.url.path;
        if (path.endsWith('FinalizeLogInWeb')) {
          return _json({
            'value': {'token': 't', 'sessionToken': 's'},
          });
        }
        if (path.endsWith('GetNew')) {
          return _json({'value': _blankModel()});
        }
        if (path.endsWith('ValidateSelectedAsset') || path.endsWith('ChangeFunctionCode')) {
          return _json({'value': jsonDecode(request.body)});
        }
        if (path.endsWith('Save')) {
          final sent = jsonDecode(request.body) as Map<String, dynamic>;
          setProperty(sent, 'WOR_ID', '700999999');
          return _json({'value': sent});
        }
        if (path.endsWith('GetById')) {
          return _json({'value': _blankModel(worId: '700999999')});
        }
        return _json({'value': {}});
      });
      final writer = BammWorkOrderWriter(transport, _config);

      final result = await writer.createWorkOrder(
        fields: const {'WOR_DESCR': 'Replace the bearing'},
        assetId: 700002757,
      );

      expect(result['workOrderId'], '700999999');
      expect(result['model'], isNotNull);
    });
  });
}
