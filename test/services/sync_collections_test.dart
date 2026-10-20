// Regression: every cloud merge failed at runtime with
// "type '(ProjectNotifier, List<Project>, ...) => ...' is not a subtype of
// type '(ProjectNotifier, List<dynamic>, ...) => ...'" because the sync loop
// called the typed function fields through a SyncCollection<dynamic> view.
// This drives every collection exactly the way the sync loop does.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/fab_job.dart';
import 'package:jokarz_engineering/models/inbox_item.dart';
import 'package:jokarz_engineering/models/project.dart';
import 'package:jokarz_engineering/models/project_template.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/models/voice_note.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/services/sync_service.dart';

import '../helpers/memory_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each synced collection parses, encodes and merges a cloud snapshot', () async {
    final c = ProviderContainer(overrides: [storageServiceProvider.overrideWithValue(MemoryStorage())]);
    addTearDown(c.dispose);
    c.read(projectProvider);
    while (c.read(projectProvider).isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final n = c.read(projectProvider.notifier);
    final sync = c.read(syncStatusProvider.notifier);

    // What "the other device" put in the cloud, one record per collection.
    final cloud = <String, Map<String, dynamic>>{
      'projects': Project(id: 'p-cloud', title: 'From the phone').toJson(),
      'voiceNotes': VoiceNote(id: 'n-cloud', title: 'Cloud note', transcript: 'hi').toJson(),
      'standaloneOrders': StandaloneOrder(id: 'o-cloud', description: 'Bearing').toJson(),
      'inbox': InboxItem(id: 'i-cloud', text: 'Check pump').toJson(),
      'vendors': Vendor(id: 'v-cloud', name: 'Motion Inc').toJson(),
      'templates': ProjectTemplate(id: 't-cloud', name: 'PM template').toJson(),
      'fabJobs': FabJob(id: 'f-cloud', title: 'Guard plates').toJson(),
    };

    expect(sync.collections.map((x) => x.name).toSet(), cloud.keys.toSet());
    for (final col in sync.collections) {
      final item = col.parse(cloud[col.name]!);
      expect(col.id(item), endsWith('-cloud'), reason: col.name);
      col.stamp(item);
      expect(col.encode(item)['id'], col.id(item), reason: col.name);
      await col.mergeRemote(n, [item], null);
      final local = col.listFrom(c.read(projectProvider)).map(col.id).toList();
      expect(local, contains(col.id(item)), reason: '${col.name} merged into this device');
    }
  });
}
