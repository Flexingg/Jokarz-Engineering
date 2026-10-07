import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final String? error;
  final String? stack;

  const LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stack,
  });

  /// Single-block text form used for the on-disk log and for sharing.
  String format() {
    final b = StringBuffer(
      '${time.toIso8601String()} [${level.name.toUpperCase()}] $tag: $message',
    );
    if (error != null) b.write('\n  error: $error');
    if (stack != null)
      b.write('\n  stack: ${stack!.trim().replaceAll('\n', '\n         ')}');
    return b.toString();
  }
}

/// Central app logger.
///
/// Keeps a bounded in-memory ring buffer (so Settings can show it live) and
/// best-effort appends to `jokarz_diagnostics.log` in the documents directory
/// (rotated once it passes [maxFileBytes]). Logging never throws and never
/// touches the disk in tests unless [attachFile] is called.
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int maxEntries = 500;
  static const int maxFileBytes = 256 * 1024;
  static const String fileName = 'jokarz_diagnostics.log';

  final List<LogEntry> _entries = [];

  /// Bumped on every new entry so UI can rebuild via [ValueListenableBuilder].
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  File? _file;
  Future<void> _writeChain = Future.value();

  List<LogEntry> get entries => List.unmodifiable(_entries);

  int get errorCount => _entries.where((e) => e.level == LogLevel.error).length;

  /// Resolves the log file and enables disk persistence. Call once at startup.
  Future<void> attachFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      if (await file.exists() && await file.length() > maxFileBytes) {
        final old = File('${file.path}.1');
        if (await old.exists()) await old.delete();
        await file.rename(old.path);
      }
      _file = file;
    } catch (e) {
      debugPrint('AppLogger: could not attach log file: $e');
    }
  }

  void info(String tag, String message) => _add(LogLevel.info, tag, message);

  void warn(String tag, String message, [Object? error]) =>
      _add(LogLevel.warning, tag, message, error);

  void error(String tag, String message, [Object? error, StackTrace? stack]) =>
      _add(LogLevel.error, tag, message, error, stack);

  void _add(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error?.toString(),
      stack: stack?.toString(),
    );
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    debugPrint(entry.format());
    _scheduleNotify();
    _append(entry);
  }

  // Entries can be logged while the framework is mid-build; bump the
  // revision outside the build phase so listeners never setState during it.
  bool _notifyScheduled = false;
  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      try {
        final binding = SchedulerBinding.instance;
        if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
          binding.addPostFrameCallback((_) => revision.value++);
          return;
        }
      } catch (_) {
        // No binding yet (very early startup, or plain-Dart tests).
      }
      revision.value++;
    });
  }

  void _append(LogEntry entry) {
    final file = _file;
    if (file == null) return;
    _writeChain = _writeChain.then((_) async {
      try {
        await file.writeAsString(
          '${entry.format()}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {
        // Logging must never raise; the in-memory buffer still has the entry.
      }
    });
  }

  /// The whole in-memory log as shareable text, oldest first.
  String exportText() => _entries.map((e) => e.format()).join('\n');

  Future<void> clear() async {
    _entries.clear();
    revision.value++;
    final file = _file;
    if (file == null) return;
    _writeChain = _writeChain.then((_) async {
      try {
        if (await file.exists()) await file.writeAsString('');
      } catch (_) {}
    });
    await _writeChain;
  }

  /// Test hook: drop all state without touching disk.
  @visibleForTesting
  void resetForTest() {
    _entries.clear();
    _file = null;
    revision.value = 0;
  }
}

/// Short alias used throughout the app.
AppLogger get log => AppLogger.instance;

/// Installs framework + platform-level error hooks that funnel into [log].
/// Returns nothing; call before `runApp`.
void installGlobalErrorHandlers() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    log.error('flutter', details.exceptionAsString(), null, details.stack);
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.error('platform', 'Uncaught error', error, stack);
    return true;
  };
}
