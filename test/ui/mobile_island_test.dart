// On phones the navigation floats as a glass pill; nothing a screen puts at
// its bottom (FABs, last rows) may end up hidden behind it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/router/app_router.dart';

import '../helpers/memory_storage.dart';

void main() {
  for (final route in ['/', '/projects', '/orders', '/voice-notes']) {
    testWidgets('phone: the FAB on $route sits above the nav island', (tester) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      appRouter.go(route);
      await tester.pumpWidget(ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(MemoryStorage())],
        child: MaterialApp.router(routerConfig: appRouter),
      ));
      await tester.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsWidgets, reason: '$route has a FAB');
      final navTop = tester.getRect(find.byType(NavigationBar)).top;
      for (final e in fab.evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        expect(r.bottom, lessThanOrEqualTo(navTop), reason: route);
      }
    });
  }
}
