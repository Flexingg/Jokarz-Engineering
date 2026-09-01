import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'services/sync_service.dart';
import 'router/app_router.dart';
import 'ui/widgets/app_shortcuts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  runApp(
    const ProviderScope(
      child: JokarzEngineeringApp(),
    ),
  );
}

class JokarzEngineeringApp extends ConsumerWidget {
  const JokarzEngineeringApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeFamily = ref.watch(themeProvider);
    // Eagerly initialize cloud sync listener when app starts
    ref.watch(syncStatusProvider);

    return MaterialApp.router(
      title: 'Jokarz Engineering',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(themeFamily),
      routerConfig: appRouter,
      builder: (context, child) =>
          AppShortcuts(child: child ?? const SizedBox.shrink()),
    );
  }
}
