import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'app_logger.dart';

/// Desktop window behaviour: a sensible minimum size, and the last size,
/// position and maximized state restored on the next launch. A no-op on
/// Android/iOS/web, and never allowed to stop the app from starting.
class WindowService with WindowListener {
  WindowService._();
  static final WindowService instance = WindowService._();

  /// Smallest size at which the desktop layout (rail + content) still works.
  static const Size minimumSize = Size(960, 640);
  static const Size defaultSize = Size(1360, 860);
  static const String fileName = 'jokarz_window.json';

  Timer? _debounce;

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<File> _file() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/$fileName');

  Future<void> init() async {
    if (!_isDesktop) return;
    try {
      await windowManager.ensureInitialized();
      final saved = await _load();
      final options = WindowOptions(
        size: saved?.size ?? defaultSize,
        minimumSize: minimumSize,
        center: saved?.position == null,
        title: 'Jokarz Engineering',
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        final pos = saved?.position;
        if (pos != null && await _isOnAScreen(pos)) {
          await windowManager.setPosition(pos);
        } else if (pos != null) {
          await windowManager.center();
        }
        if (saved?.maximized ?? false) await windowManager.maximize();
        await windowManager.show();
        await windowManager.focus();
      });
      windowManager.addListener(this);
    } catch (e, stack) {
      log.error('window', 'Window setup failed; continuing with defaults', e, stack);
    }
  }

  /// A saved position from a monitor that is no longer attached would open the
  /// window off-screen.
  Future<bool> _isOnAScreen(Offset p) async {
    try {
      for (final d in await screenRetriever.getAllDisplays()) {
        final o = d.visiblePosition ?? Offset.zero;
        final s = d.visibleSize ?? d.size;
        if (p.dx >= o.dx - 20 &&
            p.dy >= o.dy - 20 &&
            p.dx < o.dx + s.width - 100 &&
            p.dy < o.dy + s.height - 100) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<({Size size, Offset? position, bool maximized})?> _load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final w = (j['w'] as num?)?.toDouble();
      final h = (j['h'] as num?)?.toDouble();
      if (w == null || h == null || w < minimumSize.width || h < minimumSize.height) {
        return null;
      }
      final x = (j['x'] as num?)?.toDouble();
      final y = (j['y'] as num?)?.toDouble();
      return (
        size: Size(w, h),
        position: x == null || y == null ? null : Offset(x, y),
        maximized: j['maximized'] as bool? ?? false,
      );
    } catch (e) {
      log.warn('window', 'Could not read saved window bounds', e);
      return null;
    }
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    try {
      final maximized = await windowManager.isMaximized();
      final f = await _file();
      // While maximized keep the last restored bounds so un-maximizing later
      // (or relaunching) returns to a sensible size.
      Map<String, dynamic> j = {};
      if (await f.exists()) {
        try {
          j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        } catch (_) {}
      }
      if (!maximized) {
        final b = await windowManager.getBounds();
        j
          ..['x'] = b.left
          ..['y'] = b.top
          ..['w'] = b.width
          ..['h'] = b.height;
      }
      j['maximized'] = maximized;
      await f.writeAsString(jsonEncode(j), flush: true);
    } catch (e) {
      log.warn('window', 'Could not save window bounds', e);
    }
  }

  /// Forgets the saved bounds and recenters at the default size.
  Future<void> reset() async {
    if (!_isDesktop) return;
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
      await windowManager.unmaximize();
      await windowManager.setSize(defaultSize);
      await windowManager.center();
    } catch (e) {
      log.warn('window', 'Could not reset window', e);
    }
  }

  @override
  void onWindowResized() => _scheduleSave();
  @override
  void onWindowMoved() => _scheduleSave();
  @override
  void onWindowMaximize() => _scheduleSave();
  @override
  void onWindowUnmaximize() => _scheduleSave();
}
