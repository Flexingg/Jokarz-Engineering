/// Pure last-write-wins merge used for every synced collection.
///
/// Kept free of Firebase and Riverpod so the rules are unit-testable. The
/// caller supplies how to read an item's id and `updatedAt`; this decides the
/// winner and reports a [SyncConflict] whenever an edit made on *this* device
/// since the last successful sync lost to (or discarded) a different edit.

class SyncConflict {
  final String collection;
  final String id;
  final DateTime localUpdatedAt;
  final DateTime remoteUpdatedAt;

  /// True when the cloud copy replaced a local edit; false when the local edit
  /// was kept and a (different) cloud edit was discarded.
  final bool remoteWon;

  const SyncConflict({
    required this.collection,
    required this.id,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    required this.remoteWon,
  });

  String get summary => remoteWon
      ? '$collection/$id: newer cloud edit replaced a local edit'
      : '$collection/$id: kept local edit, ignored an older cloud edit';
}

class MergeOutcome<T> {
  /// Local items first (in their existing order, replaced in place where the
  /// cloud won), then cloud-only items in cloud order.
  final List<T> merged;
  final List<SyncConflict> conflicts;
  final int added;
  final int replaced;

  const MergeOutcome(this.merged, this.conflicts, this.added, this.replaced);
}

MergeOutcome<T> mergeByUpdatedAt<T>({
  required String collection,
  required List<T> local,
  required List<T> remote,
  required String Function(T) idOf,
  required DateTime Function(T) updatedAtOf,

  /// When the last successful sync finished. Edits after this point are the
  /// ones that can conflict. Null (never synced) reports no conflicts.
  DateTime? lastSyncedAt,

  /// Cloud items to ignore entirely (e.g. built-in system templates).
  bool Function(T)? skipRemote,
}) {
  final byId = <String, T>{for (final l in local) idOf(l): l};
  final order = [for (final l in local) idOf(l)];
  final conflicts = <SyncConflict>[];
  var added = 0;
  var replaced = 0;

  for (final r in remote) {
    if (skipRemote != null && skipRemote(r)) continue;
    final id = idOf(r);
    final l = byId[id];
    if (l == null) {
      byId[id] = r;
      order.add(id);
      added++;
      continue;
    }
    final lt = updatedAtOf(l);
    final rt = updatedAtOf(r);
    if (rt.isAfter(lt)) {
      byId[id] = r;
      replaced++;
      if (lastSyncedAt != null && lt.isAfter(lastSyncedAt)) {
        conflicts.add(SyncConflict(
            collection: collection,
            id: id,
            localUpdatedAt: lt,
            remoteUpdatedAt: rt,
            remoteWon: true));
      }
    } else if (lt.isAfter(rt) &&
        lastSyncedAt != null &&
        rt.isAfter(lastSyncedAt)) {
      conflicts.add(SyncConflict(
          collection: collection,
          id: id,
          localUpdatedAt: lt,
          remoteUpdatedAt: rt,
          remoteWon: false));
    }
  }

  return MergeOutcome<T>(
      [for (final id in order) byId[id] as T], conflicts, added, replaced);
}
