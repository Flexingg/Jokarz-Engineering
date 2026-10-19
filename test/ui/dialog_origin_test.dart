// Dialogs grow out of the button that opened them and settle centred.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/models/ui_prefs.dart';
import 'package:jokarz_engineering/ui/fluid/fluid_dialog.dart';
import 'package:jokarz_engineering/ui/motion/motion.dart';

Widget _app(Widget home) => MaterialApp(
      builder: (context, child) => MotionScope(
        motion: const Motion(MotionLevel.bouncy),
        child: TapOriginRecorder(child: child!),
      ),
      home: home,
    );

Widget _opener() => Scaffold(
      body: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFluidDialog(
                context: context,
                builder: (_) => const AlertDialog(key: Key('dlg'), title: Text('Hello')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('starts at the tapped button and ends in the centre', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(_opener()));
    final button = tester.getCenter(find.text('Open'));
    const screenCentre = Offset(600, 400);

    await tester.tap(find.text('Open'));
    await tester.pump(); // route pushed, animation at its start
    await tester.pump(const Duration(milliseconds: 16));
    final early = tester.getCenter(find.byKey(const Key('dlg')));
    expect((early - button).distance, lessThan((early - screenCentre).distance),
        reason: 'first frames sit near the button ($button), not the centre: got $early');

    await tester.pumpAndSettle();
    final settled = tester.getCenter(find.byKey(const Key('dlg')));
    expect((settled - screenCentre).distance, lessThan(2));
  });

  testWidgets('opened without a recent tap (keyboard), it grows from the centre', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BuildContext ctx;
    await tester.pumpWidget(_app(Builder(builder: (c) {
      ctx = c;
      return const Scaffold();
    })));
    // Let any earlier tap age out.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1600)));
    showFluidDialog(context: ctx, builder: (_) => const AlertDialog(key: Key('dlg'), title: Text('Hi')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final early = tester.getCenter(find.byKey(const Key('dlg')));
    expect((early - const Offset(600, 400)).distance, lessThan(4));
  });
}
