import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/ui/widgets/app_footer.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo _info(String version, String build) => PackageInfo(
      appName: 'jokarz_engineering',
      packageName: 'com.example.jokarz_engineering',
      version: version,
      buildNumber: build,
    );

void main() {
  test('formatVersion', () {
    expect(formatVersion(_info('1.6.0', '28')), '1.6.0 (build 28)');
    expect(formatVersion(_info('1.6.0', '')), '1.6.0');
    expect(formatVersion(null), '');
  });

  test('release notes link points at this version, else the releases list', () {
    expect(releaseNotesUri(_info('1.6.0', '28')).toString(),
        'https://github.com/Flexingg/Jokarz-Engineering/releases/tag/v1.6.0');
    expect(releaseNotesUri(null).toString(), kReleasesUrl);
  });

  testWidgets('shows the app name and the real version, with no old blurb', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AppFooter(loadInfo: () async => _info('1.6.0', '28'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('AOR Engineering'), findsOneWidget);
    expect(find.text('Version 1.6.0 (build 28)'), findsOneWidget);
    expect(find.text('Release notes'), findsOneWidget);
    expect(find.text('Diagnostics log'), findsOneWidget);
    expect(find.textContaining('BATO'), findsNothing);
    expect(find.textContaining('1.0.3'), findsNothing);
  });

  testWidgets('a platform that cannot report a version still renders', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AppFooter(loadInfo: () async => throw Exception('no plugin'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('AOR Engineering'), findsOneWidget);
    expect(find.textContaining('Version'), findsNothing);
  });
}
