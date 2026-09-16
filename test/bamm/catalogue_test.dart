import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/schema/catalogue.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';

/// The real `GetNewFilter` response shape: a JSON envelope carrying an XML
/// document as a string. Excerpted (2 fields) from the live capture at
/// `~/repos/BAMM/samples/list_filters.json` / a real `GetNewFilter` call.
const _realFilterXmlResponse = {
  'value': {
    'programId': 1,
    'value': '<?xml version="1.0" encoding="utf-8"?>\n'
        '<ListFilter>\n'
        '  <Filter key="regrouping1Id" type="List" description="Areas">\n'
        '    <Key>regrouping1Id</Key>\n'
        '    <Type>List</Type>\n'
        '    <Description>Areas</Description>\n'
        '  </Filter>\n'
        '  <Filter key="functionCode3" type="Text" description="Alternate asset code">\n'
        '    <Key>functionCode3</Key>\n'
        '    <Type>Text</Type>\n'
        '    <Description>Alternate asset code</Description>\n'
        '  </Filter>\n'
        '</ListFilter>',
  }
};

/// Excerpted from `~/repos/BAMM/samples/grid_fields.json` via the live
/// `GetListConfigurationStructure` response shape.
const _realColumnsResponse = {
  'value': {
    'availableFields': [
      {
        'key': 'woNumber',
        'name': 'woNumber',
        'header': 'WO number',
        'isVisible': true,
        'isHidden': false,
        'fieldDataType': 3,
        'format': 1,
        'linkURL': '/',
        'pinned': null,
        'order': 0,
        'isClickable': false,
        'hasValueChanger': false,
      },
      {
        'key': 'worNoSeq',
        'name': 'worNoSeq',
        'header': 'Work order',
        'isVisible': true,
        'isHidden': false,
        'fieldDataType': 6,
        'format': 0,
        'linkURL': '/workorder/detail/{workOrderId}',
        'pinned': null,
        'order': 0,
        'isClickable': false,
        'hasValueChanger': false,
      },
    ],
  }
};

Future<BammHttpTransport> _loggedInTransport(http.Client client) async {
  final transport = BammHttpTransport(
    const BammConfig(origin: 'http://mock.local', usercode: 'mock', companyId: 3, spwId: 700000027),
    client: client,
  );
  await transport.login();
  return transport;
}

http.Client _clientFor(Future<http.Response> Function(http.Request) onCall) {
  return MockClient((request) async {
    if (request.method == 'PUT') {
      return http.Response(
        jsonEncode({
          'value': {'token': 't', 'sessionToken': 's'}
        }),
        200,
      );
    }
    return onCall(request);
  });
}

void main() {
  group('columns()', () {
    test('parses availableFields into ColumnDef entries', () async {
      final client = _clientFor((request) async {
        expect(request.url.path, '/api/dynamicScreen/GetListConfigurationStructure');
        return http.Response(jsonEncode(_realColumnsResponse), 200);
      });
      final transport = await _loggedInTransport(client);
      final catalogue = BammCatalogueClient(transport, const BammConfig(usercode: 'mock'));

      final columns = await catalogue.columns();

      expect(columns, hasLength(2));
      expect(columns.first.key, 'woNumber');
      expect(columns.first.header, 'WO number');
      expect(columns.last.linkURL, '/workorder/detail/{workOrderId}');
    });

    test('a response with no availableFields is a typed error, not an empty list', () async {
      final client = _clientFor((request) async => http.Response(jsonEncode({'value': {}}), 200));
      final transport = await _loggedInTransport(client);
      final catalogue = BammCatalogueClient(transport, const BammConfig(usercode: 'mock'));

      expect(catalogue.columns(), throwsA(isA<BammCatalogueException>()));
    });

    test('a 500 is a typed HTTP error, never a silent empty catalogue', () async {
      final client = _clientFor((request) async => http.Response('nope', 500));
      final transport = await _loggedInTransport(client);
      final catalogue = BammCatalogueClient(transport, const BammConfig(usercode: 'mock'));

      expect(catalogue.columns(), throwsA(isA<BammHttpException>()));
    });
  });

  group('filters()', () {
    test('parses the embedded XML document into FilterFieldDef entries', () async {
      final client = _clientFor((request) async {
        expect(request.url.path, '/api/dynamicScreen/GetNewFilter');
        return http.Response(jsonEncode(_realFilterXmlResponse), 200);
      });
      final transport = await _loggedInTransport(client);
      final catalogue = BammCatalogueClient(transport, const BammConfig(usercode: 'mock'));

      final filters = await catalogue.filters();

      expect(filters, hasLength(2));
      expect(filters[0].key, 'regrouping1Id');
      expect(filters[0].type, 'List');
      expect(filters[0].description, 'Areas');
      expect(filters[1].key, 'functionCode3');
      expect(filters[1].type, 'Text');
    });

    test('malformed XML is a typed catalogue error', () async {
      final client = _clientFor((request) async => http.Response(
            jsonEncode({
              'value': {'value': '<ListFilter><Filter key="x"'}
            }),
            200,
          ));
      final transport = await _loggedInTransport(client);
      final catalogue = BammCatalogueClient(transport, const BammConfig(usercode: 'mock'));

      expect(catalogue.filters(), throwsA(isA<BammCatalogueException>()));
    });

    test('a missing XML payload is a typed catalogue error', () async {
      final client = _clientFor((request) async => http.Response(
            jsonEncode({
              'value': {'programId': 1}
            }),
            200,
          ));
      final transport = await _loggedInTransport(client);
      final catalogue = BammCatalogueClient(transport, const BammConfig(usercode: 'mock'));

      expect(catalogue.filters(), throwsA(isA<BammCatalogueException>()));
    });
  });

  group('fieldCatalogue()', () {
    test('extracts the property descriptors from a live GetNew model', () async {
      final client = _clientFor((request) async {
        expect(request.url.path, '/api/WorkOrder/GetNew');
        return http.Response(
          jsonEncode({
            'value': {
              'typeName': 'Cogep.BusinessLogic.WORK_ORDER, Cogep.BusinessLogic',
              'state': 3,
              'properties': [
                {'name': 'WOR_DESCR', 'type': 9, 'display': 'WO description', 'isRequired': true},
                {'name': 'WOR_ID', 'type': 3, 'value': '0'},
              ],
              'childSets': [],
              'childs': [],
            }
          }),
          200,
        );
      });
      final transport = await _loggedInTransport(client);
      final catalogue = BammCatalogueClient(transport, const BammConfig(usercode: 'mock'));

      final fields = await catalogue.fieldCatalogue();

      expect(fields, hasLength(2));
      expect(fields.first.name, 'WOR_DESCR');
      expect(fields.first.display, 'WO description');
      expect(fields.first.isRequired, isTrue);
    });
  });

  group('priority() and groupings() delegate to the lookup family', () {
    test('priority() reads PRI_ID options via GetPriority', () async {
      final client = _clientFor((request) async {
        expect(request.url.path, '/api/WorkOrderLookup/GetPriority');
        return http.Response(
          jsonEncode({
            'total': 1,
            'value': [
              {'id': 1, 'description': '1 (High)', 'code': 'P1', 'inactive': false},
            ],
          }),
          200,
        );
      });
      final transport = await _loggedInTransport(client);
      final catalogue = BammCatalogueClient(transport, const BammConfig(usercode: 'mock'));

      final options = await catalogue.priority();

      expect(options, hasLength(1));
      expect(options.first.label, '1 (High)');
    });

    test('groupings(type) reads WGM_ID options via GetMultiGrouping?type=', () async {
      final client = _clientFor((request) async {
        expect(request.url.path, '/api/WorkOrderLookup/GetMultiGrouping');
        expect(request.url.queryParameters['type'], '1');
        return http.Response(
          jsonEncode({
            'total': 1,
            'value': [
              {'id': 4112, 'description': '5 Basics Miss - Housekeeping', 'inactive': false},
            ],
          }),
          200,
        );
      });
      final transport = await _loggedInTransport(client);
      final catalogue = BammCatalogueClient(transport, const BammConfig(usercode: 'mock'));

      final options = await catalogue.groupings(1);

      expect(options, hasLength(1));
      expect(options.first.id, '4112');
    });
  });
}
