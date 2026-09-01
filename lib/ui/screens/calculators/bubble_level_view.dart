import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../theme/app_theme.dart';

/// A phone-sensor bubble level (uses the accelerometer). Works on devices that
/// expose a linear/accelerometer sensor (Android/iOS); on desktop it shows a
/// friendly "no sensor" message.
class BubbleLevelView extends StatefulWidget {
  const BubbleLevelView({super.key});

  @override
  State<BubbleLevelView> createState() => _BubbleLevelViewState();
}

class _BubbleLevelViewState extends State<BubbleLevelView> {
  static const double _maxAngle = 10; // degrees for full bubble travel
  static const double _levelThreshold = 0.5; // degrees considered "level"

  StreamSubscription<AccelerometerEvent>? _sub;
  double _roll = 0; // left-right tilt, degrees (+ = right side down)
  double _pitch = 0; // front-back tilt, degrees (+ = top down)
  bool _available = false;
  bool _waiting = true;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    try {
      _sub = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        final x = event.x, y = event.y, z = event.z;
        // Angle of tilt in each axis relative to gravity.
        final roll =
            math.atan2(x, math.sqrt(y * y + z * z)) * 180 / math.pi;
        final pitch =
            math.atan2(y, math.sqrt(x * x + z * z)) * 180 / math.pi;
        setState(() {
          _roll = roll;
          _pitch = pitch;
          _available = true;
          _waiting = false;
        });
      }, onError: (_) {
        if (mounted) {
          setState(() {
            _available = false;
            _waiting = false;
          });
        }
      });

      // If no sensor event arrives, assume unsupported platform.
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _waiting) {
          setState(() {
            _available = false;
            _waiting = false;
          });
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _available = false;
          _waiting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get _isLevel => _available &&
      _roll.abs() < _levelThreshold &&
      _pitch.abs() < _levelThreshold;

  String _signed(double v) =>
      '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}°';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_waiting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Waiting for sensor…'),
                ]),
              ),
            )
          else if (!_available)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                const Icon(Icons.sensors_off_rounded,
                    size: 48, color: AppTheme.accentCoral),
                const SizedBox(height: 12),
                const Text('Accelerometer not available on this device',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'The bubble level needs a phone/tablet with an accelerometer. '
                  'It is not available on desktop.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary),
                ),
              ]),
            )
          else ...[
            // Status banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _isLevel
                    ? AppTheme.accentEmerald.withValues(alpha: 0.18)
                    : AppTheme.accentAmber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isLevel ? Icons.check_circle_rounded : Icons.info_outline,
                    size: 18,
                    color: _isLevel
                        ? AppTheme.accentEmerald
                        : AppTheme.accentAmber,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isLevel
                        ? 'LEVEL — bubble is centered'
                        : 'Hold steady and center the bubble',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isLevel
                            ? AppTheme.accentEmerald
                            : AppTheme.accentAmber),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Bubble vial
            Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: CustomPaint(
                  painter: _BubbleLevelPainter(
                    roll: _roll,
                    pitch: _pitch,
                    maxAngle: _maxAngle,
                    isLevel: _isLevel,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Readouts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _readout('LEFT / RIGHT', _signed(_roll)),
                _readout('FRONT / BACK', _signed(_pitch)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tip: lay the phone flat on the surface, or against the edge for '
              'a vertical reading. Green = within ±0.5°.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _readout(String label, String value) {
    return Column(children: [
      Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryCyan)),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
    ]);
  }
}

class _BubbleLevelPainter extends CustomPainter {
  final double roll;
  final double pitch;
  final double maxAngle;
  final bool isLevel;
  final bool isDark;

  _BubbleLevelPainter({
    required this.roll,
    required this.pitch,
    required this.maxAngle,
    required this.isLevel,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final bubbleRadius = 26.0;
    final accent = isLevel ? AppTheme.accentEmerald : AppTheme.accentCoral;
    final outline = isDark ? Colors.white38 : Colors.black38;

    // Vial face
    final vialPaint = Paint()
      ..color = isDark ? const Color(0xFF16232f) : Colors.black12
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, vialPaint);
    final rimPaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, rimPaint);

    // Crosshair lines
    final linePaint = Paint()
      ..color = outline
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), linePaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), linePaint);

    // Center target ring
    final targetPaint = Paint()
      ..color = accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 20, targetPaint);

    // Bubble offset from tilt (sign: when right/top goes down, bubble shifts left/up)
    final travel = radius - bubbleRadius - 6;
    final dx = (roll / maxAngle).clamp(-1.0, 1.0) * -travel;
    final dy = (pitch / maxAngle).clamp(-1.0, 1.0) * -travel;
    final bubbleCenter = center + Offset(dx, dy);

    // Bubble
    final bubblePaint = Paint()
      ..color = accent
      ..shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: 0.95),
        accent,
      ]).createShader(Rect.fromCircle(center: bubbleCenter, radius: bubbleRadius));
    canvas.drawCircle(bubbleCenter, bubbleRadius, bubblePaint);
    final bubbleRim = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(bubbleCenter, bubbleRadius, bubbleRim);
  }

  @override
  bool shouldRepaint(covariant _BubbleLevelPainter old) =>
      old.roll != roll || old.pitch != pitch || old.isLevel != isLevel;
}
