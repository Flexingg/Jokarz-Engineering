import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jokarz_engineering/providers/project_provider.dart';
import 'package:jokarz_engineering/services/storage_service.dart';

/// A [ProjectNotifier] mounted in its own [ProviderContainer], so tests can
/// drive it the way the app does (a `Notifier` can't be constructed and used
/// standalone) and read state without touching the `@protected` member.
class MountedProject {
  final ProviderContainer container;
  MountedProject(this.container);

  ProjectNotifier get notifier => container.read(projectProvider.notifier);
  EngineeringState get state => container.read(projectProvider);

  /// Completes once the initial load from storage has finished.
  Future<void> loaded() async {
    while (state.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }
}

/// Mounts a fresh [ProjectNotifier] over [storage] and disposes it with the
/// test.
MountedProject mountProject(StorageService storage) {
  final container = ProviderContainer(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  container.read(projectProvider); // runs build()
  return MountedProject(container);
}

/// Generic variant for any [Notifier]: mounts [create] in its own container.
class Mounted<N extends Notifier<S>, S> {
  final ProviderContainer container;
  final NotifierProvider<N, S> provider;
  Mounted(this.container, this.provider);

  N get notifier => container.read(provider.notifier);
  S get state => container.read(provider);
}

Mounted<N, S> mountNotifier<N extends Notifier<S>, S>(
  N Function() create, {
  List<Override> overrides = const [],
}) {
  final provider = NotifierProvider<N, S>(create);
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  container.read(provider); // runs build()
  return Mounted(container, provider);
}
