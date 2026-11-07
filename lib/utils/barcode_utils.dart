import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Code 128-B patterns for ASCII 32 to 127.
/// Each character consists of 6 numbers indicating the widths of 3 bars and 3 spaces (sum = 11).
const List<List<int>> _code128Patterns = [
  [2, 1, 2, 2, 2, 2], // 32 ' '
  [2, 2, 2, 1, 2, 2], // 33 '!'
  [2, 2, 2, 2, 2, 1], // 34 '"'
  [1, 2, 1, 2, 2, 3], // 35 '#'
  [1, 2, 1, 3, 2, 2], // 36 '$'
  [1, 3, 1, 2, 2, 2], // 37 '%'
  [1, 2, 2, 2, 1, 3], // 38 '&'
  [1, 2, 2, 3, 1, 2], // 39 '\''
  [1, 3, 2, 2, 1, 2], // 40 '('
  [2, 2, 1, 2, 1, 3], // 41 ')'
  [2, 2, 1, 3, 1, 2], // 42 '*'
  [2, 3, 1, 2, 1, 2], // 43 '+'
  [1, 1, 2, 2, 3, 2], // 44 ','
  [1, 2, 2, 1, 3, 2], // 45 '-'
  [1, 2, 2, 2, 3, 1], // 46 '.'
  [1, 1, 3, 2, 2, 2], // 47 '/'
  [1, 2, 3, 1, 2, 2], // 48 '0'
  [1, 2, 3, 2, 2, 1], // 49 '1'
  [2, 2, 3, 2, 1, 1], // 50 '2'
  [2, 2, 1, 1, 3, 2], // 51 '3'
  [2, 2, 1, 2, 3, 1], // 52 '4'
  [2, 1, 3, 2, 1, 2], // 53 '5'
  [2, 2, 3, 1, 1, 2], // 54 '6'
  [3, 1, 2, 1, 3, 1], // 55 '7'
  [3, 1, 1, 2, 2, 2], // 56 '8'
  [3, 2, 1, 1, 2, 2], // 57 '9'
  [3, 2, 1, 2, 2, 1], // 58 ':'
  [3, 1, 2, 2, 1, 2], // 59 ';'
  [3, 2, 2, 1, 1, 2], // 60 '<'
  [3, 2, 2, 2, 1, 1], // 61 '='
  [2, 1, 2, 1, 2, 3], // 62 '>'
  [2, 1, 2, 3, 2, 1], // 63 '?'
  [2, 3, 2, 1, 2, 1], // 64 '@'
  [1, 1, 1, 3, 2, 3], // 65 'A'
  [1, 3, 1, 1, 2, 3], // 66 'B'
  [1, 3, 1, 3, 2, 1], // 67 'C'
  [1, 1, 2, 3, 1, 3], // 68 'D'
  [1, 3, 2, 1, 1, 3], // 69 'E'
  [1, 3, 2, 3, 1, 1], // 70 'F'
  [2, 1, 1, 3, 1, 3], // 71 'G'
  [2, 3, 1, 1, 1, 3], // 72 'H'
  [2, 3, 1, 3, 1, 1], // 73 'I'
  [1, 1, 2, 1, 3, 3], // 74 'J'
  [1, 1, 2, 3, 3, 1], // 75 'K'
  [1, 3, 2, 1, 3, 1], // 76 'L'
  [1, 1, 3, 1, 2, 3], // 77 'M'
  [1, 1, 3, 3, 2, 1], // 78 'N'
  [1, 3, 3, 1, 2, 1], // 79 'O'
  [3, 1, 3, 1, 2, 1], // 80 'P'
  [2, 1, 1, 3, 3, 1], // 81 'Q'
  [2, 3, 1, 1, 3, 1], // 82 'R'
  [2, 1, 3, 1, 1, 3], // 83 'S'
  [2, 1, 3, 3, 1, 1], // 84 'T'
  [2, 1, 3, 1, 3, 1], // 85 'U'
  [3, 1, 1, 1, 2, 3], // 86 'V'
  [3, 1, 1, 3, 2, 1], // 87 'W'
  [3, 3, 1, 1, 2, 1], // 88 'X'
  [3, 1, 2, 1, 1, 3], // 89 'Y'
  [3, 1, 2, 3, 1, 1], // 90 'Z'
  [3, 3, 2, 1, 1, 1], // 91 '['
  [3, 1, 4, 1, 1, 1], // 92 '\'
  [2, 2, 1, 4, 1, 1], // 93 ']'
  [4, 3, 1, 1, 1, 1], // 94 '^'
  [1, 1, 1, 2, 2, 4], // 95 '_'
  [1, 1, 1, 4, 2, 2], // 96 '`'
  [1, 2, 1, 1, 2, 4], // 97 'a'
  [1, 2, 1, 4, 2, 1], // 98 'b'
  [1, 4, 1, 1, 2, 2], // 99 'c'
  [1, 4, 1, 2, 2, 1], // 100 'd'
  [1, 1, 2, 2, 1, 4], // 101 'e'
  [1, 1, 2, 4, 1, 2], // 102 'f'
  [1, 2, 2, 1, 1, 4], // 103 'g'
  [1, 2, 2, 4, 1, 1], // 104 'h'
  [1, 4, 2, 1, 1, 2], // 105 'i'
  [1, 4, 2, 2, 1, 1], // 106 'j'
  [2, 4, 1, 2, 1, 1], // 107 'k'
  [2, 2, 1, 1, 1, 4], // 108 'l'
  [4, 1, 3, 1, 1, 1], // 109 'm'
  [2, 4, 1, 1, 1, 2], // 110 'n'
  [1, 3, 4, 1, 1, 1], // 111 'o'
  [1, 1, 1, 2, 4, 2], // 112 'p'
  [1, 2, 1, 1, 4, 2], // 113 'q'
  [1, 2, 1, 2, 4, 1], // 114 'r'
  [1, 1, 4, 2, 1, 2], // 115 's'
  [1, 2, 4, 1, 1, 2], // 116 't'
  [1, 2, 4, 2, 1, 1], // 117 'u'
  [4, 1, 1, 2, 1, 2], // 118 'v'
  [4, 2, 1, 1, 1, 2], // 119 'w'
  [4, 2, 1, 2, 1, 1], // 120 'x'
  [2, 1, 2, 1, 4, 1], // 121 'y'
  [2, 1, 4, 1, 2, 1], // 122 'z'
  [4, 1, 2, 1, 2, 1], // 123 '{'
  [1, 1, 1, 1, 4, 3], // 124 '|'
  [1, 1, 1, 3, 4, 1], // 125 '}'
  [1, 3, 1, 1, 4, 1], // 126 '~'
  [1, 1, 4, 1, 1, 3], // 127 DEL
];

// Special Code 128 characters
const List<int> _startCodeB = [2, 1, 1, 2, 1, 4]; // Value 104
const List<int> _stopCode = [2, 3, 3, 1, 1, 1, 2]; // 7 elements, value 106

/// Converts a string into a list of boolean modules (true = black bar, false = white space)
/// using Code 128-B encoding.
List<bool> encodeCode128B(String text) {
  final clean = text.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  if (clean.isEmpty) return [];

  final modules = <bool>[];

  void addPattern(List<int> p) {
    for (int i = 0; i < p.length; i++) {
      final isBar = (i % 2 == 0);
      final count = p[i];
      for (int c = 0; c < count; c++) {
        modules.add(isBar);
      }
    }
  }

  // Quiet zone: 10 spaces
  for (int i = 0; i < 10; i++) modules.add(false);

  // Start Code B (val 104)
  addPattern(_startCodeB);
  int checksum = 104;

  for (int i = 0; i < clean.length; i++) {
    final codeUnit = clean.codeUnitAt(i);
    final val = codeUnit - 32;
    if (val >= 0 && val < _code128Patterns.length) {
      addPattern(_code128Patterns[val]);
      checksum += (val * (i + 1));
    }
  }

  final checkVal = checksum % 103;
  if (checkVal >= 0 && checkVal < _code128Patterns.length) {
    addPattern(_code128Patterns[checkVal]);
  }

  // Stop code
  addPattern(_stopCode);

  // Quiet zone
  for (int i = 0; i < 10; i++) modules.add(false);

  return modules;
}

/// Flutter Widget that renders a crisp 1D Barcode (Code 128)
class Barcode128Widget extends StatelessWidget {
  final String data;
  final double height;
  final double? width;
  final Color barColor;
  final bool showText;

  const Barcode128Widget({
    super.key,
    required this.data,
    this.height = 54,
    this.width,
    this.barColor = Colors.black,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final modules = encodeCode128B(data);
    if (modules.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(width ?? (modules.length * 1.5), height),
          painter: _BarcodePainter(modules: modules, barColor: barColor),
        ),
        if (showText) ...[
          const SizedBox(height: 3),
          Text(
            data,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontFamily: 'monospace',
              color: barColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final List<bool> modules;
  final Color barColor;

  const _BarcodePainter({required this.modules, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (modules.isEmpty) return;
    final moduleWidth = size.width / modules.length;
    final paint = Paint()..color = barColor;

    for (int i = 0; i < modules.length; i++) {
      if (modules[i]) {
        canvas.drawRect(
          Rect.fromLTWH(i * moduleWidth, 0, moduleWidth + 0.1, size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) {
    return oldDelegate.modules != modules || oldDelegate.barColor != barColor;
  }
}

/// Flutter Widget that renders a 2D QR Code using `package:qr/qr.dart`
class QrCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color color;

  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 80,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);

    return CustomPaint(
      size: Size(size, size),
      painter: _QrPainter(qrImage: qrImage, color: color),
    );
  }
}

class _QrPainter extends CustomPainter {
  final QrImage qrImage;
  final Color color;

  const _QrPainter({required this.qrImage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final moduleCount = qrImage.moduleCount;
    final moduleSize = size.width / moduleCount;
    final paint = Paint()..color = color;

    for (int row = 0; row < moduleCount; row++) {
      for (int col = 0; col < moduleCount; col++) {
        if (qrImage.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH(col * moduleSize, row * moduleSize, moduleSize + 0.1, moduleSize + 0.1),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) {
    return oldDelegate.qrImage != qrImage || oldDelegate.color != color;
  }
}
