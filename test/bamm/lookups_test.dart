import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/schema/lookups.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';

Future<BammHttpTransport> _loggedInTransport(http.Client client) async {
  final transport = BammHttpTransport(
    const BammConfig(origin: 'http://mock.local', usercode: 'mock', companyId: 3),
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
  group('BammLookupsClient.fetch', () {
    test('parses the {total, value:[...]} envelope, matching the real shape', () async {
      final client = _clientFor((request) async {
        expect(request.url.path, '/api/WorkOrderLookup/GetPriority');
        expect(request.url.queryParameters['querytype'], 'top');
        expect(request.url.queryParameters['companyId'], '3');
        return http.Response(
          jsonEncode({
            'total': 5,
            'value': [
              {'id': 1, 'value': 0, 'description': '1 (High)', 'code': 'P1', 'type': null, 'inactive': false},
              {'id': 2, 'value': 0, 'description': '2', 'code': 'P2', 'type': null, 'inactive': false},
            ],
          }),
          200,
        );
      });
      final transport = await _loggedInTransport(client);
      final lookups = BammLookupsClient(transport, const BammConfig(usercode: 'mock'));

      final result = await lookups.fetch('GetPriority');

      expect(result.total, 5);
      expect(result.items, hasLength(2));
      expect(result.items.first.id, '1');
      expect(result.items.first.label, '1 (High)');
      expect(result.items.first.code, 'P1');
    });

    test('a POST body is empty - everything travels in the query string', () async {
      final client = _clientFor((request) async {
        expect(request.body, isEmpty);
        return http.Response(jsonEncode({'total': 0, 'value': []}), 200);
      });
      final transport = await _loggedInTransport(client);
      final lookups = BammLookupsClient(transport, const BammConfig(usercode: 'mock'));

      await lookups.fetch('GetWorkOrderStep');
    });

    test('total greater than the returned rows is surfaced as truncated, never hidden', () {
      // BAMM caps GetSubActivities at 200 of 377 rows and never pages further
      // unasked - this must be visible to the caller, not silently accepted
      // as "the whole list".
      const result = LookupResult(
        items: [
          LookupOption(id: '1', label: 'a', code: '', inactive: false),
        ],
        total: 377,
      );
      expect(result.isTruncated, isTrue);
    });

    test('total equal to (or less than) the returned rows is not truncated', () {
      const complete = LookupResult(
        items: [LookupOption(id: '1', label: 'a', code: '', inactive: false)],
        total: 1,
      );
      expect(complete.isTruncated, isFalse);

      const noTotalReported = LookupResult(items: [], total: null);
      expect(noTotalReported.isTruncated, isFalse);
    });

    test('a response with no value list is a typed error, not an empty list', () async {
      final client = _clientFor((request) async => http.Response(jsonEncode({'total': 0}), 200));
      final transport = await _loggedInTransport(client);
      final lookups = BammLookupsClient(transport, const BammConfig(usercode: 'mock'));

      expect(lookups.fetch('GetPriority'), throwsA(isA<BammLookupsException>()));
    });

    test('a 500 from the lookup endpoint is a typed HTTP error, not an empty list', () async {
      final client = _clientFor((request) async => http.Response('server error', 500));
      final transport = await _loggedInTransport(client);
      final lookups = BammLookupsClient(transport, const BammConfig(usercode: 'mock'));

      expect(lookups.fetch('GetPriority'), throwsA(isA<BammHttpException>()));
    });
  });

  group('named convenience lookups build the right query params', () {
    test('steps() asks for showSecondaryStep=false', () async {
      final client = _clientFor((request) async {
        expect(request.url.path, '/api/WorkOrderLookup/GetWorkOrderStep');
        expect(request.url.queryParameters['showSecondaryStep'], 'false');
        return http.Response(jsonEncode({'total': 0, 'value': []}), 200);
      });
      final transport = await _loggedInTransport(client);
      await BammLookupsClient(transport, const BammConfig(usercode: 'mock')).steps();
    });

    test('groupings(type) passes the slot as a query param', () async {
      final client = _clientFor((request) async {
        expect(request.url.path, '/api/WorkOrderLookup/GetMultiGrouping');
        expect(request.url.queryParameters['type'], '2');
        return http.Response(jsonEncode({'total': 0, 'value': []}), 200);
      });
      final transport = await _loggedInTransport(client);
      await BammLookupsClient(transport, const BammConfig(usercode: 'mock')).groupings(2);
    });

    test('responsible(search:) adds search + searchColumns only when given', () async {
      final client = _clientFor((request) async {
        expect(request.url.queryParameters['search'], 'jane');
        expect(request.url.queryParameters['searchColumns'], 'description');
        return http.Response(jsonEncode({'total': 0, 'value': []}), 200);
      });
      final transport = await _loggedInTransport(client);
      await BammLookupsClient(transport, const BammConfig(usercode: 'mock')).responsible(search: 'jane');
    });
  });
}
