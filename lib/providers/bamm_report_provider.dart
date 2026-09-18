import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bamm_report_config.dart';
import '../providers/project_provider.dart' show storageServiceProvider;
import '../services/storage_service.dart';

class BammReportSettings {
  final BammReportConfig current;
  final Map<String, BammReportConfig> templates;
  const BammReportSettings({required this.current, this.templates = const {}});
}

final bammReportSettingsProvider =
    StateNotifierProvider<BammReportSettingsNotifier, BammReportSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return BammReportSettingsNotifier(storage);
});

class BammReportSettingsNotifier extends StateNotifier<BammReportSettings> {
  final StorageService _storage;
  BammReportSettingsNotifier(this._storage) : super(const BammReportSettings(current: BammReportConfig())) {
    _load();
  }

  Future<void> _load() async {
    final data = await _storage.loadBammReportTemplates();
    if (data == null) return;
    final currentRaw = data['current'];
    final templatesRaw = data['templates'];
    final currentCfg = currentRaw is Map<String, dynamic> ? BammReportConfig.fromJson(currentRaw) : const BammReportConfig();
    final templates = <String, BammReportConfig>{};
    if (templatesRaw is Map<String, dynamic>) {
      templatesRaw.forEach((k, v) {
        if (v is Map<String, dynamic>) templates[k] = BammReportConfig.fromJson(v);
      });
    }
    state = BammReportSettings(current: currentCfg, templates: templates);
  }

  Future<void> _persist() async {
    await _storage.saveBammReportTemplates({
      'current': state.current.toJson(),
      'templates': state.templates.map((k, v) => MapEntry(k, v.toJson())),
    });
  }

  Future<void> setConfig(BammReportConfig cfg) async {
    state = BammReportSettings(current: cfg, templates: state.templates);
    await _persist();
  }

  Future<void> saveTemplate(String name, BammReportConfig cfg) async {
    final t = Map<String, BammReportConfig>.of(state.templates)..[name] = cfg;
    state = BammReportSettings(current: state.current, templates: t);
    await _persist();
  }

  Future<void> loadTemplate(String name) async {
    final cfg = state.templates[name];
    if (cfg == null) return;
    state = BammReportSettings(current: cfg, templates: state.templates);
    await _persist();
  }

  Future<void> deleteTemplate(String name) async {
    final t = Map<String, BammReportConfig>.of(state.templates)..remove(name);
    state = BammReportSettings(current: state.current, templates: t);
    await _persist();
  }
}
