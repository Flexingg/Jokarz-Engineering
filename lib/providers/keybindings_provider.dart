import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/key_bindings.dart';
import '../providers/project_provider.dart';
import '../services/storage_service.dart';

final keyBindingsProvider =
    NotifierProvider<KeyBindingsNotifier, Map<String, String>>(
        KeyBindingsNotifier.new);

class KeyBindingsNotifier extends Notifier<Map<String, String>> {
  late StorageService _storage;

  @override
  Map<String, String> build() {
    _storage = ref.watch(storageServiceProvider);
    _load();
    return Map.of(defaultKeyBindings);
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
