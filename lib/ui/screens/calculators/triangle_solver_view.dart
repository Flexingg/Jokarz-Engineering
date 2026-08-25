import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

class TriangleSolverView extends StatefulWidget {
  const TriangleSolverView({super.key});

  @override
  State<TriangleSolverView> createState() => _TriangleSolverViewState();
}

class _TriangleSolverViewState extends State<TriangleSolverView> {
  final _aCtrl = TextEditingController(text: '3');
  final _bCtrl = TextEditingController(text: '4');
  final _cCtrl = TextEditingController(text: '5');
  final _angleACtrl = TextEditingController();
  final _angleBCtrl = TextEditingController();
  final _angleCCtrl = TextEditingController();

  double? _sideA, _sideB, _sideC;
  double? _angleA, _angleB, _angleC; // in degrees
  double? _area, _perimeter;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _solve();
  }

  @override
  void dispose() {
    _aCtrl.dispose();
    _bCtrl.dispose();
    _cCtrl.dispose();
    _angleACtrl.dispose();
    _angleBCtrl.dispose();
    _angleCCtrl.dispose();
    super.dispose();
  }

  double _radToDeg(double rad) => rad * (180.0 / math.pi);
  double _degToRad(double deg) => deg * (math.pi / 180.0);

  void _solve() {
    final a = double.tryParse(_aCtrl.text.trim());
    final b = double.tryParse(_bCtrl.text.trim());
    final c = double.tryParse(_cCtrl.text.trim());
    final A = double.tryParse(_angleACtrl.text.trim());
    final B = double.tryParse(_angleBCtrl.text.trim());
    final C = double.tryParse(_angleCCtrl.text.trim());

    setState(() {
      _errorMsg = null;
      _sideA = _sideB = _sideC = null;
      _angleA = _angleB = _angleC = null;
      _area = _perimeter = null;

      try {
        // Case 1: Three Sides (SSS)
        if (a != null && b != null && c != null) {
          if (a + b <= c || a + c <= b || b + c <= a) {
            _errorMsg = 'Triangle Inequality Violation (Sum of any two sides must exceed third).';
            return;
          }
          final cosA = ((b * b) + (c * c) - (a * a)) / (2 * b * c);
          final cosB = ((a * a) + (c * c) - (b * b)) / (2 * a * c);
          final angleA = _radToDeg(math.acos(cosA.clamp(-1.0, 1.0)));
          final angleB = _radToDeg(math.acos(cosB.clamp(-1.0, 1.0)));
          final angleC = 180.0 - angleA - angleB;

          _setSolution(a, b, c, angleA, angleB, angleC);
        }
        // Case 2: Two Sides and Included Angle (SAS)
        else if (a != null && b != null && C != null) {
          final cCalc = math.sqrt((a * a) + (b * b) - (2 * a * b * math.cos(_degToRad(C))));
          final cosA = ((b * b) + (cCalc * cCalc) - (a * a)) / (2 * b * cCalc);
          final angleA = _radToDeg(math.acos(cosA.clamp(-1.0, 1.0)));
          final angleB = 180.0 - angleA - C;
          _setSolution(a, b, cCalc, angleA, angleB, C);
        } else if (a != null && c != null && B != null) {
          final bCalc = math.sqrt((a * a) + (c * c) - (2 * a * c * math.cos(_degToRad(B))));
          final cosA = ((bCalc * bCalc) + (c * c) - (a * a)) / (2 * bCalc * c);
          final angleA = _radToDeg(math.acos(cosA.clamp(-1.0, 1.0)));
          final angleC = 180.0 - angleA - B;
          _setSolution(a, bCalc, c, angleA, B, angleC);
        } else if (b != null && c != null && A != null) {
          final aCalc = math.sqrt((b * b) + (c * c) - (2 * b * c * math.cos(_degToRad(A))));
          final cosB = ((aCalc * aCalc) + (c * c) - (b * b)) / (2 * aCalc * c);
          final angleB = _radToDeg(math.acos(cosB.clamp(-1.0, 1.0)));
          final angleC = 180.0 - A - angleB;
          _setSolution(aCalc, b, c, A, angleB, angleC);
        }
        // Case 3: One Side and Two Angles (ASA / AAS)
        else if (A != null && B != null && (a != null || b != null || c != null)) {
          final angleC = 180.0 - A - B;
          if (angleC <= 0) {
            _errorMsg = 'Sum of angles must be less than 180°.';
            return;
          }
          double sideA = a ?? 0;
          double sideB = b ?? 0;
          double sideC = c ?? 0;

          if (a != null) {
            sideB = a * math.sin(_degToRad(B)) / math.sin(_degToRad(A));
            sideC = a * math.sin(_degToRad(angleC)) / math.sin(_degToRad(A));
          } else if (b != null) {
            sideA = b * math.sin(_degToRad(A)) / math.sin(_degToRad(B));
            sideC = b * math.sin(_degToRad(angleC)) / math.sin(_degToRad(B));
          } else if (c != null) {
            sideA = c * math.sin(_degToRad(A)) / math.sin(_degToRad(angleC));
            sideB = c * math.sin(_degToRad(B)) / math.sin(_degToRad(angleC));
          }
          _setSolution(sideA, sideB, sideC, A, B, angleC);
        } else if (A != null && C != null && (a != null || b != null || c != null)) {
          final angleB = 180.0 - A - C;
          if (angleB <= 0) {
            _errorMsg = 'Sum of angles must be less than 180°.';
            return;
          }
          double sideA = a ?? (c! * math.sin(_degToRad(A)) / math.sin(_degToRad(C)));
          double sideB = b ?? (c != null
              ? (c * math.sin(_degToRad(angleB)) / math.sin(_degToRad(C)))
              : (a! * math.sin(_degToRad(angleB)) / math.sin(_degToRad(A))));
          double sideC = c ?? (a! * math.sin(_degToRad(C)) / math.sin(_degToRad(A)));
          _setSolution(sideA, sideB, sideC, A, angleB, C);
        } else if (B != null && C != null && (a != null || b != null || c != null)) {
          final angleA = 180.0 - B - C;
          if (angleA <= 0) {
            _errorMsg = 'Sum of angles must be less than 180°.';
            return;
          }
          double sideA = a ?? (b != null
              ? (b * math.sin(_degToRad(angleA)) / math.sin(_degToRad(B)))
              : (c! * math.sin(_degToRad(angleA)) / math.sin(_degToRad(C))));
          double sideB = b ?? (c! * math.sin(_degToRad(B)) / math.sin(_degToRad(C)));
          double sideC = c ?? (b! * math.sin(_degToRad(C)) / math.sin(_degToRad(B)));
          _setSolution(sideA, sideB, sideC, angleA, B, C);
        }
        // Case 4: Right Triangle Shortcuts (e.g. Hypotenuse + Side, or Angle 90)
        else if (C == 90 || (_angleCCtrl.text.isEmpty && A == null && B == null && a != null && b != null)) {
          // Default right triangle if 2 legs entered
          final cCalc = math.sqrt((a! * a) + (b! * b));
          final angleA = _radToDeg(math.atan2(a, b));
          final angleB = 90.0 - angleA;
          _setSolution(a, b, cCalc, angleA, angleB, 90.0);
        } else {
          _errorMsg = 'Please enter at least 3 values (including at least 1 side).';
        }
      } catch (e) {
        _errorMsg = 'Could not solve triangle with given parameters.';
      }
    });
  }

  void _setSolution(double a, double b, double c, double A, double B, double C) {
    _sideA = a;
    _sideB = b;
    _sideC = c;
    _angleA = A;
    _angleB = B;
    _angleC = C;
    _perimeter = a + b + c;
    final s = _perimeter! / 2.0;
    _area = math.sqrt(s * (s - a) * (s - b) * (s - c));
  }

  void _setRightTrianglePreset() {
    _aCtrl.text = '3';
    _bCtrl.text = '4';
    _cCtrl.text = '5';
    _angleACtrl.clear();
    _angleBCtrl.clear();
    _angleCCtrl.clear();
    _solve();
  }

  void _setEquilateralPreset() {
    _aCtrl.text = '10';
    _bCtrl.text = '10';
    _cCtrl.text = '10';
    _angleACtrl.clear();
    _angleBCtrl.clear();
    _angleCCtrl.clear();
    _solve();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Info Card
          ExpressiveCard(
            child: Row(
              children: [
                const Icon(Icons.change_history_rounded, color: AppTheme.primaryCyan, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Triangle Trigonometry Solver',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Enter any 3 parameters (SSS, SAS, ASA, AAS). Solves all angles, side lengths, area, and perimeter.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Preset Buttons
          Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.square_foot_rounded, size: 14),
                label: const Text('3-4-5 Right Triangle', style: TextStyle(fontSize: 11)),
                onPressed: _setRightTrianglePreset,
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.all_inclusive_rounded, size: 14),
                label: const Text('Equilateral (60°)', style: TextStyle(fontSize: 11)),
                onPressed: _setEquilateralPreset,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Inputs Grid (Sides & Angles)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sides
              Expanded(
                child: ExpressiveCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SIDES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryCyan)),
                      const SizedBox(height: 8),
                      _buildNumField(_aCtrl, 'Side a', 'e.g. 3'),
                      const SizedBox(height: 8),
                      _buildNumField(_bCtrl, 'Side b', 'e.g. 4'),
                      const SizedBox(height: 8),
                      _buildNumField(_cCtrl, 'Side c', 'e.g. 5'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Angles
              Expanded(
                child: ExpressiveCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ANGLES (Degrees °)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentAmber)),
                      const SizedBox(height: 8),
                      _buildNumField(_angleACtrl, 'Angle A (°)', 'e.g. 36.87'),
                      const SizedBox(height: 8),
                      _buildNumField(_angleBCtrl, 'Angle B (°)', 'e.g. 53.13'),
                      const SizedBox(height: 8),
                      _buildNumField(_angleCCtrl, 'Angle C (°)', 'e.g. 90'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _solve,
                  icon: const Icon(Icons.calculate_rounded),
                  label: const Text('Solve Triangle'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {
                  _aCtrl.clear();
                  _bCtrl.clear();
                  _cCtrl.clear();
                  _angleACtrl.clear();
                  _angleBCtrl.clear();
                  _angleCCtrl.clear();
                  setState(() {
                    _sideA = _sideB = _sideC = null;
                    _angleA = _angleB = _angleC = null;
                    _area = _perimeter = null;
                    _errorMsg = null;
                  });
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Error Message
          if (_errorMsg != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentCoral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.accentCoral),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.accentCoral, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: AppTheme.accentCoral, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Solution Results & Visual Canvas
          if (_sideA != null && _angleA != null) ...[
            ExpressiveCard(
              isGlowing: true,
              glowColor: AppTheme.accentEmerald,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CALCULATED GEOMETRY',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentEmerald),
                      ),
                      ExpressiveBadge(label: 'Solved', color: AppTheme.accentEmerald, fontSize: 10),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Results Table
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Side a: ${_sideA!.toStringAsFixed(4)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Side b: ${_sideB!.toStringAsFixed(4)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Side c: ${_sideC!.toStringAsFixed(4)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Angle A: ${_angleA!.toStringAsFixed(2)}°', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentAmber)),
                            Text('Angle B: ${_angleB!.toStringAsFixed(2)}°', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentAmber)),
                            Text('Angle C: ${_angleC!.toStringAsFixed(2)}°', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentAmber)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Area: ${_area?.toStringAsFixed(4) ?? "N/A"} sq units', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      Text('Perimeter: ${_perimeter?.toStringAsFixed(4) ?? "N/A"} units', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Triangle Visual Canvas
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: CustomPaint(
                      painter: _TrianglePainter(
                        a: _sideA!,
                        b: _sideB!,
                        c: _sideC!,
                        angleA: _angleA!,
                        angleB: _angleB!,
                        angleC: _angleC!,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumField(TextEditingController ctrl, String label, String hint) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      onChanged: (_) => _solve(),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final double a, b, c;
  final double angleA, angleB, angleC;
  final bool isDark;

  _TrianglePainter({
    required this.a,
    required this.b,
    required this.c,
    required this.angleA,
    required this.angleB,
    required this.angleC,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (a <= 0 || b <= 0 || c <= 0) return;

    final paintStroke = Paint()
      ..color = AppTheme.primaryCyan
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final paintFill = Paint()
      ..color = AppTheme.primaryCyan.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    // Node A at (0, 0), Node B at (c, 0), Node C at (b * cosA, b * sinA)
    final radA = angleA * (math.pi / 180.0);
    final cx = b * math.cos(radA);
    final cy = b * math.sin(radA);

    final minX = math.min(0.0, math.min(c, cx));
    final maxX = math.max(0.0, math.max(c, cx));
    final minY = math.min(0.0, math.min(0.0, cy));
    final maxY = math.max(0.0, math.max(0.0, cy));

    final triWidth = (maxX - minX);
    final triHeight = (maxY - minY);

    final padding = 30.0;
    final scaleX = (size.width - (padding * 2)) / (triWidth > 0 ? triWidth : 1);
    final scaleY = (size.height - (padding * 2)) / (triHeight > 0 ? triHeight : 1);
    final scale = math.min(scaleX, scaleY);

    final offsetX = padding + ((size.width - (padding * 2) - (triWidth * scale)) / 2);
    final offsetY = size.height - padding - ((size.height - (padding * 2) - (triHeight * scale)) / 2);

    final pA = Offset(offsetX + (0 - minX) * scale, offsetY - (0 - minY) * scale);
    final pB = Offset(offsetX + (c - minX) * scale, offsetY - (0 - minY) * scale);
    final pC = Offset(offsetX + (cx - minX) * scale, offsetY - (cy - minY) * scale);

    final path = Path()
      ..moveTo(pA.dx, pA.dy)
      ..lineTo(pB.dx, pB.dy)
      ..lineTo(pC.dx, pC.dy)
      ..close();

    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintStroke);

    // Draw vertex dots
    final dotPaint = Paint()..color = AppTheme.accentAmber;
    canvas.drawCircle(pA, 4, dotPaint);
    canvas.drawCircle(pB, 4, dotPaint);
    canvas.drawCircle(pC, 4, dotPaint);

    // Labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    void drawLabel(String text, Offset pos, Color col) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2));
    }

    drawLabel('A (${angleA.toStringAsFixed(1)}°)', Offset(pA.dx - 12, pA.dy + 12), AppTheme.accentAmber);
    drawLabel('B (${angleB.toStringAsFixed(1)}°)', Offset(pB.dx + 12, pB.dy + 12), AppTheme.accentAmber);
    drawLabel('C (${angleC.toStringAsFixed(1)}°)', Offset(pC.dx, pC.dy - 12), AppTheme.accentAmber);

    drawLabel('c = ${c.toStringAsFixed(2)}', Offset((pA.dx + pB.dx) / 2, pA.dy + 12), isDark ? Colors.white70 : Colors.black87);
    drawLabel('a = ${a.toStringAsFixed(2)}', Offset((pB.dx + pC.dx) / 2 + 12, (pB.dy + pC.dy) / 2), isDark ? Colors.white70 : Colors.black87);
    drawLabel('b = ${b.toStringAsFixed(2)}', Offset((pA.dx + pC.dx) / 2 - 12, (pA.dy + pC.dy) / 2), isDark ? Colors.white70 : Colors.black87);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => true;
}
