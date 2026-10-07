import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ui_prefs.dart';
import '../services/storage_service.dart';
import 'project_provider.dart' show storageServiceProvider;

/// Persisted look-and-layout preferences. Starts from defaults and replaces
/// itself with the saved copy as soon as it has loaded; every [update] is
/// written straight back to disk.
final uiPrefsProvider = NotifierProvider<UiPrefsNotifier, UiPrefs>(
  UiPrefsNotifier.new,
);

class UiPrefsNotifier extends Notifier<UiPrefs> {
  StorageService get _storage => ref.read(storageServiceProvider);
  bool _touchedBeforeLoad = false;

  @override
  UiPrefs build() {
    Future.microtask(_load);
    return const UiPrefs();
  }

  Future<void> _load() async {
    final saved = await _storage.loadUiPrefs();
    // A change made while loading wins over the older saved copy.
    if (!_touchedBeforeLoad) state = saved;
  }

  void update(UiPrefs Function(UiPrefs current) change) {
    _touchedBeforeLoad = true;
    state = change(state);
    _storage.saveUiPrefs(state);
  }
}
