import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/task_item.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/ui/screens/project_detail_screen.dart';

import '../helpers/memory_storage.dart';

Future<ProviderContainer> _pump(WidgetTester tester, {Size size = const Size(1500, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final storage = MemoryStorage(
    projects: [
      Project(
        id: 'p1',
        title: 'Replace Gearbox',
        category: ProjectCategory.maintenance,
        phase: 'Installation',
        priority: 1,
        machine: 'Line 3',
        notes: 'first note',
        tasks: [TaskItem(id: 't1', description: 'Align gearbox')],
      ),
    ],
  );
  final c = ProviderContainer(overrides: [storageServiceProvider.overrideWithValue(storage)]);
  addTearDown(c.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: const MaterialApp(home: ProjectDetailScreen(projectId: 'p1')),
  ));
  await tester.pumpAndSettle();
  return c;
}

Project _p(ProviderContainer c) => c.read(projectProvider).projects.first;

void main() {
  group('project detail side panels', () {
    testWidgets('desktop: clicking a header field opens the editor, autosaves on blur', (tester) async {
      final c = await _pump(tester);
      await tester.tap(find.textContaining('Line 3'));
      await tester.pumpAndSettle();
      expect(find.text('Project details'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final machine = find.widgetWithText(TextField, 'Machine / Line');
      await tester.enterText(machine, 'Line 4');
      await tester.pump();
      expect(_p(c).machine, 'Line 3', reason: 'not saved yet');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(_p(c).machine, 'Line 4');
      expect(find.text('Project details'), findsNothing);
    });

    testWidgets('desktop: notes edit saves after an idle pause', (tester) async {
      final c = await _pump(tester);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'updated note');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(_p(c).notes, 'updated note');
    });

    testWidgets('desktop: task edit opens a panel and saves edits', (tester) async {
      final c = await _pump(tester);
      await tester.tap(find.descendant(of: find.byType(ReorderableListView), matching: find.byIcon(Icons.edit_outlined)));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Task Description *'), 'Align new gearbox');
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(_p(c).tasks.single.description, 'Align new gearbox');
    });

    testWidgets('keyboard: Down + Space checks the task, Enter opens its editor', (tester) async {
      final c = await _pump(tester);
      await tester.tap(find.text('Align gearbox')); // clicking the list gives it the keyboard
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_p(c).tasks.single.isCompleted, isTrue);
      expect(_p(c).tasks.single.completedAt, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Task Description *'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Task Description *'), findsNothing);
    });

    testWidgets('keyboard: F puts the highlighted task on the fab list', (tester) async {
      final c = await _pump(tester);
      await tester.tap(find.text('Align gearbox'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(c.read(projectProvider).fabJobs.single.taskId, 't1');
    });

    testWidgets('phone keeps the dialog', (tester) async {
      await _pump(tester, size: const Size(400, 800));
      await tester.tap(find.textContaining('Line 3'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
