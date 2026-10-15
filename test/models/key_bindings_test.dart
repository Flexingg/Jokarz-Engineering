import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/key_bindings.dart';

void main() {
  test(
    'Search is gone from the defaults; the palette and sidebar are bound',
    () {
      expect(defaultKeyBindings.containsKey('search'), isFalse);
      expect(keyBindingsLabels.containsKey('search'), isFalse);
      expect(defaultKeyBindings['palette'], 'ctrl+k');
      expect(defaultKeyBindings['toggleSidebar'], 'ctrl+b');
    },
  );

  group('migrateSavedBindings', () {
    test('an untouched old Search binding is simply dropped', () {
      final m = migrateSavedBindings({
        'search': 'ctrl+shift+s',
        'createNote': 'ctrl+n',
      });
      expect(m.containsKey('search'), isFalse);
      expect(
        m.containsKey('palette'),
        isFalse,
        reason: 'falls back to the new default, ctrl+k',
      );
      expect(m['createNote'], 'ctrl+n');
    });

    test('a customised Search binding moves to the palette', () {
      final m = migrateSavedBindings({'search': 'ctrl+alt+f'});
      expect(m, {'palette': 'ctrl+alt+f'});
    });

    test('an explicit palette binding wins over an old Search one', () {
      final m = migrateSavedBindings({
        'search': 'ctrl+alt+f',
        'palette': 'ctrl+p',
      });
      expect(m, {'palette': 'ctrl+p'});
    });

    test('unknown actions are dropped', () {
      expect(migrateSavedBindings({'bogus': 'ctrl+9'}), isEmpty);
    });
  });
}
