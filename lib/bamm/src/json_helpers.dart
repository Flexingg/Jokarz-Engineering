/// Small numeric coercions shared by the BAMM parsers.
///
/// BAMM's JSON is inconsistent about whether a number arrives as a JSON
/// number or a numeric string, so every module that reads a raw response
/// needs the same tolerant conversion.
library;

int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
