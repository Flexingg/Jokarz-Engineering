/// Calendar-date <-> epoch-millisecond wire format for BAMM date properties
/// (property types 27/28).
///
/// Dates are pinned to midnight **UTC** for the given calendar date - never
/// the host's local time zone - so the same calendar date always encodes to
/// the same epoch-millisecond string, regardless of which server or which
/// side of a daylight-saving boundary the caller happens to run on. Mirrors
/// `~/repos/BAMM/app/projects/bamm_sync.py::date_to_epoch_ms` /
/// `epoch_ms_to_date`, which pin to UTC for exactly this reason (their own
/// `dto.coerce_value` parses naive local time, which was the bug they were
/// pinning against).
library;

import 'exceptions.dart';

final RegExp _epochMillis = RegExp(r'^\d+$');
final RegExp _dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _dateTime = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$');

/// Converts a `yyyy-mm-dd` (or full ISO datetime) string to an epoch-
/// millisecond string pinned to UTC midnight for that calendar date. A value
/// that is already all-digits is assumed to already be epoch millis and is
/// passed through unchanged.
///
/// Throws [BammFieldValidationException] - an input error, not a transport
/// one - for anything else.
String dateToEpochMs(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    throw const BammFieldValidationException('Date value is empty');
  }
  if (_epochMillis.hasMatch(text)) return text;

  final dateTimeMatch = _dateTime.firstMatch(text);
  if (dateTimeMatch != null) {
    final year = int.parse(dateTimeMatch.group(1)!);
    final month = int.parse(dateTimeMatch.group(2)!);
    final day = int.parse(dateTimeMatch.group(3)!);
    final hour = int.parse(dateTimeMatch.group(4)!);
    final minute = int.parse(dateTimeMatch.group(5)!);
    final second = int.parse(dateTimeMatch.group(6) ?? '0');
    final dt = DateTime.utc(year, month, day, hour, minute, second);
    _checkRoundTrips(dt, value, year: year, month: month, day: day);
    return dt.millisecondsSinceEpoch.toString();
  }

  final dateMatch = _dateOnly.firstMatch(text);
  if (dateMatch != null) {
    final year = int.parse(dateMatch.group(1)!);
    final month = int.parse(dateMatch.group(2)!);
    final day = int.parse(dateMatch.group(3)!);
    final dt = DateTime.utc(year, month, day);
    _checkRoundTrips(dt, value, year: year, month: month, day: day);
    return dt.millisecondsSinceEpoch.toString();
  }

  throw BammFieldValidationException('Invalid calendar date format: "$value"');
}

/// `DateTime.utc` silently normalises an out-of-range component instead of
/// throwing (`DateTime.utc(2026, 13, 40)` quietly becomes 2027-02-09) - unlike
/// Python's `strptime`, which the reference relies on to reject exactly this.
/// Round-tripping the parsed components catches what the constructor won't.
void _checkRoundTrips(DateTime dt, String original, {required int year, required int month, required int day}) {
  if (dt.year != year || dt.month != month || dt.day != day) {
    throw BammFieldValidationException('Invalid calendar date format: "$original"');
  }
}

/// The inverse of [dateToEpochMs]: reads an epoch-millisecond string/number
/// back as a UTC-pinned `yyyy-mm-dd`. Reading it as local time instead would
/// show yesterday's or tomorrow's date for users west/east of UTC near
/// midnight - the same class of bug [dateToEpochMs] pins against on the way in.
String epochMsToDate(String value) {
  final text = value.trim();
  final millis = int.tryParse(text);
  if (millis == null) return text;
  final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  final month = dt.month.toString().padLeft(2, '0');
  final day = dt.day.toString().padLeft(2, '0');
  return '${dt.year}-$month-$day';
}
