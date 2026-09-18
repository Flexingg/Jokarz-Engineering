// Pure parsing coverage for inbound deep links from a printed report's QR
// code - the platform-channel wiring (`initDeepLinks`) is thin glue and not
// unit-tested; this is the logic that actually decides where a scanned
// link goes.
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/services/deep_link_service.dart';

void main() {
  group('parseDeepLinkUri', () {
    test('a full link with hash and printed-at timestamp routes to /bamm with all three params', () {
      final uri = Uri.parse('aor-report://wo?id=700203549&h=a1b2c3d4&t=1234567890');
      expect(parseDeepLinkUri(uri), '/bamm?wo=700203549&h=a1b2c3d4&t=1234567890');
    });

    test('a link with only id (no hash/timestamp) still routes', () {
      final uri = Uri.parse('aor-report://wo?id=700203549');
      expect(parseDeepLinkUri(uri), '/bamm?wo=700203549');
    });

    test('missing id -> not recognized', () {
      final uri = Uri.parse('aor-report://wo?h=a1b2c3d4');
      expect(parseDeepLinkUri(uri), isNull);
    });

    test('wrong scheme -> not recognized (never hijacks an unrelated link)', () {
      final uri = Uri.parse('https://wo?id=700203549');
      expect(parseDeepLinkUri(uri), isNull);
    });

    test('wrong host -> not recognized', () {
      final uri = Uri.parse('aor-report://something-else?id=700203549');
      expect(parseDeepLinkUri(uri), isNull);
    });
  });

  group('buildDeepLinkUri', () {
    test('round-trips through parseDeepLinkUri to the expected route', () {
      final built = buildDeepLinkUri(worId: 700203549, snapshotHash: 'deadbeef', printedAt: DateTime(2026, 9, 17, 8, 0));
      final parsed = parseDeepLinkUri(Uri.parse(built));
      expect(parsed, contains('wo=700203549'));
      expect(parsed, contains('h=deadbeef'));
    });
  });
}
