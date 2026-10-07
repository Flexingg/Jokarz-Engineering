import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/services/sync_merge.dart';

class _Item {
  final String id;
  final DateTime updatedAt;
  final String value;
  _Item(this.id, this.updatedAt, [this.value = '']);
}

DateTime _t(int minute) => DateTime.utc(2026, 10, 1, 12, minute);

MergeOutcome<_Item> _merge(List<_Item> local, List<_Item> remote,
        {DateTime? lastSyncedAt, bool Function(_Item)? skip}) =>
    mergeByUpdatedAt<_Item>(
      collection: 'items',
      local: local,
      remote: remote,
      idOf: (i) => i.id,
      updatedAtOf: (i) => i.updatedAt,
      lastSyncedAt: lastSyncedAt,
      skipRemote: skip,
    );

void main() {
  test('cloud-only items are added after local ones, local-only are kept', () {
    final out = _merge([_Item('a', _t(0))], [_Item('b', _t(0))]);
    expect(out.merged.map((i) => i.id), ['a', 'b']);
    expect(out.added, 1);
    expect(out.conflicts, isEmpty);
  });

  test('newer cloud edit replaces the local copy in place', () {
    final out = _merge(
      [_Item('a', _t(0), 'old'), _Item('b', _t(0))],
      [_Item('a', _t(5), 'new')],
    );
    expect(out.merged.map((i) => i.value), ['new', '']);
    expect(out.replaced, 1);
  });

  test('older cloud copy never clobbers a newer local edit', () {
    final out = _merge([_Item('a', _t(9), 'mine')], [_Item('a', _t(1), 'stale')]);
    expect(out.merged.single.value, 'mine');
    expect(out.replaced, 0);
  });

  test('equal timestamps (our own push echoing back) keep local, no conflict', () {
    final out = _merge([_Item('a', _t(3), 'mine')], [_Item('a', _t(3), 'echo')],
        lastSyncedAt: _t(1));
    expect(out.merged.single.value, 'mine');
    expect(out.conflicts, isEmpty);
  });

  test('cloud wins over a local edit made since the last sync -> conflict', () {
    final out = _merge([_Item('a', _t(4), 'mine')], [_Item('a', _t(8), 'theirs')],
        lastSyncedAt: _t(2));
    expect(out.merged.single.value, 'theirs');
    expect(out.conflicts.single.remoteWon, isTrue);
  });

  test('cloud replacing a local copy that was already synced is not a conflict', () {
    final out = _merge([_Item('a', _t(1), 'synced')], [_Item('a', _t(8), 'theirs')],
        lastSyncedAt: _t(2));
    expect(out.merged.single.value, 'theirs');
    expect(out.conflicts, isEmpty);
  });

  test('local wins over a different cloud edit made since last sync -> conflict', () {
    final out = _merge([_Item('a', _t(9), 'mine')], [_Item('a', _t(5), 'theirs')],
        lastSyncedAt: _t(2));
    expect(out.merged.single.value, 'mine');
    final c = out.conflicts.single;
    expect(c.remoteWon, isFalse);
    expect(c.summary, contains('items/a'));
  });

  test('never synced (null lastSyncedAt) reports no conflicts', () {
    final out = _merge([_Item('a', _t(4))], [_Item('a', _t(8))]);
    expect(out.conflicts, isEmpty);
  });

  test('skipRemote ignores built-in cloud items entirely', () {
    final out = _merge([], [_Item('sys', _t(0)), _Item('mine', _t(0))],
        skip: (i) => i.id == 'sys');
    expect(out.merged.map((i) => i.id), ['mine']);
  });
}
