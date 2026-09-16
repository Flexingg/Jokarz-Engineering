import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/queries/asset_tree.dart';
import 'package:jokarz_engineering/bamm/queries/list_query.dart';
import 'package:jokarz_engineering/bamm/schema/catalogue.dart';
import 'package:jokarz_engineering/bamm/schema/lookups.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';

/// Exercises the real read path over HTTP against the live `bamm-mock`
/// systemd service (`~/repos/BAMM/tools/mock_bamm.py`) on 127.0.0.1:5099.
///
/// Skipped cleanly (not failed) when the mock is unreachable, so this suite
/// still passes in an environment where the mock service isn't running.
const _mockOrigin = 'http://127.0.0.1:5099';

const _config = BammConfig(
  origin: _mockOrigin,
  usercode: 'mock-test-user',
  companyId: 3,
  spwId: 700000027,
  listScreenId: 700000124,
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

void main() {
  group('live mock (127.0.0.1:5099)', () {
    late bool reachable;

    setUpAll(() async {
      reachable = await _mockReachable();
    });

    test('login against the real endpoint returns usable tokens', () async {
      if (!reachable) {
        markTestSkipped('bamm-mock is not reachable on 127.0.0.1:5099');
        return;
      }
      final transport = BammHttpTransport(_config);
      addTearDown(transport.close);

      await transport.login();

      expect(transport.isAuthenticated, isTrue);
    });

    test('GetListData round-trips and unwraps propertyList for real', () async {
      if (!reachable) {
        markTestSkipped('bamm-mock is not reachable on 127.0.0.1:5099');
        return;
      }
      final transport = BammHttpTransport(_config);
      addTearDown(transport.close);
      await transport.login();
      final client = BammListQueryClient(transport, _config);

      final result = await client.fetch(
        const ListQueryRequest(
          fields: [
            ListColumn(key: 'worNoSeq', header: 'Work order'),
            ListColumn(key: 'woDescription', header: 'Description'),
          ],
        ),
      );

      expect(result.rows, isNotEmpty);
      for (final row in result.rows) {
        expect(row.containsKey('propertyList'), isFalse);
        expect(row.containsKey('worNoSeq'), isTrue);
      }
    });

    test('lookups against the real endpoint report a total and options', () async {
      if (!reachable) {
        markTestSkipped('bamm-mock is not reachable on 127.0.0.1:5099');
        return;
      }
      final transport = BammHttpTransport(_config);
      addTearDown(transport.close);
      await transport.login();
      final lookups = BammLookupsClient(transport, _config);

      final steps = await lookups.steps();

      expect(steps.items, isNotEmpty);
      expect(steps.total, isNotNull);
    });

    test('the asset tree root returns real nodes with unresolved child ids', () async {
      if (!reachable) {
        markTestSkipped('bamm-mock is not reachable on 127.0.0.1:5099');
        return;
      }
      final transport = BammHttpTransport(_config);
      addTearDown(transport.close);
      await transport.login();
      final tree = BammAssetTreeClient(transport, _config);

      final roots = await tree.level();

      expect(roots, isNotEmpty);
      expect(roots.first.isDirectory, isTrue);
    });

    test('the column and filter catalogues fetch live with no bundled fallback', () async {
      if (!reachable) {
        markTestSkipped('bamm-mock is not reachable on 127.0.0.1:5099');
        return;
      }
      final transport = BammHttpTransport(_config);
      addTearDown(transport.close);
      await transport.login();
      final catalogue = BammCatalogueClient(transport, _config);

      final columns = await catalogue.columns();
      final filters = await catalogue.filters();
      final fields = await catalogue.fieldCatalogue();

      expect(columns, isNotEmpty);
      expect(filters, isNotEmpty);
      expect(fields, isNotEmpty);
    });

    test('an application-level (599) failure surfaces its message over real HTTP', () async {
      if (!reachable) {
        markTestSkipped('bamm-mock is not reachable on 127.0.0.1:5099');
        return;
      }
      final transport = BammHttpTransport(_config);
      addTearDown(transport.close);
      await transport.login();

      // Save requires the `application/cogep.dynamicdtoV1+json` content type;
      // the mock answers a plain JSON POST here with a real 599.
      try {
        await transport.post(
          '/api/WorkOrder/Save',
          jsonBody: const {'properties': []},
          referer: '/workorder/detail/0',
          operation: 'Save (wrong content type, expect 599)',
        );
        fail('expected a BammApplicationException');
      } on BammApplicationException catch (e) {
        expect(e.statusCode, 599);
        expect(e.message, isNotEmpty);
      }
    });
  });
}
