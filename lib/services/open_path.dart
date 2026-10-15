import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_logger.dart';

/// Drawing folders are plain paths people paste in, often with quotes or a
/// trailing slash. Returns the clean path, or '' when there is nothing usable.
String cleanFolderPath(String raw) {
  var p = raw.trim();
  if (p.length >= 2 && p.startsWith('"') && p.endsWith('"')) {
    p = p.substring(1, p.length - 1).trim();
  }
  return p;
}

/// Opens [rawPath] in the system file browser (File Explorer on Windows; a
/// file is shown selected inside its folder). Returns false when it could not
/// be opened, so the caller can say so.
Future<bool> openInFileBrowser(String rawPath) async {
  final path = cleanFolderPath(rawPath);
  if (path.isEmpty) return false;
  try {
    if (!kIsWeb && Platform.isWindows) {
      final isFile = FileSystemEntity.typeSync(path) == FileSystemEntityType.file;
      // explorer.exe reports exit code 1 even when it opens fine, so the exit
      // code is not a signal; only a failure to start it is.
      await Process.run('explorer.exe', isFile ? ['/select,$path'] : [path]);
      return true;
    }
    return await launchUrl(Uri.file(path, windows: false));
  } catch (e, s) {
    log.error('open', 'Could not open $path', e, s);
    return false;
  }
}
