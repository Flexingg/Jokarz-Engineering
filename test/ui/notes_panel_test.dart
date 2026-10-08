import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/ui/screens/voice_notes_screen.dart';

import '../helpers/memory_storage.dart';

Future<ProviderContainer> _pump(WidgetTester tester, {Size size = const Size(1500, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final storage = MemoryStorage(
    projects: [Project(id: 'p1', title: 'Gearbox', notes: 'project note body')],
    voiceNotes: [VoiceNote(id: 'n1', title: 'Bearing clearance', transcript: 'looks tight')],
  );
  final c = ProviderContainer(overrides: [storageServiceProvider.overrideWithValue(storage)]);
  addTearDown(c.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: const MaterialApp(home: VoiceNotesScreen()),
  ));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('desktop: tapping a note opens the editor and autosaves on close', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.text('Bearing clearance'));
    await tester.pumpAndSettle();
    expect(find.text('Field note'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Engineering Notes & Observations'), 'too tight, shim 0.2');
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(c.read(projectProvider).voiceNotes.single.transcript, 'too tight, shim 0.2');
  });

  testWidgets('desktop: switching notes saves the first', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.text('Bearing clearance'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Note Title *'), 'Bearing clearance v2');
    await tester.pump();
    await tester.tap(find.text('Gearbox').first);
    await tester.pumpAndSettle();
    expect(find.text('Project notes'), findsOneWidget);
    expect(c.read(projectProvider).voiceNotes.single.title, 'Bearing clearance v2');
  });

  testWidgets('desktop: project note edits write to the project', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.byTooltip('Edit Project Notes'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'revised');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(c.read(projectProvider).projects.single.notes, 'revised');
  });

  testWidgets('phone keeps the edit dialog', (tester) async {
    await _pump(tester, size: const Size(400, 800));
    await tester.tap(find.byTooltip('Edit Note'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
