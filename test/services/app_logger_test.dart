import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/services/app_logger.dart';
import 'package:jokarz_engineering/ui/screens/diagnostics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => log.resetForTest());

  test('records levels, tags, errors and stack traces', () {
    log.info('t', 'hello');
    log.warn('t', 'careful', 'cause');
    log.error('t', 'boom', StateError('bad'), StackTrace.current);

    expect(log.entries.map((e) => e.level), [
      LogLevel.info,
      LogLevel.warning,
      LogLevel.error,
    ]);
    expect(log.errorCount, 1);
    final text = log.exportText();
    expect(text, contains('[INFO] t: hello'));
    expect(text, contains('error: cause'));
    expect(text, contains('Bad state: bad'));
  });

  test('ring buffer keeps only the newest entries', () {
    for (var i = 0; i < AppLogger.maxEntries + 25; i++) {
      log.info('t', 'm$i');
    }
    expect(log.entries.length, AppLogger.maxEntries);
    expect(log.entries.first.message, 'm25');
    expect(log.entries.last.message, 'm${AppLogger.maxEntries + 24}');
  });

  testWidgets('diagnostics screen lists entries and updates live', (
    tester,
  ) async {
    log.error('sync', 'first failure');
    await tester.pumpWidget(const MaterialApp(home: DiagnosticsScreen()));
    await tester.pump();
    expect(find.textContaining('first failure'), findsOneWidget);

    log.warn('storage', 'second thing');
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('second thing'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear log'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No log entries yet.'), findsOneWidget);
  });
}
