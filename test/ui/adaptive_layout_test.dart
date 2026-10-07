import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/ui/adaptive/breakpoints.dart';
import 'package:jokarz_engineering/ui/adaptive/master_detail.dart';

Future<void> _pumpAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdaptiveMasterDetail(
          list: const Text('LIST'),
          detailBuilder: (_) => const Text('DETAIL'),
        ),
      ),
    ),
  );
}

void main() {
  test('breakpoint classes sit on the Material 3 boundaries', () {
    expect(Breakpoints.classify(599), WindowSizeClass.compact);
    expect(Breakpoints.classify(600), WindowSizeClass.medium);
    expect(Breakpoints.classify(839), WindowSizeClass.medium);
    expect(Breakpoints.classify(840), WindowSizeClass.expanded);
    expect(Breakpoints.isAtLeastMedium(600), isTrue);
    expect(Breakpoints.isAtLeastMedium(599), isFalse);
  });

  testWidgets(
    'master-detail shows only the list on compact and medium windows',
    (tester) async {
      await _pumpAt(tester, 500);
      expect(find.text('LIST'), findsOneWidget);
      expect(find.text('DETAIL'), findsNothing);

      await _pumpAt(tester, 800);
      expect(find.text('DETAIL'), findsNothing);
    },
  );

  testWidgets('master-detail shows both panes on expanded windows', (
    tester,
  ) async {
    await _pumpAt(tester, 1200);
    expect(find.text('LIST'), findsOneWidget);
    expect(find.text('DETAIL'), findsOneWidget);
  });
}
