import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/filament_profile.dart';
import 'package:jokarz_engineering/services/storage_service.dart';

void main() {
  late Directory docs;
  late StorageService storage;
  File dataFile() => File('${docs.path}/jokarz_engineering_data.json');

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('jokarz_storage_test');
    storage = StorageService(docsDir: () async => docs);
  });
  tearDown(() => docs.delete(recursive: true));

  Future<void> save(String title) => storage.saveData(
        projects: [Project(id: 'p1', title: title)],
        voiceNotes: const [],
        customFilaments: FilamentProfile.defaultProfiles,
      );

  test('a save keeps the previous good copy as .bak', () async {
    await save('first');
    await save('second');
    final bak = jsonDecode(await File('${dataFile().path}.bak').readAsString());
    expect((bak['projects'] as List).single['title'], 'first');
  });

  test('corrupt data file is quarantined and restored from .bak', () async {
    await save('first');
    await save('second'); // .bak now holds "first"
    await dataFile().writeAsString('{ this is not json');

    final data = await storage.loadData();
    expect((data['projects'] as List<Project>).single.title, 'first');

    final quarantined = docs
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('.corrupt-'));
    expect(quarantined, hasLength(1));
    expect(await quarantined.single.readAsString(), '{ this is not json');
    // Live file is valid again.
    expect(() => jsonDecode(dataFile().readAsStringSync()), returnsNormally);
  });

  test('corrupt file with no backup is preserved, not overwritten', () async {
    await dataFile().writeAsString('garbage');
    final data = await storage.loadData();
    expect(data['projects'], isEmpty);
    final preserved = docs
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('.corrupt-'));
    expect(preserved, hasLength(1));
    expect(await preserved.single.readAsString(), 'garbage');
  });
}
