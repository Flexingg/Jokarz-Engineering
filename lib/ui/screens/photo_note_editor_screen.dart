import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/voice_note.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';

/// Pick a photo, sketch red lines on it, add a caption, and save as a note.
class PhotoNoteEditorScreen extends ConsumerStatefulWidget {
  final String imagePath;
  const PhotoNoteEditorScreen({super.key, required this.imagePath});

  @override
  ConsumerState<PhotoNoteEditorScreen> createState() => _PhotoNoteEditorScreenState();
}

class _PhotoNoteEditorScreenState extends ConsumerState<PhotoNoteEditorScreen> {
  final _boundaryKey = GlobalKey();
  final _strokes = <List<Offset>>[];
  List<Offset> _current = [];
  final _captionCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getApplicationDocumentsDirectory();
      final photoFile = File('${dir.path}/jokarz_photo_${DateTime.now().millisecondsSinceEpoch}.png');
      await photoFile.writeAsBytes(bytes!.buffer.asUint8List());

      final caption = _captionCtrl.text.trim();
      final note = VoiceNote(
        title: caption.isEmpty ? 'Photo Note' : caption,
        transcript: caption,
        photoPath: photoFile.path,
      );
      await ref.read(projectProvider.notifier).addVoiceNote(note);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save photo note: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Note'),
        actions: [
          IconButton(
            tooltip: 'Undo stroke',
            onPressed: _strokes.isEmpty ? null : () => setState(() => _strokes.removeLast()),
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Clear lines',
            onPressed: _strokes.isEmpty ? null : () => setState(() => _strokes.clear()),
            icon: const Icon(Icons.layers_clear_outlined),
          ),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save Note'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: RepaintBoundary(
            key: _boundaryKey,
            child: Stack(children: [
              Positioned.fill(
                child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
              ),
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: (d) => setState(() {
                    _current = [d.localPosition];
                    _strokes.add(_current);
                  }),
                  onPanUpdate: (d) => setState(() => _current.add(d.localPosition)),
                  onPanEnd: (_) => _current = [],
                  child: CustomPaint(painter: _RedLinePainter(_strokes)),
                ),
              ),
              const Positioned(
                left: 12, top: 12,
                child: _HintBadge(),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _captionCtrl,
            decoration: const InputDecoration(
              labelText: 'Caption / note',
              hintText: 'Add text alongside the photo…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ]),
    );
  }
}

class _HintBadge extends StatelessWidget {
  const _HintBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
      child: const Text('Draw red lines on the photo', style: TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}

class _RedLinePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _RedLinePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentCoral
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RedLinePainter oldDelegate) => true;
}
