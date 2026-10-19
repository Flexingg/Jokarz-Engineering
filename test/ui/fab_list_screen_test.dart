import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/fab_job.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/ui/screens/fab_list_screen.dart';

import '../helpers/memory_storage.dart';

Future<ProviderContainer> _pump(WidgetTester tester, {Size size = const Size(1500, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final storage = MemoryStorage(fabJobs: [
    FabJob(id: 'a', title: 'Guard plates', who: 'Sam', dueDate: DateTime(2030, 1, 5), drawingPath: r'\\srv\dwg\J-1', notes: 'rush'),
    FabJob(id: 'b', title: 'Bracket', who: 'Dana', dueDate: DateTime(2030, 1, 2)),
    FabJob(id: 'c', title: 'Old job', status: FabStatus.completed),
  ]);
  final c = ProviderContainer(overrides: [storageServiceProvider.overrideWithValue(storage)]);
  addTearDown(c.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: const MaterialApp(home: FabListScreen()),
  ));
  await tester.pumpAndSettle();
  return c;
}

FabJob _job(ProviderContainer c, String id) => c.read(projectProvider).fabJobs.firstWhere((j) => j.id == id);

void main() {
  testWidgets('shows open jobs soonest-due first with all the columns', (tester) async {
    await _pump(tester);
    for (final h in ['JOB', 'WHO', 'DUE', 'STARTED', 'DRAWINGS', 'NOTES', 'STATUS']) {
      expect(find.text(h), findsOneWidget);
    }
    expect(find.text('Old job'), findsNothing, reason: 'completed jobs are filtered out of Open');
    expect(tester.getTopLeft(find.text('Bracket')).dy < tester.getTopLeft(find.text('Guard plates')).dy, isTrue);
    expect(find.text(r'\\srv\dwg\J-1'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Old job'), findsOneWidget);
    expect(find.text('Bracket'), findsNothing);
  });

  testWidgets('status chip changes status and stamps the start date', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.text('Pending').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('In progress').last);
    await tester.pumpAndSettle();
    final changed = c.read(projectProvider).fabJobs.where((j) => j.status == FabStatus.inProgress);
    expect(changed, hasLength(1));
    expect(changed.single.startedDate, isNotNull);
  });

  testWidgets('clicking a row edits it in the side panel and autosaves', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.text('Guard plates'));
    await tester.pumpAndSettle();
    expect(find.text('Fab job'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Who'), 'Priya');
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(_job(c, 'a').who, 'Priya');
  });

  testWidgets('keyboard: arrows move, S cycles status, Enter opens, Esc closes', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.byType(Scaffold).first, warnIfMissed: false);
    // Focus the list: click the search-less area by sending keys to the focused KeyNav.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    // Rows are Bracket (0) then Guard plates (1); the highlight is on row 1.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
    expect(_job(c, 'a').status, FabStatus.inProgress);
    expect(_job(c, 'b').status, FabStatus.pending);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Fab job'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Fab job'), findsNothing);
  });

  testWidgets('typing in the search box never triggers list keys', (tester) async {
    final c = await _pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Search'), 'sss');
    await tester.pump();
    expect(c.read(projectProvider).fabJobs.every((j) => j.status != FabStatus.inProgress), isTrue);
  });
}
