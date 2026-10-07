import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';

/// Thrown when a backup archive is unreadable or fails validation. The
/// message is safe to show to the user.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

class BackupInfo {
  final DateTime createdAt;
  final int fileCount;
  final int schemaVersion;
  const BackupInfo(
      {required this.createdAt,
      required this.fileCount,
      required this.schemaVersion});
}

/// Whole-dataset backup & restore.
///
/// A backup is a zip holding every `jokarz_*.json` data file in the app
/// documents directory plus a `manifest.json` (schema version, timestamp and
/// a SHA-256 per file). Restores validate the manifest and that every file is
/// well-formed JSON *before* touching the live data, and always snapshot the
/// current data first so a restore can itself be undone.
class BackupService {
  static const int schemaVersion = 1;
  static const String manifestName = 'manifest.json';
  static const String dataPrefix = 'jokarz_';
  static const String backupsDirName = 'backups';
  static const int maxAutoBackups = 7;

  final Future<Directory> Function() _docsDir;

  BackupService({Future<Directory> Function()? docsDir})
      : _docsDir = docsDir ?? getApplicationDocumentsDirectory;

  bool _isDataFile(String name) =>
      name.startsWith(dataPrefix) && name.endsWith('.json');

  Future<Directory> _backupsDir() async {
    final dir = Directory('${(await _docsDir()).path}/$backupsDirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Builds the zip for the current on-disk data.
  Future<List<int>> buildBackup({DateTime? now}) async {
    final docs = await _docsDir();
    final archive = Archive();
    final checksums = <String, String>{};

    final files = docs
        .listSync()
        .whereType<File>()
        .where((f) => _isDataFile(f.uri.pathSegments.last))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final f in files) {
      final name = f.uri.pathSegments.last;
      final bytes = await f.readAsBytes();
      checksums[name] = sha256.convert(bytes).toString();
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    final manifest = utf8.encode(jsonEncode({
      'app': 'jokarz-engineering',
      'schemaVersion': schemaVersion,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'files': checksums,
    }));
    archive.addFile(ArchiveFile(manifestName, manifest.length, manifest));

    final out = ZipEncoder().encode(archive);
    return out;
  }

  /// Validates [zipBytes] and returns what it contains. Throws
  /// [BackupException] if it is not a usable backup.
  BackupInfo inspect(List<int> zipBytes) => _parse(zipBytes).info;

  ({BackupInfo info, Map<String, List<int>> files}) _parse(List<int> zipBytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw const BackupException('That file is not a valid backup archive.');
    }

    ArchiveFile? manifestFile;
    for (final f in archive.files) {
      if (f.isFile && f.name == manifestName) manifestFile = f;
    }
    if (manifestFile == null) {
      throw const BackupException('Backup is missing its manifest.');
    }

    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>))
          as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('Backup manifest is unreadable.');
    }
    if (manifest['app'] != 'jokarz-engineering') {
      throw const BackupException('This backup is from a different app.');
    }
    final version = manifest['schemaVersion'];
    if (version is! int || version > schemaVersion) {
      throw const BackupException(
          'This backup was made by a newer version of the app. Update first.');
    }

    final expected =
        (manifest['files'] as Map<String, dynamic>? ?? const {}).cast<String, dynamic>();
    final files = <String, List<int>>{};
    for (final f in archive.files) {
      if (!f.isFile || f.name == manifestName) continue;
      // Reject path tricks: only flat jokarz_*.json names are ever restored.
      if (f.name.contains('/') || f.name.contains('\\') || !_isDataFile(f.name)) {
        throw BackupException('Backup contains an unexpected entry: ${f.name}');
      }
      final bytes = f.content as List<int>;
      final want = expected[f.name];
      if (want == null || want != sha256.convert(bytes).toString()) {
        throw BackupException('Backup file failed integrity check: ${f.name}');
      }
      try {
        jsonDecode(utf8.decode(bytes));
      } catch (_) {
        throw BackupException('Backup file is not valid JSON: ${f.name}');
      }
      files[f.name] = bytes;
    }
    for (final name in expected.keys) {
      if (!files.containsKey(name)) {
        throw BackupException('Backup is missing a file: $name');
      }
    }
    if (files.isEmpty) {
      throw const BackupException('Backup contains no data.');
    }

    return (
      info: BackupInfo(
        createdAt: DateTime.tryParse('${manifest['createdAt']}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        fileCount: files.length,
        schemaVersion: version,
      ),
      files: files,
    );
  }

  /// Replaces the live data with the contents of [zipBytes].
  ///
  /// Validation happens first; then the current data is snapshotted to
  /// `backups/pre-restore-<ts>.zip`; then files are swapped in atomically one
  /// by one. Data files not present in the backup are left untouched.
  Future<BackupInfo> restore(List<int> zipBytes) async {
    final parsed = _parse(zipBytes);
    final docs = await _docsDir();

    try {
      final snapshot = await buildBackup();
      final dir = await _backupsDir();
      await File(
              '${dir.path}/pre-restore-${DateTime.now().millisecondsSinceEpoch}.zip')
          .writeAsBytes(snapshot, flush: true);
    } catch (e, stack) {
      log.error('backup', 'Pre-restore snapshot failed; aborting restore', e, stack);
      throw const BackupException(
          'Could not snapshot current data before restoring. Nothing was changed.');
    }

    for (final entry in parsed.files.entries) {
      final target = File('${docs.path}/${entry.key}');
      final tmp = File('${target.path}.restore.tmp');
      await tmp.writeAsBytes(entry.value, flush: true);
      if (await target.exists()) await target.delete();
      await tmp.rename(target.path);
    }
    log.info('backup', 'Restored ${parsed.files.length} files from backup');
    return parsed.info;
  }

  /// Writes a timestamped backup into `backups/` and prunes old auto-backups.
  Future<File> writeBackupFile({String prefix = 'backup', DateTime? now}) async {
    final stamp = (now ?? DateTime.now());
    final name =
        '$prefix-${stamp.year}${_2(stamp.month)}${_2(stamp.day)}-${_2(stamp.hour)}${_2(stamp.minute)}${_2(stamp.second)}.zip';
    final dir = await _backupsDir();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(await buildBackup(now: now), flush: true);
    return file;
  }

  /// Takes at most one automatic backup per calendar day and keeps the newest
  /// [maxAutoBackups]. Never throws.
  Future<File?> runAutoBackupIfDue({DateTime? now}) async {
    try {
      final today = now ?? DateTime.now();
      final dir = await _backupsDir();
      final autos = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.uri.pathSegments.last.startsWith('auto-'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final todayKey = '${today.year}${_2(today.month)}${_2(today.day)}';
      if (autos.any((f) => f.uri.pathSegments.last.startsWith('auto-$todayKey'))) {
        return null;
      }
      // Nothing worth backing up yet (fresh install).
      final hasData = (await _docsDir())
          .listSync()
          .whereType<File>()
          .any((f) => _isDataFile(f.uri.pathSegments.last));
      if (!hasData) return null;

      final created = await writeBackupFile(prefix: 'auto', now: today);
      autos.add(created);
      while (autos.length > maxAutoBackups) {
        await autos.removeAt(0).delete();
      }
      log.info('backup', 'Auto-backup written: ${created.uri.pathSegments.last}');
      return created;
    } catch (e, stack) {
      log.error('backup', 'Auto-backup failed', e, stack);
      return null;
    }
  }

  /// Existing backups in `backups/`, newest first.
  Future<List<File>> listBackups() async {
    final dir = await _backupsDir();
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
  }

  String _2(int n) => n.toString().padLeft(2, '0');
}
