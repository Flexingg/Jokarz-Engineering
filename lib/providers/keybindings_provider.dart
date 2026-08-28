import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/key_bindings.dart';
import '../providers/project_provider.dart';
import '../services/storage_service.dart';

final keyBindingsProvider =
    StateNotifierProvider<KeyBindingsNotifier, Map<String, String>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return KeyBindingsNotifier(storage);
});

class KeyBindingsNotifier extends StateNotifier<Map<String, String>> {
  final StorageService _storage;

  KeyBindingsNotifier(this._storage) : super(Map.of(defaultKeyBindings)) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.loadKeyBindings();
    if (saved.isNotEmpty) {
      final merged = Map<String, String>.of(defaultKeyBindings);
      merged.addAll(saved);
      state = merged;
    }
  }

  Future<void> setBinding(String actionId, String combo) async {
    state = Map<String, String>.of(state)..[actionId] = combo;
    await _storage.saveKeyBindings(state);
  }

  Future<void> resetToDefaults() async {
    state = Map.of(defaultKeyBindings);
    await _storage.saveKeyBindings(state);
  }
}
