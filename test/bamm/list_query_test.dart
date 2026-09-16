import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/queries/list_query.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';

/// A verbatim (trimmed) copy of `~/repos/BAMM/samples/list_row_sample.json` -
/// captured from the live `/debug` page. Every row is wrapped in
/// `propertyList`.
const _realListResponse = {
  'value': [
    {
      'propertyList': {
        'workOrderId': 700203512,
        'worNoSeq': 'WO-143608.4',
        'functionInfo2': 'Cell 1',
        'functionCode': '700009868',
        'worEstLaborTime': 0.0,
        'worEstNbEmployee': 1,
        'woDescription': 'LR repair request',
        'woStatusDescription': 'Registered',
        'executionModeDescription': 'Down',
        'funCodeLevelNiv3Description': 'Filler A',
        'requesterName': 'Sample, Person',
        'recipientName': '',
        'worNumber3': null,
      }
    },
    {
      'propertyList': {
        'workOrderId': 700203513,
        'worNoSeq': 'WO-143609.1',
        'functionInfo2': 'Cell 2',
        'functionCode': '700010290',
        'worEstLaborTime': 1.5,
        'worEstNbEmployee': 2,
        'woDescription': 'Conveyor jam',
        'woStatusDescription': 'In preparation',
        'executionModeDescription': '',
        'funCodeLevelNiv3Description': 'Conveyor B',
        'requesterName': '',
        'recipientName': 'Doe, Jane',
        'worNumber3': null,
      }
    },
  ],
};

Future<BammHttpTransport> _loggedInTransport(http.Client client) async {
  final transport = BammHttpTransport(
    const BammConfig(origin: 'http://mock.local', usercode: 'mock', companyId: 3, listScreenId: 700000124),
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
  group('ListQueryRequest.toJson', () {
    test('shapes filters/listFormat/isCountOnly as BAMM expects', () {
      final request = ListQueryRequest(
        fields: const [ListColumn(key: 'worNoSeq', header: 'Work order', fieldDataType: 6)],
        orderByFields: const [ListOrderBy('woIssueDate', ascending: false)],
        filters: [
          ListFilter.byList(
            searchFieldKey: 'woStatusId',
            options: const [
              {'id': 1, 'description': 'In preparation'}
            ],
            sourceUrl: 'GetWorkOrderStatus',
          ),
          ListFilter.byText(searchFieldKey: 'woDescription', value: 'bearing'),
        ],
        topCount: 500,
      );

      final json = request.toJson();

      expect(json['isCountOnly'], isFalse);
      expect(json['listFormat']['topCount'], 500);
      expect(json['listFormat']['fields'], [
        {'name': 'worNoSeq', 'key': 'worNoSeq', 'header': 'Work order', 'isVisible': true, 'fieldDataType': 6}
      ]);
      expect(json['listFormat']['orderByFields'], [
        {'name': 'woIssueDate', 'ascending': false}
      ]);
      final filters = json['filters'] as List;
      expect(filters, hasLength(2));
      expect(filters[0]['searchFieldKey'], 'woStatusId');
      expect(filters[0]['filterType'], 8);
      expect(filters[0]['values'][0]['listValues'], [
        {'id': 1, 'description': 'In preparation'}
      ]);
      expect(filters[1]['searchFieldKey'], 'woDescription');
      expect(filters[1]['filterType'], 1);
      expect(filters[1]['values'][0]['stringValues'], ['bearing']);
    });
  });

  group('BammListQueryClient.fetch', () {
    test('unwraps propertyList - skipping this is the classic failure mode', () async {
      final client = _clientFor((request) async {
        expect(request.url.path, '/api/WorkOrderList/GetListData');
        return http.Response(jsonEncode(_realListResponse), 200);
      });
      final transport = await _loggedInTransport(client);
      final queryClient = BammListQueryClient(transport, const BammConfig(usercode: 'mock'));

      final result = await queryClient.fetch(
        const ListQueryRequest(fields: [ListColumn(key: 'worNoSeq')]),
      );

      expect(result.rows, hasLength(2));
      // Unwrapped: columns are readable directly, not nested under propertyList.
      expect(result.rows.first['worNoSeq'], 'WO-143608.4');
      expect(result.rows.first.containsKey('propertyList'), isFalse);
      expect(result.rows.last['recipientName'], 'Doe, Jane');
      expect(result.total, 2);
    });

    test('a row with no propertyList wrapper still works (defensive, matches Python)', () async {
      final client = _clientFor((request) async => http.Response(
            jsonEncode({
              'value': [
                {'worNoSeq': 'WO-1', 'woDescription': 'flat row, no wrapper'}
              ]
            }),
            200,
          ));
      final transport = await _loggedInTransport(client);
      final queryClient = BammListQueryClient(transport, const BammConfig(usercode: 'mock'));

      final result = await queryClient.fetch(
        const ListQueryRequest(fields: [ListColumn(key: 'worNoSeq')]),
      );

      expect(result.rows.single['worNoSeq'], 'WO-1');
    });

    test('a response with no value list is a typed error, not an empty list', () async {
      final client = _clientFor((request) async => http.Response(jsonEncode({'total': 0}), 200));
      final transport = await _loggedInTransport(client);
      final queryClient = BammListQueryClient(transport, const BammConfig(usercode: 'mock'));

      expect(
        queryClient.fetch(const ListQueryRequest(fields: [ListColumn(key: 'worNoSeq')])),
        throwsA(isA<ListQueryException>()),
      );
    });
  });
}
