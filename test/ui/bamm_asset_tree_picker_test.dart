// The 5-level machine/asset tree picker (`bamm_asset_tree_picker.dart`)
// replaces the free-text machine field. Two guard rails matter most:
// (1) a folder (isSelectable == false) must never be returned as a pick,
// only used to descend a level, and (2) each level is fetched lazily, one
// call per expansion - `?id=X` returns X's children, per the BAMM reference.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/queries/asset_tree.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';
import 'package:jokarz_engineering/ui/widgets/bamm_asset_tree_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

Future<BammAssetTreeClient> _fakeClient(Map<String, List<Map<String, dynamic>>> levels) async {
  final calls = <String>[];
  final transport = BammHttpTransport(
    const BammConfig(origin: 'http://mock.local', usercode: 'mock', companyId: 3),
    client: MockClient((request) async {
      if (request.method == 'PUT') {
        return http.Response(jsonEncode({'value': {'token': 't', 'sessionToken': 's'}}), 200);
      }
      final id = request.url.queryParameters['id'] ?? '0';
      calls.add(id);
      final nodes = levels[id] ?? const [];
      return http.Response(jsonEncode({'value': nodes}), 200);
    }),
  );
  await transport.login();
  return BammAssetTreeClient(transport, const BammConfig(usercode: 'mock'));
}

void main() {
  testWidgets('a folder (not selectable) cannot be picked, but expands its children', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final client = await _fakeClient({
      '0': [
        {
          'id': 10,
          'text': 'PLANT A',
          'isDirectory': true,
          'hasChildren': true,
          'isSelectable': false,
          'children': [20],
        },
      ],
      '10': [
        {
          'id': 20,
          'text': 'Pump 12',
          'isDirectory': false,
          'hasChildren': false,
          'isSelectable': true,
          'children': [],
        },
      ],
    });

    BammAssetSelection? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              picked = await showBammAssetTreePicker(context, client: client);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Level 1 shows PLANT A; it is a folder, so "Use this asset" must stay
    // disabled until a *selectable* node further down is chosen.
    expect(find.text('PLANT A'), findsOneWidget);
    final useButtonBefore = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Use this asset'));
    expect(useButtonBefore.onPressed, isNull, reason: 'nothing selectable chosen yet');

    await tester.tap(find.text('PLANT A'));
    await tester.pumpAndSettle();

    // Selecting the folder lazily loaded level 2 - its child, a selectable leaf.
    expect(find.text('Pump 12'), findsOneWidget);
    await tester.tap(find.text('Pump 12'));
    await tester.pumpAndSettle();

    final useButtonAfter = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Use this asset'));
    expect(useButtonAfter.onPressed, isNotNull, reason: 'a selectable leaf is now chosen');

    await tester.tap(find.text('Use this asset'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.id, '20');
    expect(picked!.path, ['PLANT A', 'Pump 12']);
  });

  testWidgets('only one HTTP call per level - children are fetched lazily, not eagerly', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var callCount = 0;
    final transport = BammHttpTransport(
      const BammConfig(origin: 'http://mock.local', usercode: 'mock', companyId: 3),
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          return http.Response(jsonEncode({'value': {'token': 't', 'sessionToken': 's'}}), 200);
        }
        callCount++;
        final id = request.url.queryParameters['id'] ?? '0';
        if (id == '0') {
          return http.Response(
            jsonEncode({
              'value': [
                {'id': 1, 'text': 'A', 'isDirectory': true, 'hasChildren': true, 'isSelectable': false, 'children': []},
              ]
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'value': []}), 200);
      }),
    );
    await transport.login();
    final client = BammAssetTreeClient(transport, const BammConfig(usercode: 'mock'));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showBammAssetTreePicker(context, client: client),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(callCount, 1, reason: 'only level 1 (root) is fetched on open');

    await tester.tap(find.text('A'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(callCount, 2, reason: 'expanding "A" fetches exactly its own children, one call');
  });
}
