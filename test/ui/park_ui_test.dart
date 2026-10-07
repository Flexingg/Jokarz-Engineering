import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/order_item.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/ui/shell/park_scheduler.dart';
import 'package:jokarz_engineering/ui/widgets/park_dialog.dart';

import '../helpers/memory_storage.dart';

void main() {
  group('park dialog helpers', () {
    test('nextMonday is always strictly in the future and a Monday', () {
      for (var i = 0; i < 14; i++) {
        final d = DateTime(2026, 10, 1).add(Duration(days: i));
        final m = nextMonday(d);
        expect(m.weekday, DateTime.monday);
        expect(m.isAfter(d), isTrue, reason: '$d -> $m');
        expect(
          m.difference(DateTime(d.year, d.month, d.day)).inDays,
          lessThanOrEqualTo(7),
        );
      }
    });

    test(
      'nextOrderEta picks the earliest undelivered ETA that is not in the past',
      () {
        final now = DateTime(2026, 10, 7, 14);
        final p = Project(
          title: 'p',
          orders: [
            OrderItem(id: 'a', eta: DateTime(2026, 10, 5)), // past
            OrderItem(id: 'b', eta: DateTime(2026, 10, 12)),
            OrderItem(id: 'c', eta: DateTime(2026, 10, 9)),
            OrderItem(id: 'd', eta: DateTime(2026, 10, 8), delivered: true),
            OrderItem(id: 'e'), // no ETA
          ],
        );
        expect(nextOrderEta(p, now), DateTime(2026, 10, 9));
        expect(nextOrderEta(Project(title: 'x'), now), isNull);
      },
    );

    test('parkBadgeText', () {
      final p = Project(
        title: 'x',
        priority: 5,
        parkedUntil: DateTime(2026, 10, 10),
        parkRestorePriority: 2,
      );
      expect(parkBadgeText(p), 'Parked until Sat, Oct 10 · back to #2');
      expect(parkBadgeText(Project(title: 'y')), '');
    });
  });

  testWidgets('the park dialog returns the chosen date and reason', (
    tester,
  ) async {
    final project = Project(title: 'Gearbox', priority: 2);
    ParkChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showParkDialog(
                context,
                project,
                now: DateTime(2026, 10, 7),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Park this project'), findsOneWidget);
    expect(find.textContaining('comes back to #2'), findsOneWidget);
    // Park is disabled until a date is picked.
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Park'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Next Monday'));
    await tester.ensureVisible(find.text('Downtime window'));
    await tester.tap(find.text('Downtime window'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Park'));
    await tester.pumpAndSettle();

    expect(result!.until, DateTime(2026, 10, 12));
    expect(result!.reason, 'Downtime window');
  });

  testWidgets(
    '"when the next order arrives" is offered only when there is one',
    (tester) async {
      final withEta = Project(
        title: 'A',
        orders: [OrderItem(id: 'o', eta: DateTime(2026, 10, 14))],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showParkDialog(context, withEta, now: DateTime(2026, 10, 7)),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('When the next order arrives (Wed, Oct 14)'),
        findsOneWidget,
      );
    },
  );

  testWidgets('returning to the foreground brings a due project back', (
    tester,
  ) async {
    var clock = DateTime(2026, 10, 7, 9);
    final storage = MemoryStorage(
      projects: [
        Project(id: 'a', title: 'Alpha', priority: 1),
        Project(id: 'b', title: 'Beta', priority: 2),
      ],
    );
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ParkScheduler(clock: () => clock, child: const Text('app')),
          ),
        ),
      ),
    );
    container.read(projectProvider); // start loading
    while (container.read(projectProvider).isLoading) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    await container
        .read(projectProvider.notifier)
        .parkProject('a', DateTime(2026, 10, 9));
    expect(container.read(projectProvider).activeProjects.map((p) => p.id), [
      'b',
      'a',
    ]);

    clock = DateTime(2026, 10, 9, 8); // the app slept through to the 9th
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(container.read(projectProvider).activeProjects.map((p) => p.id), [
      'a',
      'b',
    ]);
  });
}
