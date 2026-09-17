// Item 4: the local "search everything already loaded" mode - multi-token
// AND across every field (including hidden columns), case-insensitive, and
// dates must match both their displayed form and their spoken forms.
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/services/bamm_local_search.dart';

void main() {
  group('matchesBammLocalSearch / filterBammWorkOrdersLocally', () {
    // The exact scenario from the batch brief: work done, responsible, and a
    // registered date, found by tokens drawn from all three, one of them a
    // spoken month name rather than the raw date.
    final tireHammer = BammWorkOrder(
      worId: 1,
      worNoSeq: '1',
      description: 'Flat tire on cart',
      workDone: 'hit tire with hammer',
      responsible: 'Jonathan Randall',
      issueDate: DateTime(2026, 9, 17),
    );
    final other = BammWorkOrder(
      worId: 2,
      worNoSeq: '2',
      description: 'Unrelated work order',
      workDone: 'replaced bearing',
      responsible: 'Someone Else',
      issueDate: DateTime(2026, 1, 5),
    );

    test('multi-token AND across work done, responsible, and a spoken date form all matches', () {
      expect(matchesBammLocalSearch(tireHammer, 'Randall hammer September'), isTrue);
      expect(matchesBammLocalSearch(other, 'Randall hammer September'), isFalse);
    });

    test('case-insensitive', () {
      expect(matchesBammLocalSearch(tireHammer, 'RANDALL HAMMER'), isTrue);
    });

    test('a date matches its displayed form and every spoken/short form', () {
      for (final token in ['9/17/26', '9/17/2026', 'September', 'Sep', '09-17', 'Sep 17, 2026']) {
        expect(matchesBammLocalSearch(tireHammer, token), isTrue, reason: '"$token" should match the 2026-09-17 issue date');
      }
    });

    test('a missing token (present on neither field) excludes the row', () {
      expect(matchesBammLocalSearch(tireHammer, 'Randall hammer October'), isFalse);
    });

    test('matches a hidden (not-default-visible) field: EM Priority', () {
      final wo = BammWorkOrder(worId: 3, worNoSeq: '3', description: 'x', priority: '17.5');
      expect(matchesBammLocalSearch(wo, '17.5'), isTrue);
    });

    test('a blank query matches everything', () {
      expect(matchesBammLocalSearch(tireHammer, ''), isTrue);
      expect(matchesBammLocalSearch(tireHammer, '   '), isTrue);
    });

    test('filterBammWorkOrdersLocally narrows the list and returns it unchanged for a blank query', () {
      final rows = [tireHammer, other];
      expect(filterBammWorkOrdersLocally(rows, 'Randall hammer').map((w) => w.worId), [1]);
      expect(filterBammWorkOrdersLocally(rows, ''), same(rows));
    });
  });
}
