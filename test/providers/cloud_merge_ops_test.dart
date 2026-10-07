import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/inbox_item.dart';
import 'package:jokarz_engineering/models/project_template.dart';
import 'package:jokarz_engineering/models/standalone_order.dart';
import 'package:jokarz_engineering/models/vendor.dart';
import 'package:jokarz_engineering/services/storage_service.dart';

import '../helpers/mount_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('updatedAt on synced models', () {
    test('legacy JSON without updatedAt falls back to createdAt', () {
      final created = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final order = StandaloneOrder.fromJson({
        'id': 'o1',
        'createdAt': created.toIso8601String(),
      });
      expect(order.updatedAt, created);
      final vendor = Vendor.fromJson({
        'id': 'v1',
        'name': 'V',
        'createdAt': created.toIso8601String(),
      });
      expect(vendor.updatedAt, created);
      final inbox = InboxItem.fromJson({
        'id': 'i1',
        'text': 't',
        'createdAt': created.toIso8601String(),
      });
      expect(inbox.updatedAt, created);
      final tpl = ProjectTemplate.fromJson({
        'id': 't1',
        'name': 'T',
        'createdAt': created.toIso8601String(),
      });
      expect(tpl.updatedAt, created);
    });

    test('round-trips and copyWith stamps a newer time', () async {
      final order = StandaloneOrder(
        id: 'o1',
        updatedAt: DateTime.utc(2026, 1, 1),
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(
        StandaloneOrder.fromJson(order.toJson()).updatedAt,
        order.updatedAt,
      );
      expect(
        order.copyWith(notes: 'x').updatedAt.isAfter(order.updatedAt),
        isTrue,
      );
      expect(order.copyWith(notes: 'x').createdAt, order.createdAt);
    });
  });

  group('ProjectNotifier cloud merge', () {
    test(
      'standalone orders: newer cloud edit wins, stale cloud copy does not',
      () async {
        final h = mountProject(StorageService());
        await h.loaded();
        final n = h.notifier;

        final base = DateTime.utc(2026, 10, 1, 12);
        await n.addStandaloneOrder(
          StandaloneOrder(
            id: 'o1',
            description: 'local',
            createdAt: base,
            updatedAt: base.add(const Duration(minutes: 10)),
          ),
        );

        final stale = StandaloneOrder(
          id: 'o1',
          description: 'stale cloud',
          createdAt: base,
          updatedAt: base.add(const Duration(minutes: 1)),
        );
        await n.mergeCloudStandaloneOrders([stale]);
        expect(h.state.standaloneOrders.single.description, 'local');

        final fresh = StandaloneOrder(
          id: 'o1',
          description: 'fresh cloud',
          createdAt: base,
          updatedAt: base.add(const Duration(minutes: 20)),
        );
        await n.mergeCloudStandaloneOrders([fresh]);
        expect(h.state.standaloneOrders.single.description, 'fresh cloud');
      },
    );

    test(
      'a local edit since the last sync that loses is reported as a conflict',
      () async {
        final h = mountProject(StorageService());
        await h.loaded();
        final n = h.notifier;

        final base = DateTime.utc(2026, 10, 1, 12);
        await n.addVendor(
          Vendor(
            id: 'v1',
            name: 'mine',
            createdAt: base,
            updatedAt: base.add(const Duration(minutes: 5)),
          ),
        );

        final conflicts = await n.mergeCloudVendors([
          Vendor(
            id: 'v1',
            name: 'theirs',
            createdAt: base,
            updatedAt: base.add(const Duration(minutes: 9)),
          ),
        ], lastSyncedAt: base.add(const Duration(minutes: 1)));

        expect(h.state.vendors.single.name, 'theirs');
        expect(conflicts, hasLength(1));
        expect(conflicts.single.remoteWon, isTrue);
      },
    );

    test('system templates from the cloud are ignored', () async {
      final h = mountProject(StorageService());
      await h.loaded();
      final before = h.state.customTemplates.length;
      final sys = ProjectTemplate(
        id: 'sys-pm',
        name: 'System',
        isSystemTemplate: true,
      );
      await h.notifier.mergeCloudTemplates([sys]);
      expect(h.state.customTemplates.length, before);
    });
  });
}
