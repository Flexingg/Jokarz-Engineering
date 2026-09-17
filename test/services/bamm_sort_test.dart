// Bug 4: BAMM's real server ignores `orderByFields` (see
// BAMM/captures/*.har for WorkOrderOpenOnAssetList) - these prove the local
// comparator that replaces it: blanks always sort last regardless of
// direction, and numeric/date columns compare by magnitude, not string.
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/bamm_models.dart';
import 'package:jokarz_engineering/services/bamm_sort.dart';

BammWorkOrder _wo({
  required int id,
  DateTime? issueDate,
  String priority = '',
  String description = '',
  String assembly = '',
  String area = '',
}) =>
    BammWorkOrder(
      worId: id,
      worNoSeq: '$id',
      description: description,
      issueDate: issueDate,
      priority: priority,
      assembly: assembly,
      area: area,
    );

void main() {
  group('compareBammWorkOrders', () {
    test('date column: ascending orders earliest first', () {
      final a = _wo(id: 1, issueDate: DateTime(2026, 1, 3));
      final b = _wo(id: 2, issueDate: DateTime(2026, 1, 1));
      expect(compareBammWorkOrders(a, b, 'woIssueDate', ascending: true), greaterThan(0));
      expect(compareBammWorkOrders(b, a, 'woIssueDate', ascending: true), lessThan(0));
    });

    test('date column: a null date always sorts last, in both directions', () {
      final withDate = _wo(id: 1, issueDate: DateTime(2026, 1, 1));
      final withoutDate = _wo(id: 2, issueDate: null);
      expect(compareBammWorkOrders(withoutDate, withDate, 'woIssueDate', ascending: true), greaterThan(0));
      expect(compareBammWorkOrders(withoutDate, withDate, 'woIssueDate', ascending: false), greaterThan(0));
      expect(compareBammWorkOrders(withDate, withoutDate, 'woIssueDate', ascending: false), lessThan(0));
    });

    test('numeric column (worNumber3 / EM Priority): compares by magnitude, not string', () {
      final low = _wo(id: 1, priority: '2');
      final high = _wo(id: 2, priority: '10');
      // String comparison would put "10" before "2" - magnitude must not.
      expect(compareBammWorkOrders(low, high, 'worNumber3', ascending: true), lessThan(0));
    });

    test('numeric column: a blank priority always sorts last, in both directions', () {
      final withPriority = _wo(id: 1, priority: '5');
      final blank = _wo(id: 2, priority: '');
      expect(compareBammWorkOrders(blank, withPriority, 'worNumber3', ascending: true), greaterThan(0));
      expect(compareBammWorkOrders(blank, withPriority, 'worNumber3', ascending: false), greaterThan(0));
    });

    test('text column: natural/numeric-aware ("WO-9" before "WO-10")', () {
      final nine = _wo(id: 1, description: 'WO-9');
      final ten = _wo(id: 2, description: 'WO-10');
      expect(compareBammWorkOrders(nine, ten, 'woDescription', ascending: true), lessThan(0));
    });

    test('text column: a blank description always sorts last', () {
      final withText = _wo(id: 1, description: 'Bearing replacement');
      final blank = _wo(id: 2, description: '');
      expect(compareBammWorkOrders(blank, withText, 'woDescription', ascending: true), greaterThan(0));
      expect(compareBammWorkOrders(blank, withText, 'woDescription', ascending: false), greaterThan(0));
    });

    test('both blank: equal', () {
      final a = _wo(id: 1);
      final b = _wo(id: 2);
      expect(compareBammWorkOrders(a, b, 'woDescription', ascending: true), 0);
    });

    test('Assembly column (funCodeLevelNiv4Description) sorts like any other text column', () {
      final a = _wo(id: 1, assembly: 'Fill Head 9');
      final b = _wo(id: 2, assembly: 'Fill Head 10');
      // Natural compare: "9" before "10" by magnitude, not string order.
      expect(compareBammWorkOrders(a, b, 'funCodeLevelNiv4Description', ascending: true), lessThan(0));
      final blank = _wo(id: 3);
      expect(compareBammWorkOrders(blank, a, 'funCodeLevelNiv4Description', ascending: true), greaterThan(0),
          reason: 'a blank assembly always sorts last');
    });

    test('Area column (funCodeLevelNiv1Description, the 1st-level function code) sorts like any other text column', () {
      final a = _wo(id: 1, area: 'Packaging 9');
      final b = _wo(id: 2, area: 'Packaging 10');
      // Natural compare: "9" before "10" by magnitude, not string order.
      expect(compareBammWorkOrders(a, b, 'funCodeLevelNiv1Description', ascending: true), lessThan(0));
      final blank = _wo(id: 3);
      expect(compareBammWorkOrders(blank, a, 'funCodeLevelNiv1Description', ascending: true), greaterThan(0),
          reason: 'a blank area always sorts last');
    });
  });

  group('sortBammWorkOrders', () {
    test('sorts a copy, blanks last, respects ascending/descending', () {
      final rows = [
        _wo(id: 1, priority: '3'),
        _wo(id: 2, priority: ''),
        _wo(id: 3, priority: '1'),
        _wo(id: 4, priority: '2'),
      ];

      final asc = sortBammWorkOrders(rows, 'worNumber3', true);
      expect(asc.map((w) => w.worId), [3, 4, 1, 2], reason: 'ascending by magnitude, blank last');

      final desc = sortBammWorkOrders(rows, 'worNumber3', false);
      expect(desc.map((w) => w.worId), [1, 4, 3, 2], reason: 'descending by magnitude, blank STILL last');

      // Original list is untouched.
      expect(rows.map((w) => w.worId), [1, 2, 3, 4]);
    });

    test('a null field leaves the input order unchanged', () {
      final rows = [_wo(id: 2), _wo(id: 1)];
      expect(sortBammWorkOrders(rows, null, true), same(rows));
    });
  });
}
