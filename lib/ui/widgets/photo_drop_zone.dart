import 'dart:io' show Platform;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/project_provider.dart';
import '../../services/app_logger.dart';
import '../../theme/app_theme.dart';

const _imageExtensions = {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'};

/// Lets a user drag image files from the desktop onto a project to attach them
/// as photos. A plain pass-through on phones and tablets.
class PhotoDropZone extends ConsumerStatefulWidget {
  final String projectId;
  final Widget child;
  const PhotoDropZone({
    super.key,
    required this.projectId,
    required this.child,
  });

  @override
  ConsumerState<PhotoDropZone> createState() => _PhotoDropZoneState();
}

class _PhotoDropZoneState extends ConsumerState<PhotoDropZone> {
  bool _over = false;

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> _onDrop(DropDoneDetails details) async {
    setState(() => _over = false);
    final notifier = ref.read(projectProvider.notifier);
    var added = 0;
    var skipped = 0;
    for (final f in details.files) {
      final ext = f.path.split('.').last.toLowerCase();
      if (!_imageExtensions.contains(ext)) {
        skipped++;
        continue;
      }
      try {
        await notifier.addProjectPhoto(widget.projectId, f.path);
        added++;
      } catch (e, stack) {
        log.error('drop', 'Could not attach dropped photo', e, stack);
        skipped++;
      }
    }
    if (!mounted) return;
    final msg = added == 0
        ? 'No photos attached. Drop PNG, JPG, WebP, GIF or BMP images.'
        : 'Attached $added photo${added == 1 ? '' : 's'}${skipped > 0 ? ' ($skipped skipped)' : ''}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return widget.child;
    final colors = AppTheme.of(context);
    return DropTarget(
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: _onDrop,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _over ? 1 : 0,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.background.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.primary, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Drop photos to attach to this project',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
