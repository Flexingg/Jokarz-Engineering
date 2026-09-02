import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/project_provider.dart';
import '../../../models/voice_note.dart';

/// A phone-sensor bubble level. Uses the accelerometer for left/right (roll)
/// and front/back (pitch) tilt, and the magnetometer for rotation/heading
/// (the "third axis"). Supports zeroing (offset to current reading), returning
/// to true zero, and building a labeled note of measurements by holding the
/// Record button for ~1s at each point.
class BubbleLevelView extends ConsumerStatefulWidget {
  const BubbleLevelView({super.key});

  @override
  ConsumerState<BubbleLevelView> createState() => _BubbleLevelViewState();
}

class _LevelPoint {
  final String label;
  final double roll;
  final double pitch;
  final double heading;
  final DateTime at;
  _LevelPoint(this.label, this.roll, this.pitch, this.heading, this.at);
}

class _BubbleLevelViewState extends ConsumerState<BubbleLevelView> {
  static const double _maxAngle = 10; // degrees for full bubble travel
  static const double _levelThreshold = 0.5; // degrees considered "level"

  StreamSubscription<AccelerometerEvent>? _sub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  Timer? _holdTimer;

  bool _available = false;
  bool _waiting = true;
  bool _headingOk = false;
  bool _holding = false;

  double _rawRoll = 0; // left-right tilt, degrees (+ = right side down)
  double _rawPitch = 0; // front-back tilt, degrees (+ = top down)
  double _rawHeading = 0; // compass heading, 0-360 (rotation / third axis)

  double _rollOffset = 0; // zeroed-offset so current reading shows 0
  double _pitchOffset = 0;
  double _headingOffset = 0;

  // Magnetometer calibration feedback: smoothed magnitude of change between
  // samples. High while the phone is moving (figure-8), low when still.
  final ValueNotifier<double> _magMotion = ValueNotifier<double>(0);
  (double, double, double)? _lastMagVec;

  final List<_LevelPoint> _points = [];
  final TextEditingController _noteTitleCtrl =
      TextEditingController(text: 'Level Measurements');

  double get _roll => _rawRoll - _rollOffset;
  double get _pitch => _rawPitch - _pitchOffset;
  double get _heading {
    var h = _rawHeading - _headingOffset;
    while (h > 180) {
      h -= 360;
    }
    while (h < -180) {
      h += 360;
    }
    return h;
  }

  bool get _isLevel =>
      _available &&
      _roll.abs() < _levelThreshold &&
      _pitch.abs() < _levelThreshold;

  bool get _isZeroed =>
      _rollOffset.abs() > 0.01 || _pitchOffset.abs() > 0.01 || _headingOffset.abs() > 0.01;

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
        final roll = math.atan2(x, math.sqrt(y * y + z * z)) * 180 / math.pi;
        final pitch = math.atan2(y, math.sqrt(x * x + z * z)) * 180 / math.pi;
        setState(() {
          _rawRoll = roll;
          _rawPitch = pitch;
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

      // Magnetometer gives the rotation/heading (third) axis.
      _magSub = magnetometerEventStream().listen((event) {
        if (!mounted) return;
        var h = math.atan2(event.y, event.x) * 180 / math.pi;
        if (h < 0) h += 360;
        // Track sample-to-sample vector change to sense figure-8 motion.
        final vec = (event.x, event.y, event.z);
        double delta = 0;
        final last = _lastMagVec;
        if (last != null) {
          delta = math.sqrt(math.pow(vec.$1 - last.$1, 2) +
              math.pow(vec.$2 - last.$2, 2) +
              math.pow(vec.$3 - last.$3, 2));
        }
        _lastMagVec = vec;
        _magMotion.value = _magMotion.value * 0.85 + delta * 0.15;
        setState(() {
          _rawHeading = h;
          _headingOk = true;
        });
      }, onError: (_) {});

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
    _magSub?.cancel();
    _holdTimer?.cancel();
    _noteTitleCtrl.dispose();
    _magMotion.dispose();
    super.dispose();
  }

  String _signed(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}°';
  String _headingStr() =>
      _headingOk ? '${_heading >= 0 ? '+' : ''}${_heading.toStringAsFixed(0)}°' : 'n/a';

  void _zero() => setState(() {
        _rollOffset = _rawRoll;
        _pitchOffset = _rawPitch;
        _headingOffset = _rawHeading;
      });

  void _resetZero() => setState(() {
        _rollOffset = 0;
        _pitchOffset = 0;
        _headingOffset = 0;
      });

  void _openCalibration() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _CalibrationSheet(motion: _magMotion),
    );
  }

  void _startHold() {
    if (!_available || _holding) return;
    setState(() => _holding = true);
    _holdTimer = Timer(const Duration(seconds: 1), _snapshotPoint);
  }

  void _endHold() {
    if (_holding) setState(() => _holding = false);
    _holdTimer?.cancel();
  }

  Future<void> _snapshotPoint() async {
    if (!mounted) return;
    setState(() => _holding = false);
    final roll = _roll, pitch = _pitch, heading = _heading;
    final labelCtrl =
        TextEditingController(text: 'Point ${_points.length + 1}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Label measurement'),
        content: TextField(
          controller: labelCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Point label',
            hintText: 'e.g. Mounting bracket, front',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    final text = saved == true ? labelCtrl.text.trim() : '';
    labelCtrl.dispose();
    if (saved == true && mounted) {
      setState(() => _points.add(_LevelPoint(
            text.isEmpty ? 'Point ${_points.length + 1}' : text,
            roll,
            pitch,
            heading,
            DateTime.now(),
          )));
    }
  }

  Future<void> _saveNote() async {
    if (_points.isEmpty) return;
    final sb = StringBuffer('Level measurement points (${_points.length}):\n');
    for (var i = 0; i < _points.length; i++) {
      final p = _points[i];
      sb.writeln(
          '${i + 1}. ${p.label} — L/R ${p.roll.toStringAsFixed(1)}°, '
          'F/B ${p.pitch.toStringAsFixed(1)}°, Rot ${p.heading.toStringAsFixed(0)}°');
    }
    final note = VoiceNote(
      title: _noteTitleCtrl.text.trim().isEmpty
          ? 'Level Measurements'
          : _noteTitleCtrl.text.trim(),
      transcript: sb.toString().trim(),
    );
    await ref.read(projectProvider.notifier).addVoiceNote(note);
    if (!mounted) return;
    setState(() => _points.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved note: ${note.title}')),
    );
  }

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
                Icon(Icons.sensors_off_rounded,
                    size: 48, color: AppTheme.of(context).coral),
                const SizedBox(height: 12),
                const Text('Accelerometer not available on this device',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'The bubble level needs a phone/tablet with an accelerometer. '
                  'It is not available on desktop.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.of(context).textSecondary),
                ),
              ]),
            )
          else ...[
            // Status banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: (_isLevel ? AppTheme.of(context).emerald : AppTheme.of(context).amber)
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isLevel ? Icons.check_circle_rounded : Icons.info_outline,
                    size: 18,
                    color: _isLevel
                        ? AppTheme.of(context).emerald
                        : AppTheme.of(context).amber,
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
                            ? AppTheme.of(context).emerald
                            : AppTheme.of(context).amber),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Bubble vial
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
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
            // Readouts (left/right, front/back, rotation)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _readout('LEFT / RIGHT', _signed(_roll)),
                _readout('FRONT / BACK', _signed(_pitch)),
                _readout('ROTATION', _headingStr(), dim: !_headingOk),
              ],
            ),
            if (_isZeroed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: Text('Zeroed — readings are relative',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.of(context).primary)),
                ),
              ),
            const SizedBox(height: 12),
            // Zero / Reset controls
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _zero,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Zero'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetZero,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('True Zero'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openCalibration,
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: Text(_headingOk
                  ? 'Calibrate Compass (Rotation)'
                  : 'Compass Unavailable'),
            ),
            const SizedBox(height: 16),
            // Record measurement
            _buildRecordSection(),
            const SizedBox(height: 10),
            Text(
              'Tip: lay the phone flat (or against the edge for vertical). '
              'Zero first, then hold Record ~1s at each point on the assembly — '
              'repeat as you move around to compare where it is out of level.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.of(context).textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordSection() {
    final c = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hold-to-record button
        GestureDetector(
          onTapDown: (_) => _startHold(),
          onTapUp: (_) => _endHold(),
          onTapCancel: _endHold,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _holding
                  ? c.coral.withValues(alpha: 0.9)
                  : c.primary.withValues(alpha: 0.12),
              border: Border.all(color: c.primary, width: 2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _holding ? Icons.fiber_manual_record : Icons.radio_button_checked,
                  color: _holding ? Colors.white : c.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _holding ? 'Holding… release to keep' : 'Hold ~1s to Record Point',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _holding ? Colors.white : c.primary),
                ),
              ],
            ),
          ),
        ),
        if (_points.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceCard,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _noteTitleCtrl,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Note title',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ..._points.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${i + 1}. ${p.label}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Text(
                          '${p.roll.toStringAsFixed(1)}° / ${p.pitch.toStringAsFixed(1)}° / ${p.heading.toStringAsFixed(0)}°',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.of(context).textSecondary),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _points.clear()),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saveNote,
                        icon: const Icon(Icons.save_alt_rounded, size: 18),
                        label: Text('Save Note (${_points.length})'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _readout(String label, String value, {bool dim = false}) {
    return Column(children: [
      Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: dim
                  ? AppTheme.of(context).textSecondary
                  : AppTheme.of(context).primary)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: dim ? AppTheme.of(context).textSecondary : null)),
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
    final bubbleRadius = 24.0;
    final accent = isLevel ? AppTheme.of().emerald : AppTheme.of().coral;
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
    canvas.drawCircle(center, 18, targetPaint);

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

/// Bottom sheet guiding magnetometer calibration (figure-8) with live feedback
/// based on detected phone motion.
class _CalibrationSheet extends StatelessWidget {
  final ValueListenable<double> motion;
  const _CalibrationSheet({required this.motion});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.explore_rounded, color: c.primary),
              const SizedBox(width: 10),
              const Text('Magnetometer Calibration',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 10),
            Text(
              'The ROTATION axis reads the phone compass, which uses the '
              'magnetometer. It can drift near metal, tools, or after travel. '
              'Re-calibrate by tracing a figure-8:',
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            _step(context, '1', 'Hold the phone roughly flat (face up).'),
            _step(context, '2',
                'Trace a figure-8 in the air, slowly, 3–4 times.'),
            _step(context, '3',
                'Keep going until the indicator below shows motion.'),
            const SizedBox(height: 16),
            ValueListenableBuilder<double>(
              valueListenable: motion,
              builder: (context, v, _) {
                final moving = v > 2.5;
                final bar = (v / 20).clamp(0.0, 1.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: bar,
                        minHeight: 10,
                        color: moving ? c.emerald : c.amber,
                        backgroundColor: c.surfaceHighlight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(
                        moving
                            ? Icons.motion_photos_on_rounded
                            : Icons.motion_photos_off_rounded,
                        size: 18,
                        color: moving ? c.emerald : c.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          moving
                              ? 'Motion detected — keep tracing figure-8s'
                              : 'No movement — move the phone',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: moving ? c.emerald : c.amber,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'There is no app API to force calibration — the phone '
                      're-baselines its compass automatically as it sees this '
                      'pattern. After a few figure-8s, re-zero the rotation and '
                      'the heading should be stable.',
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(BuildContext context, String n, String text) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$n.', style: TextStyle(fontWeight: FontWeight.bold, color: c.primary)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.3))),
        ],
      ),
    );
  }
}
