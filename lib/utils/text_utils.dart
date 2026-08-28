/// Capitalizes the first letter of each word and lowercases the rest
/// (title case). Used when creating a project from search text.
String titleCase(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// Splits a machine field on `/` or `,` into individual machine names.
List<String> splitMachines(String input) => input
    .split(RegExp(r'[/,]'))
    .map((m) => m.trim())
    .where((m) => m.isNotEmpty)
    .toList();

/// Decodes any literal `\uXXXX` escape sequences (e.g. left over from a
/// double-encoded JSON import) into their real characters.
String decodeUnicodeEscapes(String input) {
  if (!input.contains(r'\u')) return input;
  final buffer = StringBuffer();
  var i = 0;
  while (i < input.length) {
    if (input[i] == r'\' && i + 1 < input.length && input[i + 1] == 'u') {
      final end = i + 6 <= input.length ? i + 6 : input.length;
      final hex = input.substring(i + 2, end);
      if (hex.length == 4 && int.tryParse(hex, radix: 16) != null) {
        buffer.writeCharCode(int.parse(hex, radix: 16));
        i += 6;
        continue;
      }
    }
    buffer.write(input[i]);
    i++;
  }
  return buffer.toString();
}
