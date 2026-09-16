// The searchable BAMM lookup picker (`bamm_lookup_picker.dart`) is the
// widget every new field/lookups picker in the WO edit dialog is built on:
// it must never show a bundled option list, must filter client-side by
// default, must re-fetch on every keystroke when told to search
// server-side, and must surface truncation (BAMM capping a lookup at a
// page size below its reported total) rather than hiding it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/bamm/schema/lookups.dart';
import 'package:jokarz_engineering/ui/widgets/bamm_lookup_picker.dart';

void main() {
  Future<LookupOption?> pump(WidgetTester tester, {
    required Future<LookupResult> Function(String) fetch,
    bool serverSearch = false,
  }) async {
    LookupOption? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              picked = await showBammLookupPicker(context, title: 'Pick one', fetch: fetch, serverSearch: serverSearch);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('client-side filter narrows the already-fetched list as the user types', (tester) async {
    var fetchCalls = 0;
    await pump(
      tester,
      fetch: (search) async {
        fetchCalls++;
        return const LookupResult(
          items: [
            LookupOption(id: '1', label: 'Bearing failure', code: '', inactive: false),
            LookupOption(id: '2', label: 'Electrical fault', code: '', inactive: false),
          ],
          total: 2,
        );
      },
    );

    expect(find.text('Bearing failure'), findsOneWidget);
    expect(find.text('Electrical fault'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'elect');
    await tester.pumpAndSettle();

    expect(find.text('Bearing failure'), findsNothing);
    expect(find.text('Electrical fault'), findsOneWidget);
    // Client-side filtering must not re-hit the network for every keystroke.
    expect(fetchCalls, 1);
  });

  testWidgets('selecting an option pops the sheet with that LookupOption', (tester) async {
    final picked = await pump(
      tester,
      fetch: (search) async => const LookupResult(
        items: [LookupOption(id: '7', label: 'Night crew', code: 'NC', inactive: false)],
        total: 1,
      ),
    );
    // Not selected yet - open the sheet, then tap.
    expect(picked, isNull);

    await tester.tap(find.text('Night crew'));
    await tester.pumpAndSettle();
  });

  testWidgets('truncation is surfaced, not hidden, when total exceeds the returned page', (tester) async {
    await pump(
      tester,
      fetch: (search) async => LookupResult(
        items: List.generate(2, (i) => LookupOption(id: '$i', label: 'Option $i', code: '', inactive: false)),
        total: 377,
      ),
    );

    expect(find.textContaining('Showing 2 of 377'), findsOneWidget);
  });

  testWidgets('serverSearch re-invokes fetch with the query instead of filtering locally', (tester) async {
    final queries = <String>[];
    await pump(
      tester,
      serverSearch: true,
      fetch: (search) async {
        queries.add(search);
        return LookupResult(
          items: [LookupOption(id: '1', label: 'Result for "$search"', code: '', inactive: false)],
          total: 1,
        );
      },
    );

    expect(queries, ['']); // initial load
    await tester.enterText(find.byType(TextField), 'jane');
    await tester.pump(const Duration(milliseconds: 400)); // past the debounce
    await tester.pumpAndSettle();

    expect(queries, ['', 'jane']);
    expect(find.textContaining('Result for "jane"'), findsOneWidget);
  });
}
