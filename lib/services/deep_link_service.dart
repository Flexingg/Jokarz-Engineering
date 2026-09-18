/// Inbound deep links from a printed report's QR code
/// (`aor-report://wo?id=<worId>&h=<snapshotHash>&t=<printedAtEpochMs>`) -
/// Android only (see `.hermes/plans/2026-09-17_time-blocking-and-reports.md`
/// §0 for why Windows protocol registration is out of scope).
library;

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

const String deepLinkScheme = 'aor-report';

/// Pure parsing: translates a scanned `aor-report://wo?...` URI into the
/// in-app route that opens it, or `null` for anything this app doesn't
/// recognize (a different scheme/host, or a malformed link - never a crash).
String? parseDeepLinkUri(Uri uri) {
  if (uri.scheme != deepLinkScheme || uri.host != 'wo') return null;
  final id = uri.queryParameters['id'];
  if (id == null || id.trim().isEmpty) return null;

  final params = <String>['wo=$id'];
  final hash = uri.queryParameters['h'];
  if (hash != null && hash.isNotEmpty) params.add('h=$hash');
  final printedAt = uri.queryParameters['t'];
  if (printedAt != null && printedAt.isNotEmpty) params.add('t=$printedAt');

  return '/bamm?${params.join('&')}';
}

/// Builds the deep-link URI a printed report's QR code encodes for [worId].
String buildDeepLinkUri({required int worId, required String snapshotHash, required DateTime printedAt}) {
  return '$deepLinkScheme://wo?id=$worId&h=$snapshotHash&t=${printedAt.millisecondsSinceEpoch}';
}

/// Wires the real `app_links` stream (+ cold-start initial link) to
/// [router]. Not unit-tested directly (it's a thin platform-channel glue
/// layer) - [parseDeepLinkUri] carries the actual logic and IS tested.
Future<void> initDeepLinks(GoRouter router) async {
  final appLinks = AppLinks();

  final initial = await appLinks.getInitialLink();
  if (initial != null) {
    final route = parseDeepLinkUri(initial);
    if (route != null) router.go(route);
  }

  appLinks.uriLinkStream.listen((uri) {
    final route = parseDeepLinkUri(uri);
    if (route != null) router.go(route);
  });
}
