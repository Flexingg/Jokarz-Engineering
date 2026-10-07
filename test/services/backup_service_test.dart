import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/services/backup_service.dart';

void main() {
  late Directory docs;
  late BackupService service;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('jokarz_backup_test');
    service = BackupService(docsDir: () async => docs);
    await File(
      '${docs.path}/jokarz_engineering_data.json',
    ).writeAsString(jsonEncode({'projects': [], 'marker': 'original'}));
    await File('${docs.path}/jokarz_downtimes.json').writeAsString('[]');
    await File('${docs.path}/unrelated.txt').writeAsString('ignore me');
    await File(
      '${docs.path}/jokarz_bamm_config.json',
    ).writeAsString(jsonEncode({'password': 'hunter2'}));
  });

  tearDown(() async {
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  test('BAMM credentials are never written into a backup', () async {
    final bytes = await service.buildBackup();
    final names = ZipDecoder().decodeBytes(bytes).files.map((f) => f.name);
    expect(names, isNot(contains('jokarz_bamm_config.json')));
    expect(String.fromCharCodes(bytes), isNot(contains('hunter2')));
  });

  test('backup contains only jokarz_*.json plus a manifest', () async {
    final bytes = await service.buildBackup();
    final names = ZipDecoder()
        .decodeBytes(bytes)
        .files
        .map((f) => f.name)
        .toSet();
    expect(names, {
      'jokarz_engineering_data.json',
      'jokarz_downtimes.json',
      BackupService.manifestName,
    });
    final info = service.inspect(bytes);
    expect(info.fileCount, 2);
  });

  test('restore round-trips and snapshots current data first', () async {
    final bytes = await service.buildBackup();
    await File(
      '${docs.path}/jokarz_engineering_data.json',
    ).writeAsString(jsonEncode({'projects': [], 'marker': 'changed'}));

    await service.restore(bytes);

    final restored = jsonDecode(
      await File('${docs.path}/jokarz_engineering_data.json').readAsString(),
    );
    expect(restored['marker'], 'original');
    final snaps = (await service.listBackups()).where(
      (f) => f.path.contains('pre-restore-'),
    );
    expect(snaps, hasLength(1));
  });

  test(
    'rejects non-zip, missing manifest, tampered and foreign archives',
    () async {
      expect(() => service.inspect([1, 2, 3]), throwsA(isA<BackupException>()));

      final noManifest = Archive()
        ..addFile(ArchiveFile('jokarz_a.json', 2, utf8.encode('[]')));
      expect(
        () => service.inspect(ZipEncoder().encode(noManifest)),
        throwsA(isA<BackupException>()),
      );

      // Tamper with a file after the manifest checksum was computed.
      final good = ZipDecoder().decodeBytes(await service.buildBackup());
      final tampered = Archive();
      for (final f in good.files) {
        if (f.name == 'jokarz_downtimes.json') {
          final bad = utf8.encode('[1]');
          tampered.addFile(ArchiveFile(f.name, bad.length, bad));
        } else {
          tampered.addFile(ArchiveFile(f.name, f.size, f.content as List<int>));
        }
      }
      expect(
        () => service.inspect(ZipEncoder().encode(tampered)),
        throwsA(isA<BackupException>()),
      );

      final foreign = utf8.encode(
        jsonEncode({'app': 'other', 'schemaVersion': 1, 'files': {}}),
      );
      final foreignZip = Archive()
        ..addFile(ArchiveFile('manifest.json', foreign.length, foreign));
      expect(
        () => service.inspect(ZipEncoder().encode(foreignZip)),
        throwsA(isA<BackupException>()),
      );
    },
  );

  test('rejects entries with path traversal', () async {
    final body = utf8.encode('[]');
    final manifest = utf8.encode(
      jsonEncode({
        'app': 'jokarz-engineering',
        'schemaVersion': 1,
        'files': {'../jokarz_evil.json': 'x'},
      }),
    );
    final a = Archive()
      ..addFile(ArchiveFile('../jokarz_evil.json', body.length, body))
      ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    expect(
      () => service.inspect(ZipEncoder().encode(a)),
      throwsA(isA<BackupException>()),
    );
  });

  test('auto-backup runs once per day and prunes to the newest 7', () async {
    final day = DateTime(2026, 10, 1, 9);
    expect(await service.runAutoBackupIfDue(now: day), isNotNull);
    expect(
      await service.runAutoBackupIfDue(now: day.add(const Duration(hours: 3))),
      isNull,
    );

    for (var i = 1; i <= 9; i++) {
      await service.runAutoBackupIfDue(now: day.add(Duration(days: i)));
    }
    final autos = (await service.listBackups()).where(
      (f) => f.uri.pathSegments.last.startsWith('auto-'),
    );
    expect(autos.length, BackupService.maxAutoBackups);
  });

  test('auto-backup is skipped when there is no data yet', () async {
    final empty = await Directory.systemTemp.createTemp('jokarz_empty');
    addTearDown(() => empty.delete(recursive: true));
    final s = BackupService(docsDir: () async => empty);
    expect(await s.runAutoBackupIfDue(), isNull);
  });
}
