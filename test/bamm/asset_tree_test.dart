import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/queries/asset_tree.dart';
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
  group('BammAssetTreeClient.level', () {
    test('?id=X returns X\'s children, not X itself - parses that shape', () async {
      final client = _clientFor((request) async {
        expect(request.url.path, '/api/WorkOrderTreeView/GetAssets');
        expect(request.url.queryParameters['id'], '700012595');
        // What comes back are 700012595's children (e.g. node 700012596),
        // per the captures - the level() call does not resolve further.
        return http.Response(
          jsonEncode({
            'value': [
              {
                'id': 700012596,
                'text': 'Cell 1',
                'typeLetter': 'C',
                'isDirectory': true,
                'hasChildren': true,
                'isSelectable': false,
                'children': [700012700, 700012701],
              }
            ]
          }),
          200,
        );
      });
      final transport = await _loggedInTransport(client);
      final tree = BammAssetTreeClient(transport, const BammConfig(usercode: 'mock'));

      final nodes = await tree.level(nodeId: 700012595);

      expect(nodes, hasLength(1));
      expect(nodes.first.id, 700012596);
      expect(nodes.first.text, 'Cell 1');
      // Children are left as raw ids - not walked/resolved by this client.
      expect(nodes.first.children, [700012700, 700012701]);
    });

    test('root level defaults nodeId to 0', () async {
      final client = _clientFor((request) async {
        expect(request.url.queryParameters['id'], '0');
        return http.Response(
          jsonEncode({
            'value': [
              {
                'id': 1,
                'text': 'PLANT A',
                'typeLetter': 'P',
                'isDirectory': true,
                'hasChildren': true,
                'isSelectable': false,
                'isRoot': true,
                'children': [20, 30],
              }
            ]
          }),
          200,
        );
      });
      final transport = await _loggedInTransport(client);
      final tree = BammAssetTreeClient(transport, const BammConfig(usercode: 'mock'));

      final nodes = await tree.level();

      expect(nodes.single.isRoot, isTrue);
      expect(nodes.single.children, [20, 30]);
    });

    test('a leaf node (no children) parses to an empty children list', () async {
      final client = _clientFor((request) async => http.Response(
            jsonEncode({
              'value': [
                {
                  'id': 21110,
                  'text': 'Filler head A',
                  'typeLetter': 'F',
                  'isDirectory': false,
                  'hasChildren': false,
                  'isSelectable': true,
                  'children': [],
                }
              ]
            }),
            200,
          ));
      final transport = await _loggedInTransport(client);
      final tree = BammAssetTreeClient(transport, const BammConfig(usercode: 'mock'));

      final nodes = await tree.level(nodeId: 2110);

      expect(nodes.single.hasChildren, isFalse);
      expect(nodes.single.children, isEmpty);
    });

    test('a response with no value list is a typed error', () async {
      final client = _clientFor((request) async => http.Response(jsonEncode({}), 200));
      final transport = await _loggedInTransport(client);
      final tree = BammAssetTreeClient(transport, const BammConfig(usercode: 'mock'));

      expect(tree.level(nodeId: 999), throwsA(isA<AssetTreeException>()));
    });
  });
}
