import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/bamm/mutations/dates.dart';
import 'package:jokarz_engineering/bamm/mutations/exceptions.dart';

void main() {
  group('dateToEpochMs', () {
    test('converts a calendar date to epoch millis pinned to UTC midnight', () {
      expect(dateToEpochMs('2026-01-01'), DateTime.utc(2026, 1, 1).millisecondsSinceEpoch.toString());
    });

    test('converts a full ISO datetime in UTC', () {
      expect(
        dateToEpochMs('2026-06-15T08:30:00'),
        DateTime.utc(2026, 6, 15, 8, 30, 0).millisecondsSinceEpoch.toString(),
      );
    });

    test('an already-epoch-millis string passes through unchanged', () {
      expect(dateToEpochMs('1789125391362'), '1789125391362');
    });

    test('rejects an unparseable date as an input error, not a crash', () {
      expect(() => dateToEpochMs('not-a-date'), throwsA(isA<BammFieldValidationException>()));
      expect(() => dateToEpochMs('2026-13-40'), throwsA(isA<BammFieldValidationException>()));
      expect(() => dateToEpochMs(''), throwsA(isA<BammFieldValidationException>()));
    });

    test('consecutive calendar dates are exactly 24h apart across a spring-forward DST boundary', () {
      // 2026-03-08 is the US spring-forward Sunday: local wall-clock time
      // skips from 02:00 to 03:00. A conversion that used local time instead
      // of pinning to UTC would encode this as a 23-hour day; UTC pinning
      // means it is always exactly 86,400,000ms, regardless of what
      // timezone the host running the tests is in.
      final before = int.parse(dateToEpochMs('2026-03-08'));
      final after = int.parse(dateToEpochMs('2026-03-09'));
      expect(after - before, Duration.millisecondsPerDay);
    });

    test('consecutive calendar dates are exactly 24h apart across a fall-back DST boundary', () {
      // 2026-11-01 is the US fall-back Sunday.
      final before = int.parse(dateToEpochMs('2026-11-01'));
      final after = int.parse(dateToEpochMs('2026-11-02'));
      expect(after - before, Duration.millisecondsPerDay);
    });
  });

  group('epochMsToDate', () {
    test('is the inverse of dateToEpochMs, read back as UTC', () {
      final ms = dateToEpochMs('2026-03-08');
      expect(epochMsToDate(ms), '2026-03-08');
    });

    test('reads near-midnight instants as the same UTC calendar day regardless of host timezone', () {
      // 1ms before UTC midnight on 2026-03-09 is still 2026-03-08 in UTC,
      // even though it would be 2026-03-09 already in timezones east of UTC.
      final oneMsBefore = DateTime.utc(2026, 3, 9).millisecondsSinceEpoch - 1;
      expect(epochMsToDate(oneMsBefore.toString()), '2026-03-08');
    });

    test('an unparseable value is returned unchanged rather than guessed', () {
      expect(epochMsToDate('garbage'), 'garbage');
    });
  });
}
